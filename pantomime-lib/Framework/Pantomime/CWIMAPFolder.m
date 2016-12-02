/*
**  CWIMAPFolder.m
**
**  Copyright (c) 2001-2007
**
**  Author: Ludovic Marcotte <ludovic@Sophos.ca>
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

#import "Pantomime/CWIMAPFolder.h"

#import "Pantomime/CWConnection.h"
#import "Pantomime/CWConstants.h"
#import "Pantomime/CWFlags.h"
#import "Pantomime/CWIMAPStore.h"
#import "Pantomime/CWIMAPMessage.h"
#import "Pantomime/NSData+Extensions.h"
#import "Pantomime/NSString+Extensions.h"

#import "NSDate+RFC2822.h"

@interface CWIMAPFolder ()
@property NSMutableDictionary *uids;
@end

//
// Private methods
//
@interface CWIMAPFolder (Private)

- (NSData *) _removeInvalidHeadersFromMessage: (NSData *) theMessage;

@end


//
//
//
@implementation CWIMAPFolder

- (id) initWithName: (NSString *) theName
{
  if ((self = [super initWithName: theName]) == nil)
    return nil;

    self.uids = [NSMutableDictionary new];
  [self setSelected: NO];
  return self;
}


//
//
//
- (id) initWithName: (NSString *) theName
               mode: (PantomimeFolderMode) theMode
{
  if ((self = [self initWithName: theName]) == nil)
    return nil; 

  _mode = theMode;
  return self;
}


//
//
//
- (void) appendMessageFromRawSource: (NSData *) theData
                              flags: (CWFlags *) theFlags
{
  [self appendMessageFromRawSource: theData
	flags: theFlags
	internalDate: nil];
}

//
//
//
- (void) appendMessageFromRawSource: (NSData *) theData
                              flags: (CWFlags *) theFlags
		       internalDate: (NSDate *) theDate
{
  NSDictionary *aDictionary;
  NSString *flagsAsString;
  NSData *aData;
 
  if (theFlags)
    {
      flagsAsString = [theFlags asString];
    }
  else
    {
      flagsAsString = @"";
    }
  
  // We remove any invalid headers from our message
  aData = [self _removeInvalidHeadersFromMessage: theData];
  
  if (theFlags)
    {
      aDictionary = [NSDictionary dictionaryWithObjectsAndKeys: aData, @"NSDataToAppend", theData, @"NSData", self, @"Folder", theFlags, PantomimeFlagsKey, nil];
    }
  else
    {
      aDictionary = [NSDictionary dictionaryWithObjectsAndKeys: aData, @"NSDataToAppend", theData, @"NSData", self, @"Folder", nil];
    }

  
  if (theDate)
    {
      [_store sendCommand: IMAP_APPEND
	      info: aDictionary
	      arguments: @"APPEND \"%@\" (%@) \"%@\" {%d}",                    // IMAP command
	      [_name modifiedUTF7String],                                      // folder name
	      flagsAsString,                                                   // flags
	      [theDate rfc2822String], // internal date
	      [aData length]];                                                 // length of the data to write
    }
  else
    {
      [_store sendCommand: IMAP_APPEND
	      info: aDictionary
	      arguments: @"APPEND \"%@\" (%@) {%d}",  // IMAP command
	      [_name modifiedUTF7String],             // folder name
	      flagsAsString,                          // flags
	      [aData length]];                        // length of the data to write
    }
}

//
//
//
- (void) copyMessages: (NSArray *) theMessages
	     toFolder: (NSString *) theFolder
{
  NSMutableString *aMutableString;
  NSUInteger i, count;

  // We create our message's UID set
  aMutableString = [[NSMutableString alloc] init];
  count = [theMessages count];

  for (i = 0; i < count; i++)
    {
      if (i == count-1)
	{
	  [aMutableString appendFormat: @"%lu", 
		(unsigned long)[[theMessages objectAtIndex: i] UID]];
	}
      else
	{
	  [aMutableString appendFormat: @"%lu,",
		(unsigned long)[[theMessages objectAtIndex: i] UID]];
	}
    }
 
  // We send our IMAP command
  [_store sendCommand: IMAP_UID_COPY
	  info: [NSDictionary dictionaryWithObjectsAndKeys: theMessages,
             PantomimeMessagesKey, theFolder, @"Name", self, @"Folder", nil]
	  arguments: @"UID COPY %@ \"%@\"",
	  aMutableString,
	  [theFolder modifiedUTF7String]];
 
  RELEASE(aMutableString);
}


/**
 For key sync to work, we have to fetch the whole mail.
 */
- (void) prefetch
{
    // Maximum number of mails to prefetch
    NSInteger fetchMaxMails = [((CWIMAPStore *) [self store]) maxPrefetchCount];

    if ([self lastUID] > 0) {
        [_store sendCommand: IMAP_UID_FETCH_RFC822  info: nil
                  arguments: @"UID FETCH %u:* (FLAGS RFC822)", [self lastUID] + 1];
    } else {
        // Local cache seems to be empty. Fetch a maximum of fetchMaxMails newest mails
        NSInteger lowestMessageNumberToFetch = self.existsCount - fetchMaxMails + 1;
        if (lowestMessageNumberToFetch <= 0) {
            lowestMessageNumberToFetch = 1;
        }

        [_store sendCommand: IMAP_UID_FETCH_RFC822  info: nil
                  arguments: @"FETCH %u:* (UID FLAGS RFC822)", lowestMessageNumberToFetch];
    }
}

