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
#import "Pantomime/CWIMAPStore+Protected.h"
#import "Pantomime/CWIMAPMessage.h"
#import "Pantomime/CWLogger.h"
#import "Pantomime/NSData+Extensions.h"
#import "Pantomime/NSString+Extensions.h"

#import "NSDate+RFC2822.h"

typedef enum {
    CWIMAPFolderFetchTypeNone = 0,
    CWIMAPFolderFetchTypeFetchOlder,
    CWIMAPFolderFetchTypeFetch
} CWIMAPFolderFetchType;

@interface CWIMAPFolder ()
@property NSMutableDictionary *uidToMsnMap;
@property NSMutableDictionary *msnToUidMap;

/** 
 The fromUID of the last fetchOlder performed. Used to 
 figure out if we did fetch messages when fetching fetchOlder()  */

@property NSUInteger lastFetcheOlderFromUid;
/**
 The type  of the last fetchOlder performed. Used to
 figure out if we need to call fetchOlder() again to receive older messages */

@property CWIMAPFolderFetchType lastFetchType;
@end

//
// Private methods
//
@interface CWIMAPFolder (Private)

- (NSUInteger)_maximumNumberOfMessagesToFetch;

- (BOOL) _uidAlreadyFetched:(NSUInteger)uid;

- (BOOL) _isInFetchedRange:(NSUInteger)uid;

- (BOOL)_fetchedOlderBefore;

- (BOOL)fetchedNothingOnLastFetchOlder;

- (BOOL) _wouldCreatedUpperFetchedRangeWithFrom:(NSUInteger)fromUid to:(NSUInteger)toUid;

- (BOOL) _wouldCreatedLowerFetchedRangeWithFrom:(NSUInteger)fromUid to:(NSUInteger)toUid;

- (BOOL) _previouslyFetchedMessagesExist;

- (BOOL) _messagesExistOnServer;

- (BOOL) _noOlderMessagesExistOnServer;

- (BOOL) _allMessagesHaveBeenFetched;

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
  if ((self = [super initWithName: theName]) == nil)
    return nil;

    self.lastFetchType = CWIMAPFolderFetchTypeNone;
    self.lastFetcheOlderFromUid = NSIntegerMax;
    self.uidToMsnMap = [NSMutableDictionary new];
    self.msnToUidMap = [NSMutableDictionary new];
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

#pragma mark - Fetching

// fetchOlder wants to fetch fetchMaxMails number of (yet unfetched) older messages by UID:
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
//
// The Problem is that the UIDs are not sequential, which is why we might have to call fetchOlder multiple times.
// uidGap: 108 - 10 - 1 == 97
// Example using the numbers from the table above:
//
//Case fetchOlder1
//
// Problem: due to the non-sequecial UIDs (..., 9, 10, 108, ...), the logic "from = [self firstUID] - fetchMaxMails" might not work.
// In the above Example:
// 1st fetchOlder call:
// fetchMaxMails = 20, from = [self firstUID] - fetchMaxMails == 88, to = [self firstUID] - 1 == 107
// -> nothing fetched in UID range 88-107
// 2nd fetchOlder call:
// lastFetcheOlderFromUid == 88, from = 88  - fetchMaxMails == 68, to = [self firstUID] - 1	 == 107
// -> nothing fetched in UID range 68-107
// ...
// 5th fetchOlder call:
// lastFetcheOlderFromUid == 28, from = 28 - fetchMaxMails == 8, to = [self firstUID] - 1 == 107
// -> fetched in UID range 8-107 (3 messages. 8,9,10)
//
// We have to see if this works out.
// Possible Problems:
// - fetchOlder is called uidGap / fetchMaxMails times. This can be often and might potentially even cause being punished by the provider (access denied times)
// Possible solution:
// - double the fetch range on every call to fetchOlder. This migh cause fetching a lot of mails in the end though.
// - Fetch by msg numbers instead of UIDs. This might result in missing emails as msg numbers might be outdated.
- (void) fetchOlder
{
    if ([self _noOlderMessagesExistOnServer] ||
        ![self _messagesExistOnServer] ||
        [self _allMessagesHaveBeenFetched]) {
        // No need to fetch. Inform the client
        [_store signalFolderFetchCompleted];
        return;
    }

    self.lastFetchType = CWIMAPFolderFetchTypeFetchOlder;

    if (![self _previouslyFetchedMessagesExist]) {
        // We did never fetch messages. fetchOlder is the wrong method to handle this case.
        self.lastFetcheOlderFromUid = 0;
        [_store signalFolderFetchCompleted];
        return;
    }

    NSInteger toUid = [self firstUID] - 1;
    toUid = MAX(1, toUid);

    // Maximum number of mails to fetch
    NSInteger fetchMaxMails = [self _maximumNumberOfMessagesToFetch];
    NSInteger fromUid = 0;
    if ([self fetchedNothingOnLastFetchOlder]) {
        //Case fetchOlder1
        // Due non-sequential UIDs we did not fetch anything.
        // Increase the UID range to fetch
        fromUid = self.lastFetcheOlderFromUid - fetchMaxMails;
    } else {
        fromUid = [self firstUID] - fetchMaxMails;
    }
    fromUid = MAX(1, fromUid);

    self.lastFetcheOlderFromUid = fromUid;
//    INFO(NSStringFromClass([self class]), @"Trying to fetchOlder fromUid: %ld toUid: %ld", (long)fromUid, (long)toUid);
    [self fetchFrom:fromUid to:toUid];
}


