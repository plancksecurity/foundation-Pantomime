/*
**  CWIMAPCacheManager.m
**
**  Copyright (c) 2001-2007 Ludovic Marcotte
**                2013-2014
**
**  Author: Ludovic Marcotte <ludovic@Sophos.ca>
**          Riccardo Mottola <rm@gnu.org>
**
**  This library is free software; you can redistribute it and/or
**  modify it under the terms of the GNU Lesser General Public
**  License as published by the Free Software Foundation; either
**  version 2.1 of the License, or (at your option) any later version.
**  
**  This library is distributed in the hope that it will be useful,
**  but WITHOUT ANY WARRANTY; without even the implied warranty of
**  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
**  Lesser General Public License for more details.
**  
**  You should have received a copy of the GNU Lesser General Public
**  License along with this library; if not, write to the Free Software
**  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
*/

#import <Pantomime/CWIMAPCacheManager.h>

#include <Pantomime/CWConstants.h>
#include <Pantomime/CWFlags.h>
#include <Pantomime/CWFolder.h>
#include <Pantomime/CWIMAPMessage.h>
#include <Pantomime/CWParser.h>

#include <Foundation/Foundation.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSException.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSValue.h>

#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <netinet/in.h>
#include <errno.h>
#include <unistd.h>
#include <stdio.h>

static unsigned short version = 1;

//
//
//
@implementation CWIMAPCacheManager

- (id) initWithPath: (NSString *) thePath  folder: (id) theFolder
{
  NSDictionary *attributes;
  unsigned short int v;

  self = [super initWithPath: thePath];

  _table = NSCreateMapTable(NSIntMapKeyCallBacks, NSObjectMapValueCallBacks, 128);
  _count = _UIDValidity = 0;
  _folder = theFolder;


  if ((_fd = open([thePath UTF8String], O_RDWR|O_CREAT, S_IRUSR|S_IWUSR)) < 0) 
    {
      INFO(NSStringFromClass([self class]), @"CANNOT CREATE OR OPEN THE CACHE!)");
      abort();
    }

  if (lseek(_fd, 0L, SEEK_SET) < 0)
    {
      close(_fd);
      INFO(NSStringFromClass([self class]), @"UNABLE TO LSEEK INITIAL");
      abort();
    }

  attributes = [[NSFileManager defaultManager] fileAttributesAtPath: thePath  traverseLink: NO];

  // If the cache exists, lets parse it.
  if ([[attributes objectForKey: NSFileSize] intValue])
    {
      v = read_unsigned_short(_fd);

      if (v != version)
	{
	  if (ftruncate(_fd, 0) == -1)
            {

              if (errno == EACCES || errno == EROFS)
                INFO(NSStringFromClass([self class]), @"UNABLE TO TRUNCATE CACHE FILE WITH OLD VERSION, NOT WRITABLE");
              else
                INFO(NSStringFromClass([self class]), @"UNABLE TO TRUNCATE CACHE FILE WITH OLD VERSION");
              close(_fd);
              abort();
            }
	  [self synchronize];
	  return self;
	}

      _count = read_unsigned_int(_fd);
      _UIDValidity = read_unsigned_int(_fd);
    }
  else
    {
      [self synchronize];
    }

  return self;
}


//
//
//
- (void) dealloc
{
  //INFO(NSStringFromClass([self class]), @"CWIMAPCacheManager: -dealloc");
  
  NSFreeMapTable(_table);
  if (_fd >= 0) close(_fd);

  [super dealloc];
}