- (void)syncExisting
{
    [_store sendCommand: IMAP_UID_FETCH_FLAGS  info: nil
              arguments: @"UID FETCH %u:%u (FLAGS)", [self firstUID], [self lastUID]];
}

//
// This method simply close the selected mailbox (ie. folder)
//
- (void) close
{
  IMAPCommand theCommand;

  if (![self selected])
    {
      [_store removeFolderFromOpenFolders: self];
      return;
    }

  // If we are opening a mailbox but -close was called before we
  // finished opening it, we close the connection immediately.
  theCommand = [[self store] lastCommand];

  if (theCommand == IMAP_SELECT || theCommand == IMAP_UID_SEARCH || theCommand == IMAP_UID_SEARCH_ANSWERED ||
      theCommand == IMAP_UID_SEARCH_FLAGGED || theCommand == IMAP_UID_SEARCH_UNSEEN)
    {
      [_store removeFolderFromOpenFolders: self];
      [[self store] cancelRequest];
      [[self store] reconnect];
      return;
    }

  if (_cacheManager)
    {
      [_cacheManager synchronize];
    }

  // We set the _folder ivar to nil for all messages. This is required in case
  // an IMAPMessage instance was retained and we invoke -setFlags: on it, which
  // will try to access the _folder ivar in order to communicate with the IMAP server.
  [self.allMessages makeObjectsPerformSelector: @selector(setFolder:)  withObject: nil];

  // We close the selected IMAP folder to _expunge_ messages marked as \Deleted
  // if and only we are NOT showing DELETED messages. We also don't send the command
  // if we are NOT connected since a MUA using Pantomime needs to call -close
  // on IMAPFolder to clean-up the "open" folder.
  if ([_store isConnected] && ![self showDeleted])
    {
      [_store sendCommand: IMAP_CLOSE
	      info: [NSDictionary dictionaryWithObject: self  forKey: @"Folder"]
	      arguments: @"CLOSE"];
    }
  else
    {
      PERFORM_SELECTOR_2([_store delegate], @selector(folderCloseCompleted:), PantomimeFolderCloseCompleted, self, @"Folder");
      POST_NOTIFICATION(PantomimeFolderCloseCompleted, _store, [NSDictionary dictionaryWithObject: self  forKey: @"Folder"]);
    }

  [_store removeFolderFromOpenFolders: self];
}


//
// This method returns all messages that have the flag PantomimeFlagDeleted.
//
- (void) expunge
{
  //
  // We send our EXPUNGE command. The responses will be processed in IMAPStore and
  // the MSN will be updated in IMAPStore: -_parseExpunge.
  //
  [_store sendCommand: IMAP_EXPUNGE  info: nil  arguments: @"EXPUNGE"];
}


//
//
//
- (NSUInteger) UIDValidity
{
  return _uid_validity;
}


//
//
//
- (void) setUIDValidity: (NSUInteger) theUIDValidity
{
  _uid_validity = theUIDValidity;
 
   if (_cacheManager)
    {
      if ([_cacheManager UIDValidity] == 0 || [_cacheManager UIDValidity] != _uid_validity)
	{
	  [_cacheManager invalidate];
	  [_cacheManager setUIDValidity: _uid_validity];
	}
    }
}


//
//
//
- (BOOL) selected
{
  return _selected;
}


//
//
//
- (void) setSelected: (BOOL) theBOOL
{
  _selected = theBOOL;
}

//
//
//
- (void) setFlags: (CWFlags *) theFlags
         messages: (NSArray *) theMessages
{
  NSMutableString *aMutableString, *aSequenceSet;
  CWIMAPMessage *aMessage;

  if ([theMessages count] == 1)
    {
      aMessage = [theMessages lastObject];
      // We set the flags right away, just in case someone asks for them
      // just after invoking this method. Nevertheless, they WILL be set
      // in IMAPStore: -_parseOK:.
      // We do the same below, when the count > 1
      [[aMessage flags] replaceWithFlags: theFlags];
      aSequenceSet = [NSMutableString stringWithFormat: @"%lu:%lu", 
				(unsigned long)[aMessage UID], (unsigned long)[aMessage UID]];
    }
  else
    {
      NSUInteger i, count;

      aSequenceSet = AUTORELEASE([[NSMutableString alloc] init]);
      count = [theMessages count];

      for (i = 0; i < count; i++)
	{
	  aMessage = [theMessages objectAtIndex: i];
	  [[aMessage flags] replaceWithFlags: theFlags];

	  if (aMessage == [theMessages lastObject])
	    {
	      [aSequenceSet appendFormat: @"%lu", (unsigned long)[aMessage UID]];
	    }
	  else
	    {
	      [aSequenceSet appendFormat: @"%lu,", (unsigned long)[aMessage UID]];
	    }
	}
    }
  
  aMutableString = [[NSMutableString alloc] init];
  
  //
  // If we're removing all flags, we rather send a STORE -FLAGS (<current flags>) 
  // than a STORE FLAGS (<new flags>) since some broken servers might not 
  // support it (like Cyrus v1.5.19 and v1.6.24).
  //
  if (theFlags->flags == 0)
    {
      [aMutableString appendFormat: @"UID STORE %@ -FLAGS.SILENT (", aSequenceSet];
      [aMutableString appendString: [[aMessage flags] asString]];
      [aMutableString appendString: @")"];
    }
  else
    {
      [aMutableString appendFormat: @"UID STORE %@ FLAGS.SILENT (", aSequenceSet];
      [aMutableString appendString: [theFlags asString]];
      [aMutableString appendString: @")"];
    }
  
  [_store sendCommand: IMAP_UID_STORE
	  info: [NSDictionary dictionaryWithObjectsAndKeys: theMessages,
             PantomimeMessagesKey, theFlags, PantomimeFlagsKey, nil]
	  arguments: aMutableString];
  RELEASE(aMutableString);
}



