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

#import "CWIMAPFolder+CWProtected.h"

#import "CWConnection.h"
#import "CWConstants.h"
#import "CWFlags.h"
#import "CWIMAPStore+Protected.h"
#import "CWIMAPMessage.h"
#import <pEpIOSToolbox/PEPLogger.h>
#import "NSData+Extensions.h"
#import "Pantomime/NSString+Extensions.h"

#import "NSDate+StringRepresentation.h"



@interface CWIMAPFolder ()
@property NSMutableDictionary *uidToMsnMap;
@property NSMutableDictionary *msnToUidMap;
@property BOOL isUpdatingMessageNumber;
@end

//
// Private methods
//
@interface CWIMAPFolder (Private)

- (BOOL) _isInFetchedRange:(NSUInteger)uid;

- (BOOL) _wouldCreatedUpperFetchedRangeWithFrom:(NSUInteger)fromUid to:(NSUInteger)toUid;

- (BOOL) _wouldCreatedLowerFetchedRangeWithFrom:(NSUInteger)fromUid to:(NSUInteger)toUid;

- (BOOL) _isNegativeUid:(NSInteger)uid;

- (BOOL) _uidRangeAllreadyFetchedWithFrom:(NSUInteger)fromUid to:(NSUInteger)toUid;

- (BOOL) _uidRangeOutOfExistsRangeWithFrom:(NSUInteger)fromUid to:(NSUInteger)toUid;

- (NSData *) _removeInvalidHeadersFromMessage: (NSData *) theMessage;

@end


//
//
//
@implementation CWIMAPFolder

- (id) initWithName: (NSString *) theName
{
    self = [super initWithName: theName];
    if (self) {
        self.uidToMsnMap = [NSMutableDictionary new];
        self.msnToUidMap = [NSMutableDictionary new];
        [self setSelected: NO];
    }
    return self;
}