//
//
//
- (void) initInRange: (NSRange) theRange
{
  NSAutoreleasePool *pool;
  CWIMAPMessage *aMessage;
  unsigned short int len, tot;
  int begin, end, i;
  unsigned char *r, *s;

  if (lseek(_fd, 10L, SEEK_SET) < 0)
    {
      INFO(NSStringFromClass([self class]), @"lseek failed in initInRange:");
      abort();
    }

  begin = theRange.location;
  end = (NSMaxRange(theRange) <= _count ? NSMaxRange(theRange) : _count);
  
  //INFO(NSStringFromClass([self class]), @"init from %d to %d, count = %d, size of char %d  UID validity = %d", begin, end, _count, sizeof(char), _UIDValidity);

  pool = [[NSAutoreleasePool alloc] init];
  s = (unsigned char *)malloc(65536);

  // We MUST skip the last few bytes...
  for (i = begin; i < end ; i++)
    {
      aMessage = [[CWIMAPMessage alloc] init];
      [aMessage setMessageNumber: i+1];

      // We parse the record length, date, flags, position in file and the size.
      len = read_unsigned_int(_fd);
      //INFO(NSStringFromClass([self class]), @"i = %d, len = %d", i, len);

      r = (unsigned char *)malloc(len-4);

      if (r == NULL)	// may be in case len was 4
	{
	  RELEASE(aMessage);
	  continue;
	}
      
      if (read(_fd, r, len-4) < 0) { INFO(NSStringFromClass([self class]), @"read failed"); abort(); }
      
      ((CWFlags *)[aMessage flags])->flags = read_unsigned_int_memory(r);  // FASTER and _RIGHT_ since we can't call -setFlags: on CWIMAPMessage
      [aMessage setReceivedDate: [NSCalendarDate dateWithTimeIntervalSince1970: read_unsigned_int_memory(r+4)]];
      [aMessage setUID: read_unsigned_int_memory(r+8)];
      [aMessage setSize: read_unsigned_int_memory(r+12)];
      tot = 16;

      read_string_memory(r+tot, s, &len);
      [CWParser parseFrom: [NSData dataWithBytes: s  length: len]  inMessage: aMessage  quick: YES];
      tot += len+2;
     
      read_string_memory(r+tot, s, &len);
      [CWParser parseInReplyTo: [NSData dataWithBytes: s  length: len]  inMessage: aMessage  quick: YES];
      tot += len+2;
      
      read_string_memory(r+tot, s, &len);
      [CWParser parseMessageID: [NSData dataWithBytes: s  length: len]  inMessage: aMessage  quick: YES];
      tot += len+2;

      read_string_memory(r+tot, s, &len);
      [CWParser parseReferences: [NSData dataWithBytes: s  length: len]  inMessage: aMessage  quick: YES];
      tot += len+2;

      read_string_memory(r+tot, s, &len);
      [CWParser parseSubject:  [NSData dataWithBytes: s  length: len]  inMessage: aMessage  quick: YES];
      tot += len+2;
      
      read_string_memory(r+tot, s, &len);
      [CWParser parseDestination: [NSData dataWithBytes: s  length: len]
		forType: PantomimeToRecipient
		inMessage: aMessage
		quick: YES];
      tot += len+2;

      read_string_memory(r+tot, s, &len);
      [CWParser parseDestination: [NSData dataWithBytes: s  length: len]
		forType: PantomimeCcRecipient
		inMessage: aMessage
		quick: YES];

      [((CWFolder *)_folder)->allMessages addObject: aMessage];
      NSMapInsert(_table, (void *)[aMessage UID], aMessage);
      //[self addObject: aMessage]; // MOVE TO CWFIMAPOLDER
      //[((CWFolder *)_folder)->allMessages replaceObjectAtIndex: i  withObject: aMessage];
      RELEASE(aMessage);

      free(r);
    }

  free(s);
  RELEASE(pool);
}

//
//
//
- (void) removeMessageWithUID: (NSUInteger) theUID
{
  NSMapRemove(_table, (void *)theUID);
}

//
//
//
- (CWIMAPMessage *) messageWithUID: (NSUInteger) theUID
{
  return NSMapGet(_table, (void *)theUID);
}

//
//
//
- (unsigned int) UIDValidity
{
  return _UIDValidity;
}

//
//
//
- (void) setUIDValidity: (unsigned int) theUIDValidity
{
  _UIDValidity = theUIDValidity;
}


//
//
//
- (void) invalidate
{
  //INFO(NSStringFromClass([self class]), @"IMAPCacheManager - INVALIDATING the cache...");
  [super invalidate];
  _UIDValidity = 0;
  [self synchronize];
}


//
//
//
- (BOOL) synchronize
{
  unsigned int len, flags;
  int i;

  _count = [_folder->allMessages count];
  
  //INFO(NSStringFromClass([self class]), @"CWIMAPCacheManager: -synchronize with folder count = %d", _count);

  if (lseek(_fd, 0L, SEEK_SET) < 0)
    {
      INFO(NSStringFromClass([self class]), @"fseek failed");
      abort();
    }
  
  // We write our cache version, count and UID validity.
  write_unsigned_short(_fd, version);
  write_unsigned_int(_fd, _count);
  write_unsigned_int(_fd, _UIDValidity);
  
  //INFO(NSStringFromClass([self class]), @"Synching flags");
  for (i = 0; i < _count; i++)
    {
      len = read_unsigned_int(_fd);
      flags = ((CWFlags *)[[_folder->allMessages objectAtIndex: i] flags])->flags;
      write_unsigned_int(_fd, flags);
      lseek(_fd, (len-8), SEEK_CUR);
    }
  //INFO(NSStringFromClass([self class]), @"Done!");
 
  return (fsync(_fd) == 0);
}