//
// Using IMAP, we ignore most parameters.
//
- (void) search: (NSString *) theString
	   mask: (PantomimeSearchMask) theMask
	options: (PantomimeSearchOption) theOptions
{
  NSString *aString;  
   
  switch (theMask)
    {
    case PantomimeFrom:
      aString = [NSString stringWithFormat: @"UID SEARCH ALL FROM \"%@\"", theString];
      break;
     
    case PantomimeTo:
      aString = [NSString stringWithFormat: @"UID SEARCH ALL TO \"%@\"", theString];
      break;

    case PantomimeContent:
      aString = [NSString stringWithFormat: @"UID SEARCH ALL BODY \"%@\"", theString];
      break;
      
    case PantomimeSubject:
    default:
      aString = [NSString stringWithFormat: @"UID SEARCH ALL SUBJECT \"%@\"", theString];
    }

  // We send our SEARCH command. Store->searchResponse will have the result.
  [_store sendCommand: IMAP_UID_SEARCH_ALL  info: [NSDictionary dictionaryWithObject: self  forKey: @"Folder"]  arguments: aString];
}

- (NSUInteger) firstUID
{
    return [[[self allMessages] firstObject] UID];
}


- (NSUInteger) lastUID
{
    return [[[self allMessages] lastObject] UID];
}

- (CWIMAPMessage * _Nullable)messageByUID:(NSUInteger)uid
{
    return nil;
}

- (void)matchUID:(NSUInteger)uid withMSN:(NSUInteger)msn
{
    [self.uids setObject:[NSNumber numberWithUnsignedInteger:uid]
                  forKey:[NSNumber numberWithUnsignedInteger:msn]];
}

- (NSUInteger)uidForMSN:(NSUInteger)msn
{
    return [[self.uids objectForKey:[NSNumber numberWithUnsignedInteger:msn]]
            unsignedIntegerValue];
}

- (void)expungeMSN:(NSUInteger)msn
{
    NSArray<NSNumber *> *keysAsc = [self.uids
                                    keysSortedByValueUsingSelector:@selector(unsignedIntegerValue)];
    if (keysAsc.count) {
        NSUInteger lowest = [[keysAsc firstObject] unsignedIntegerValue];
        NSNumber *highestKey = [keysAsc lastObject];
        if (msn >= lowest) {
            NSArray<NSNumber *> *keysDesc = [[keysAsc reverseObjectEnumerator] allObjects];
            NSArray<NSNumber *> *toRework = [keysDesc
                                             filteredArrayUsingPredicate:
                                             [NSPredicate
                                              predicateWithFormat:@"integerValue > msn"]];
            for (NSNumber *num in toRework) {
                NSNumber *value = [self.uids objectForKey:num];
                [self.uids setObject:value forKey:[NSNumber numberWithInt:num.integerValue - 1]];
            }
            [self.uids removeObjectForKey:highestKey];
        }
    }
}

@end


//
// Private methods
// 
@implementation CWIMAPFolder (Private)

//
//
//
- (NSData *) _removeInvalidHeadersFromMessage: (NSData *) theMessage
{
  NSMutableData *aMutableData;
  NSArray *allLines;
  NSUInteger i, count;

  // We allocate our mutable data object
  aMutableData = [[NSMutableData alloc] initWithCapacity: [theMessage length]];
  
  // We now replace all \n by \r\n
  allLines = [theMessage componentsSeparatedByCString: "\n"];
  count = [allLines count];

  for (i = 0; i < count; i++)
    {
      NSData *aLine;

      // We get a line...
      aLine = [allLines objectAtIndex: i];

      // We skip dumb headers
      if ([aLine hasCPrefix: "From "])
	{
	  continue;
	}

      [aMutableData appendData: aLine];
      [aMutableData appendCString: "\r\n"];
    }

  return AUTORELEASE(aMutableData);
}

@end