//
//
//
- (BOOL)fetchOlderNeedsReCall
{
    return self.lastFetchType == CWIMAPFolderFetchTypeFetchOlder && [self fetchedNothingOnLastFetchOlder];
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
        WARN(NSStringFromClass([self class]), @"Invalid input.");
        // Inform the client
        [_store signalFolderFetchCompleted];
        return;
    }

    // No messages on server (EXISTS count is 0)
    if (![self _messagesExistOnServer]) {
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
    NSInteger fetchMaxMails = [self _maximumNumberOfMessagesToFetch];

    self.lastFetchType = CWIMAPFolderFetchTypeFetch;
    if ([self lastUID] > 0) {
        // We already fetched mails before, so lets fetch all newer ones by UID
        NSInteger fromUid = [self lastUID] + 1;
        fromUid = fromUid <= 0 ? 1 : fromUid;
        [self fetchFrom:fromUid to:UNLIMITED];
    } else {
        //case 7
        // Local cache seems to be empty. Fetch a maximum of fetchMaxMails newest mails
        // with a simple FETCH by sequnce numbers
        NSInteger upperMessageSequenceNumber = [self existsCount];
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

#pragma mark -

- (void)syncExistingFirstUID:(NSUInteger)firstUID lastUID:(NSUInteger)lastUID
{
    if (firstUID <= lastUID && firstUID > 0) {
        [_store sendCommand: IMAP_UID_FETCH_FLAGS  info: nil
                  arguments: @"UID FETCH %u:%u (FLAGS)", firstUID, lastUID];
    } else {
        ERROR(NSStringFromClass([self class]),
              @"UID FETCH %lu:%lu (FLAGS)", (unsigned long) firstUID, (unsigned long) lastUID);
        [_store signalFolderSyncError];
    }
}

//
// This method simply close the selected mailbox (ie. folder)
//
- (void) close
{
  IMAPCommand theCommand;

  self.lastFetchType = CWIMAPFolderFetchTypeNone;
  self.lastFetcheOlderFromUid = NSIntegerMax;

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

- (NSUInteger)_maximumNumberOfMessagesToFetch
{
    return  [((CWIMAPStore *) [self store]) maxFetchCount];
}


//
//
//
- (BOOL) _uidAlreadyFetched:(NSUInteger)uid
{
    return [self _isInFetchedRange:uid];
}


//
//
//
- (BOOL)_fetchedOlderBefore
{
    return self.lastFetcheOlderFromUid != 0 && self.lastFetcheOlderFromUid != NSIntegerMax;
}


//
//
//
- (BOOL)fetchedNothingOnLastFetchOlder
{
    return [self _fetchedOlderBefore] && self.lastFetcheOlderFromUid < [self firstUID];
}


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
    return [self _previouslyFetchedMessagesExist] && fromUid > [self lastUID] + 1;
}


//
//
//
- (BOOL) _wouldCreatedLowerFetchedRangeWithFrom:(NSUInteger)fromUid to:(NSUInteger)toUid
{
    return [self _previouslyFetchedMessagesExist] && toUid < [self firstUID] - 1;
}


//
//
//
- (BOOL) _previouslyFetchedMessagesExist
{
    return [self firstUID] != 0 && [self lastUID] != 0;
}


//
//
//
- (BOOL) _messagesExistOnServer
{
    return self.existsCount > 0;
}


//
//
//
- (BOOL) _noOlderMessagesExistOnServer
{
    return [self firstUID] == 1;
}


//
//
//
- (BOOL) _allMessagesHaveBeenFetched
{
    return self.allMessages.count == self.existsCount;
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

