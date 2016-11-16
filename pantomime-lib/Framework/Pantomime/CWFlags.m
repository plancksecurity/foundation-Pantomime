/*
**  CWFlags.m
**
**  Copyright (c) 2001-2004
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

#import "Pantomime/CWFlags.h"

#import "Pantomime/NSData+Extensions.h"
#import "Pantomime/NSString+Extensions.h"

#define CHECK_FLAG(c, value) \
  theRange = [theData rangeOfCString: c]; \
  if (theRange.length) { [self add: value]; }

//
//
//
@implementation CWFlags

- (id) initWithFlags: (PantomimeFlag) theFlags
{
  self = [super init];

  flags = theFlags;

  return self;
}

- (instancetype) initWithInt: (NSInteger) theInt
{
    self = [super init];
    if (self) {
        flags = theInt;
    }
    return self;
}

- (instancetype) initWithNumber: (NSNumber *) theNumber
{
    self = [self initWithInt:[theNumber integerValue]];
    return self;
}

- (PantomimeFlag)rawFlags
{
    return flags;
}

- (short)rawFlagsAsShort
{
    return (short) flags;
}

- (NSString *)asString
{
    NSMutableString *aMutableString;

    aMutableString = [[NSMutableString alloc] init];
    AUTORELEASE_VOID(aMutableString);

    if ([self contain: PantomimeFlagAnswered])
    {
        [aMutableString appendString: @"\\Answered "];
    }

    if ([self contain: PantomimeFlagDraft] )
    {
        [aMutableString appendString: @"\\Draft "];
    }

    if ([self contain: PantomimeFlagFlagged])
    {
        [aMutableString appendString: @"\\Flagged "];
    }

    if ([self contain: PantomimeFlagSeen])
    {
        [aMutableString appendString: @"\\Seen "];
    }

    if ([self contain: PantomimeFlagDeleted])
    {
        [aMutableString appendString: @"\\Deleted "];
    }

    return [aMutableString stringByTrimmingWhiteSpaces];

}

//
// NSCoding protocol
//
- (void) encodeWithCoder: (NSCoder *) theCoder
{
  [theCoder encodeObject: [NSNumber numberWithInt: flags]];
}


- (id) initWithCoder: (NSCoder *) theCoder
{
  self = [super init];

  flags = [[theCoder decodeObject] intValue];

  return self;
}


//
// NSCopying protocol
//
- (id) copyWithZone: (NSZone *) zone
{
  CWFlags *theFlags;

  theFlags = [[CWFlags alloc] initWithFlags: flags];

  return theFlags;
}


//
//
//
- (void) add: (PantomimeFlag) theFlag
{
  flags = flags|theFlag;
}


//
//
//
- (void) addFlagsFromData: (NSData *) theData
		   format: (PantomimeFolderFormat) theFormat
{
  NSRange theRange;
  
  if (theData)
    {    
      if (theFormat == PantomimeFormatMbox)
	{
	  CHECK_FLAG("R", PantomimeFlagSeen);
	  CHECK_FLAG("D", PantomimeFlagDeleted);
	  CHECK_FLAG("A", PantomimeFlagAnswered);
	  CHECK_FLAG("F", PantomimeFlagFlagged);
	}
      else if (theFormat == PantomimeFormatMaildir)
	{
	  CHECK_FLAG("S", PantomimeFlagSeen);
	  CHECK_FLAG("R", PantomimeFlagAnswered);
	  CHECK_FLAG("F", PantomimeFlagFlagged);
	  CHECK_FLAG("D", PantomimeFlagDraft);
	  CHECK_FLAG("T", PantomimeFlagDeleted);
	}
    }
}


//
//
//
- (BOOL) contain: (PantomimeFlag) theFlag
{
  if ((flags&theFlag) == theFlag) 
    {
      return YES;
    }
  else
    {
      return NO;
    }
}


//
//
//
- (void) replaceWithFlags: (CWFlags *) theFlags
{
  flags = theFlags->flags;
}

//
//
//
- (void) remove: (PantomimeFlag) theFlag
{
  flags = flags&(flags^theFlag);
}


//
//
//
- (void) removeAll
{
  flags = 0;
}


//
//
//
- (NSString *) statusString
{
  return [NSString stringWithFormat: @"%cO", ([self contain: PantomimeFlagSeen] ? 'R' : ' ')];
}

//

// This is useful if we want to store the flags in the mbox file
// when expunging messages from it. We might write in the headers:
//
// X-Status: FA
//
// If the message had the "Flagged" and "Answered" flags.
//
// Note: We store the same value as pine does in order to ease
//       using mbox files between the two MUAs.
//
- (NSString *) xstatusString
{
  NSMutableString *aMutableString;

  aMutableString = [[NSMutableString alloc] init];
  
  if ([self contain: PantomimeFlagDeleted])
    {
      [aMutableString appendFormat: @"%c", 'D'];
    }

  if ([self contain: PantomimeFlagFlagged])
    {
      [aMutableString appendFormat: @"%c", 'F'];
    }

  if ([self contain: PantomimeFlagAnswered])
    {
      [aMutableString appendFormat: @"%c", 'A'];
    }

  return AUTORELEASE(aMutableString);
}


//
//
//
- (NSString *) maildirString
{
  NSMutableString *aMutableString;
  
  aMutableString = [[NSMutableString alloc] initWithString: @"2,"];
  
  if ([self contain: PantomimeFlagDraft])
    {
      [aMutableString appendString: @"D"];
    }
  
  if ([self contain: PantomimeFlagFlagged])
    {
      [aMutableString appendString: @"F"];
    }
  
  if ([self contain: PantomimeFlagAnswered])
    {
      [aMutableString appendString: @"R"];
    }
  
  if ([self contain: PantomimeFlagSeen])
    {
      [aMutableString appendString: @"S"];
    }
  
  if ([self contain: PantomimeFlagDeleted])
    {
      [aMutableString appendString: @"T"];
    }

  return AUTORELEASE(aMutableString);
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<CWFlags: 0x%x %@>", (uint) self, [self asString]];
}

@end