//
//
//
- (void) writeRecord: (CacheRecord *) theRecord  message: (id) theMessage
{
  unsigned int len;

  if (lseek(_fd, 0L, SEEK_END) < 0)
    {
      INFO(NSStringFromClass([self class]), @"COULD NOT LSEEK TO END OF FILE");
      abort();
    }
  
  // We calculate the length of this record (including the
  // first five fields, which is 20 bytes long and is added
  // at the very end)
  len = 0;
  len += [theRecord.from length]+2;
  len += [theRecord.in_reply_to length]+2;
  len += [theRecord.message_id length]+2;
  len += [theRecord.references length]+2;
  len += [theRecord.subject length]+2;
  len += [theRecord.to length]+2;
  len += [theRecord.cc length]+22;
  write_unsigned_int(_fd, len);
  
  // We write the flags, date, position and the size of the message.
  write_unsigned_int(_fd, theRecord.flags);
  write_unsigned_int(_fd, theRecord.date);
  write_unsigned_int(_fd, theRecord.imap_uid);
  write_unsigned_int(_fd, theRecord.size);

  // We write the read of our cached headers (From, In-Reply-To, Message-ID, References, 
  // Subject, To and Cc)
  write_string(_fd, (unsigned char *)[theRecord.from bytes], [theRecord.from length]);
  write_string(_fd, (unsigned char *)[theRecord.in_reply_to bytes], [theRecord.in_reply_to length]);
  write_string(_fd, (unsigned char *)[theRecord.message_id bytes], [theRecord.message_id length]);
  write_string(_fd, (unsigned char *)[theRecord.references bytes], [theRecord.references length]);
  write_string(_fd, (unsigned char *)[theRecord.subject bytes], [theRecord.subject length]);
  write_string(_fd, (unsigned char *)[theRecord.to bytes], [theRecord.to length]);
  write_string(_fd, (unsigned char *)[theRecord.cc bytes], [theRecord.cc length]);
  
  NSMapInsert(_table, (void *)theRecord.imap_uid, theMessage);
  _count++;
}


//
//
//
- (void) expunge
{
  NSDictionary *attributes;

  unsigned int i, len, size, total_length, v;
  unsigned char *buf;

  //INFO(NSStringFromClass([self class]), @"expunge: rewriting cache");

  if (lseek(_fd, 10L, SEEK_SET) < 0)
    {
      INFO(NSStringFromClass([self class]), @"fseek failed");
      abort();
    }
  
  attributes = [[NSFileManager defaultManager]
		fileAttributesAtPath: [self path]  traverseLink: NO];
  
  buf = (unsigned char *)malloc([[attributes objectForKey: NSFileSize]
								intValue]);
  if (buf == NULL)	// nothing to do for us here
    return;
  total_length = 0;

  for (i = 0; i < _count; i++)
    {
      //INFO(NSStringFromClass([self class]), @"===========");
      len = read_unsigned_int(_fd);
      if (len <= 4)	// sanity check, we read len-4 bytes later on
	continue;

      //INFO(NSStringFromClass([self class]), @"i = %d  len = %d", i, len);
      v = htonl(len);
      memcpy((buf+total_length), (char *)&v, 4);
      
      // We write the rest of the record into the memory
      if (read(_fd, (buf+total_length+4), len-4) < 0)
	{
	  INFO(NSStringFromClass([self class]), @"read failed");
	  abort();
	}
      
      unsigned int uid = read_unsigned_int_memory(buf+total_length+12);

      if ([self messageWithUID: uid])
	{
	  total_length += len;
	}
      else
	{
	  //INFO(NSStringFromClass([self class]), @"Message not found! uid = %d  table count = %d",
	  //					uid, NSCountMapTable(_table));
	}
    }

  if (lseek(_fd, 0L, SEEK_SET) < 0)
    {
      INFO(NSStringFromClass([self class]), @"fseek failed");
      abort();
    }

  // We write our cache version, count, modification date our new size
  _count = [_folder->allMessages count];
  size = total_length+10;

  write_unsigned_short(_fd, version);
  write_unsigned_int(_fd, _count);
  write_unsigned_int(_fd, _UIDValidity);

  // We write our memory cache
  if (write(_fd, buf, total_length) != total_length)
    {
      if (errno == EAGAIN)
        {
          // Perhaps we could handle this more gracefully?
          INFO(NSStringFromClass([self class]), @"EXPUNGE CACHE: WRITE OUT ERROR, EAGAIN");
        }
      else
        {
          INFO(NSStringFromClass([self class]), @"EXPUNGE CACHE: WRITE OUT INCOMPLETE");
        }
      abort();
    }

  if (ftruncate(_fd, size) == -1)
    {
      
      if (errno == EACCES || errno == EROFS)
        INFO(NSStringFromClass([self class]), @"UNABLE TO EXPUNGE CACHE, NOT WRITABLE");
      else if (errno == EFBIG)
        INFO(NSStringFromClass([self class]), @"UNABLE TO EXPUNGE CACHE, EFBIG");
      else
        INFO(NSStringFromClass([self class]), @"UNABLE TO EXPUNGE CACHE");
      abort();
    }
  free(buf);

  //INFO(NSStringFromClass([self class]), @"Done! New size = %d", size);
}
@end