//
//
//
- (id) initWithName: (NSString *) theName
               mode: (PantomimeFolderMode) theMode
{
    self = [self initWithName: theName];
    if (self) {
        _mode = theMode;
    }
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

- (void)appendMessageFromRawSource:(NSData *)rawSource
                             flags:(CWFlags * _Nullable)flags
                      internalDate:(NSDate * _Nullable)date;
{
    NSString *flagsAsString = @"";
    if (flags) {
        flagsAsString = [flags asString];
    }

    // We remove any invalid headers from our message
    NSData *dataToAppend = [self _removeInvalidHeadersFromMessage: rawSource];

    NSDictionary *aDictionary;
    if (flags) {
        aDictionary = @{@"NSDataToAppend":dataToAppend,
                        @"NSData":rawSource,
                        @"Folder":self,
                        PantomimeFlagsKey:flags};
    } else {
        aDictionary = @{@"NSDataToAppend":dataToAppend,
                        @"NSData":rawSource,
                        @"Folder":self};
    }
    if (!date) {
        date = [NSDate new];
    }
    NSAssert(date, @"Must not be nil");

    [_store sendCommand: IMAP_APPEND
                   info: aDictionary
              arguments: @"APPEND \"%@\" (%@) \"%@\" {%d}", // IMAP command
     [_name modifiedUTF7String],                            // folder name
     flagsAsString,                                         // flags
     [date dateTimeString],                                 // Internal date
     [dataToAppend length]];                                // length of the data to write
}

#pragma mark - UID COPY

// Implementation of UID COPY
// (see https://tools.ietf.org/html/rfc3501#section-6.4.8)
- (void)copyMessageWithUid:(NSUInteger)uid toFolderNamed:(NSString *)targetFolderName;
{
    NSParameterAssert(uid > 0);

    [_store sendCommand: IMAP_UID_COPY
                   info: nil
              arguments: @"UID COPY %u \"%@\"", uid, [targetFolderName modifiedUTF7String]];
}

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

#pragma mark - UID MOVE

// Basic implementation of the UID MOVE extension(see RFC-6851)
- (void)moveMessageWithUid:(NSUInteger)uid toFolderNamed:(NSString *)targetFolderName;
{
    NSParameterAssert(uid > 0);

    [_store sendCommand: IMAP_UID_MOVE
                   info: nil
              arguments: @"UID MOVE %u \"%@\"", uid, [targetFolderName modifiedUTF7String]];
}

#pragma mark - Fetching

// Fetches fetchMaxMails number of (yet unfetched) older messages by MSN.
// Fetching by UID did not work. Here is why:
//
// |<----------------------------- Existing messages on server (self.existsCount == 20) ---------------------------------->|
// Sequence numbers:
// |  1  |  2  |  3  |  4  |  5  |  6  |  7  |  8  |  9  |  10 |  11 |  12 |  13 |  14 |  15 |  16 |  17 |  18 |  19 |  20 |
// UIDs:
// |  4  |  5  |  6  |  7  |  8  |  9  | 10  | 108 | 109 | 110 |  11 | 112 | 313 | 314 | 415 | 416 | 417 | 418 | 519 | 520 |
//                                           |<---- allready fetched ----->|
//                                           |<------ fetchedRange ------->|
//                                              ^                       ^
//                                              |                       |
//                                           firstUid                lastUid
// We want this:     |<--- fetchMaxMails --->|
//                                           |
//                                 UID gap 11 - 107
//
// The Problem is that the UIDs are not sequential.
// uidGap: 108 - 10 - 1 == 97
// Handling the UID gap by making multiple calls can cause many, many calls (num calls ~= uidGap / fetchMaxMails)
// which might even be punished by the provider by denying access due to assumed DOS attempt. Temporarly or forever.
// Thus we are fetching by MSNs.
- (void) fetchOlder
{
    if ([self isFirstCallToFetchOlder]) {
        [self fetchOlderProtected];
    }
}


// We want to always have a closed fetchedRange.
// In other words, we do not want to have multible fetchedRanges.
// Thus we adjust fromUid and toUid accordingly, if required.
//
// Example:
//
// |<----------------------------- Existing messages on server (self.existsCount == 20) ---------------------------------->|
// Sequence numbers:
// |  1  |  2  |  3  |  4  |  5  |  6  |  7  |  8  |  9  |  10 |  11 |  12 |  13 |  14 |  15 |  16 |  17 |  18 |  19 |  20 |
// UIDs:
// |  4  |  5  |  6  |  7  |  8  |  9  | 10  | 108 | 109 | 110 |  11 | 112 | 313 | 314 | 415 | 416 | 417 | 418 | 519 | 520 |
//                                           |<---- allready fetched ----->|
//                                           |<------ fetchedRange ------->|
//                                              ^                       ^
//                                              |                       |
//                                           firstUid                lastUid
//---------------------------------------------------------------------------------------------------------------------------
// case 1:
//                                                   |                 |
//                                                fromUid            toUid
//          Range already fetched. Do nothing.
//---------------------------------------------------------------------------------------------------------------------------
// case 2:
//          before:
//                                                                                  |               |
//                                                                               fromUid          toUid
//          Would result in a second fetchedRange. Move "fromUid" down.
//          after:
//                                                                              |<---               |
//                                                                           fromUid              toUid
//---------------------------------------------------------------------------------------------------------------------------
// case 3:
//          before:
//                |               |
//             fromUid          toUid
//          Would result in a second fetchedRange. Move "toUid" up.
//          after:
//                |                ---->|
//             fromUid                toUid
//---------------------------------------------------------------------------------------------------------------------------
// case 4:
//          before:
//                                                                    |                        |
//                                                                 fromUid                   toUid
//          "fromUid" is in fetchedRange. Move it up.
//          after:
//                                                                     --->|                   |
//                                                                      fromUid              toUid
//---------------------------------------------------------------------------------------------------------------------------
// case 5:
//          before:
//                     |                           |
//                  fromUid                      toUid
//          "toUid" is in fetchedRange. Move it down.
//          after:
//                     |                |<---------
//                  fromUid           toUid
//---------------------------------------------------------------------------------------------------------------------------
// case 6:
//          before:
//                            |                                                            |
//                         fromUid                                                       toUid
//          fetchedRange is included in fromUid-toUid range.
//          We ignore this fact and fetch the messaged in fetchedRange again.
//---------------------------------------------------------------------------------------------------------------------------
// case 7:
//          Nothing has been fetched yet. We get the last fetchMaxMails numbers of *sequence* numbers.
//                            |<----------------------------------- fetchMaxMails --------------------------------------->|
//                     fromSequenceNum                                                                          toSequenceNum
//---------------------------------------------------------------------------------------------------------------------------
#define UNLIMITED NSIntegerMin
- (void) fetchFrom:(NSUInteger)fromUid to:(NSInteger)toUid
{
    // Invalid input. Do nothing.
    if (fromUid == 0 || fromUid > toUid) {
        LogWarn(@"Invalid input.");
        // Inform the client
        [_store signalFolderFetchCompleted];
        return;
    }

    // No messages on server (EXISTS count is 0)
    if (![self messagesExistOnServer]) {
        [_store signalFolderFetchCompleted];
        return;
    }

    // case 1
    if ([self _uidRangeAllreadyFetchedWithFrom:fromUid to:toUid]) {
        // No reason to fetch, inform the client
        [_store signalFolderFetchCompleted];
        return;
    }

    NSInteger from = fromUid;
    NSInteger to = toUid;

    // case 4
    from = [self _isInFetchedRange:from] ? [self lastUID] + 1 : from;

    // case 5
    to = [self _isInFetchedRange:to] ? [self firstUID] - 1 : to;

    if ([self _wouldCreatedUpperFetchedRangeWithFrom:from to:to]) {
        // case 2
        from = [self lastUID] + 1;
    } else if ([self _wouldCreatedLowerFetchedRangeWithFrom:from to:to]) {
        // case 3
        to = [self firstUID] - 1;
    }

    NSString *toString = (toUid == UNLIMITED) ? @"*" : [NSString stringWithFormat:@"%ld", (long)to];

    [_store sendCommand: IMAP_UID_FETCH_RFC822  info: nil
              arguments: @"UID FETCH %u:%@ (UID FLAGS BODY.PEEK[])", from, toString];
}


//
//
//
- (void) fetch
{
    // Maximum number of mails to fetch
    NSInteger fetchMaxMails = [self maximumNumberOfMessagesToFetch];

    if ([self lastUID] > 0) {
        // We already fetched mails before, so lets fetch all newer ones by UID
        NSInteger fromUid = [self lastUID] + 1;
        fromUid = fromUid <= 0 ? 1 : fromUid;
        [self fetchFrom:fromUid to:UNLIMITED];
    } else {
        LogInfo(@"no messages, fetching from scratch");
        // case 7
        // Local cache seems to be empty. Fetch a maximum of fetchMaxMails newest mails
        // with a simple FETCH by sequnce numbers
        NSInteger upperMessageSequenceNumber = [self existsCount];
        LogInfo(@"existsCount %ld", (long) upperMessageSequenceNumber);
        if (upperMessageSequenceNumber == 0) {
            // nothing to fetch
            [_store signalFolderFetchCompleted];
            return;
        } else {
            NSInteger lowerMessageSequenceNumber = upperMessageSequenceNumber - fetchMaxMails + 1;
            lowerMessageSequenceNumber = MAX(1, lowerMessageSequenceNumber);
            [_store sendCommand: IMAP_UID_FETCH_RFC822  info: nil
                      arguments: @"FETCH %u:%u (UID FLAGS BODY.PEEK[])",
             lowerMessageSequenceNumber,
             upperMessageSequenceNumber];
        }
    }
}


//
//
//
/**
 Note:  The whole thing is a hack.
        Usecase is to ignore pEp-auto-consumable messages in new mails count.
        Correct would be to fetch the headers and handle affected messages on a higher level.
        We did it like this as the high level operation is extremely timing critical (background fetch).
 */
- (void)fetchUidsForNewMails;
{
    NSInteger lastUid = [self lastUID] ? [self lastUID] : 0;
    NSInteger from = lastUid + 1;
    [_store sendCommand: IMAP_UID_FETCH_UIDS  info:nil arguments:@"UID FETCH %u:* (UID)", from];
}

#pragma mark -

- (void)syncExistingFirstUID:(NSUInteger)firstUID lastUID:(NSUInteger)lastUID
{
    if (firstUID <= lastUID && firstUID > 0) {
        LogInfo(@"sync existing %lu:%lu", (unsigned long) firstUID, (unsigned long) lastUID);
        [_store sendCommand: IMAP_UID_FETCH_FLAGS  info: nil
                  arguments: @"UID FETCH %u:%u (FLAGS)", firstUID, lastUID];
    } else {
        LogError(@"UID FETCH %lu:%lu (FLAGS)", (unsigned long) firstUID, (unsigned long) lastUID);
        [_store signalFolderSyncError];
    }
}

//
// This method simply close the selected mailbox (ie. folder)
//
- (void)close
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

    // We avoid to call IMAP_CLOSE and call SELECT for a non-existing mailbox (aka. folder).
    // See: RFC4549-4.2.5
  if ([_store isConnected] && ![self showDeleted])
    {
      [_store sendCommand: IMAP_SELECT  info: nil  arguments: @"SELECT \"%@\"",
       [PantomimeFolderNameToIgnore modifiedUTF7String]];
    }
  else
    {
      PERFORM_SELECTOR_2([_store delegate], @selector(folderCloseCompleted:), PantomimeFolderCloseCompleted, self, @"Folder");
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
  if (theFlags->flags == 0 && aMessage)
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

- (NSUInteger) lastMSN
{
    return self.allMessages.count;
}

- (NSUInteger) firstUID
{
    return [[self allMessages] firstObject] ? [[[self allMessages] firstObject] UID] : 0;
}

- (NSUInteger) lastUID
{
    return [[self allMessages] lastObject] ? [[[self allMessages] lastObject] UID] : 0;
}

- (CWIMAPMessage * _Nullable)messageByUID:(NSUInteger)uid
{
    return nil;
}

- (void)matchUID:(NSUInteger)uid withMSN:(NSUInteger)msn
{
    [self.msnToUidMap setObject:[NSNumber numberWithUnsignedInteger:uid]
                         forKey:[NSNumber numberWithUnsignedInteger:msn]];
    [self.uidToMsnMap setObject:[NSNumber numberWithUnsignedInteger:msn]
                         forKey:[NSNumber numberWithUnsignedInteger:uid]];
}

- (NSUInteger)uidForMSN:(NSUInteger)msn
{
    return [[self.msnToUidMap objectForKey:[NSNumber numberWithUnsignedInteger:msn]]
            unsignedIntegerValue];
}

- (NSUInteger)msnForUID:(NSUInteger)uid
{
    return [[self.uidToMsnMap objectForKey:[NSNumber numberWithUnsignedInteger:uid]]
            unsignedIntegerValue];
}

- (BOOL)existsUID:(NSUInteger)uid
{
    return [self.uidToMsnMap objectForKey:[NSNumber numberWithUnsignedInteger:uid]] != nil;
}

- (NSSet * _Nonnull)existingUIDs
{
    return [NSSet setWithArray:self.uidToMsnMap.allKeys];
}

- (void)resetMatchedUIDs
{
    [self.uidToMsnMap removeAllObjects];
    [self.msnToUidMap removeAllObjects];
}

- (void)expungeMSN:(NSUInteger)msn
{
    NSArray<NSNumber *> *keysAsc = [self.uidToMsnMap
                                    keysSortedByValueUsingSelector:@selector(unsignedIntegerValue)];
    if (keysAsc.count) {
        NSUInteger lowest = [[keysAsc firstObject] unsignedIntegerValue];
        NSNumber *highestKey = [keysAsc lastObject];
        if (msn >= lowest) {
            NSArray<NSNumber *> *keysDesc = [[keysAsc reverseObjectEnumerator] allObjects];
            NSArray<NSNumber *> *toRework = [keysDesc
                                             filteredArrayUsingPredicate:
                                             [NSPredicate
                                              predicateWithFormat:@"integerValue > %d", msn]];
            for (NSNumber *num in toRework) {
                NSNumber *value = [self.uidToMsnMap objectForKey:num];
                [self.uidToMsnMap setObject:value forKey:[NSNumber numberWithInt:num.intValue - 1]];
            }
            [self.uidToMsnMap removeObjectForKey:highestKey];
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
- (BOOL) _isInFetchedRange:(NSUInteger)uid
{
    return [self firstUID] <= uid && uid <= [self lastUID];
}


//
//
//
- (BOOL) _wouldCreatedUpperFetchedRangeWithFrom:(NSUInteger)fromUid to:(NSUInteger)toUid
{
    return [self previouslyFetchedMessagesExist] && fromUid > [self lastUID] + 1;
}


//
//
//
- (BOOL) _wouldCreatedLowerFetchedRangeWithFrom:(NSUInteger)fromUid to:(NSUInteger)toUid
{
    return [self previouslyFetchedMessagesExist] && toUid < [self firstUID] - 1;
}


//
//
//
- (BOOL) _isNegativeUid:(NSInteger)uid
{
    return (UNLIMITED < uid && uid < 0);
}


//
//
//
- (BOOL) _uidRangeAllreadyFetchedWithFrom:(NSUInteger)fromUid to:(NSUInteger)toUid
{
    return [self _isInFetchedRange:fromUid] && [self _isInFetchedRange:toUid];
}


//
//
//
- (BOOL) _uidRangeOutOfExistsRangeWithFrom:(NSUInteger)fromUid to:(NSUInteger)toUid
{
    return self.existsCount == 0 || fromUid == 0 || toUid > self.existsCount;
}


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

