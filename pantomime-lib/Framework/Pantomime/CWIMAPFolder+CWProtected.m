//
//  CWIMAPFolder+CWProtected.m
//  PantomimeTests
//
//  Created by Andreas Buff on 25.10.17.
//  Copyright © 2017 pEp Security S.A. All rights reserved.
//

#import "CWIMAPFolder+CWProtected.h"

#import "Pantomime/CWIMAPStore+Protected.h"

#pragma mark - Private Methods

@interface CWIMAPFolder (Private)
- (BOOL) _noOlderMessagesExistOnServer;
- (BOOL) _allMessagesHaveBeenFetched;
@end

@interface CWIMAPFolder()
/** Indicates fetchOlder: is currently updating the MSN */
@property BOOL isUpdatingMessageNumber;
@end

@implementation CWIMAPFolder(CWProtected)

/**
 Fetches  fetchMaxMails number of older messages with decreasing MSN, starting from MSN of oldest local message - 1.
 Internally the method must be called twice until messages are fetched. The first call triggers an MSN update for the oldest local message, the second call actually fetches older messages.
 To figure out if it has be called one more time, call fetchOlderNeedsReCall:
 */
- (void) fetchOlderProtected;
{
    if ([self _noOlderMessagesExistOnServer] ||
        ![self messagesExistOnServer] ||
        [self _allMessagesHaveBeenFetched]) {
        // No need to fetch. Inform the client
        self.isUpdatingMessageNumber = NO;
        [_store signalFolderFetchCompleted];
        return;
    }

    if (![self previouslyFetchedMessagesExist]) {
        // We did never fetch messages. fetchOlder is the wrong method to handle this case.
        [_store signalFolderFetchCompleted];
        return;
    }

    NSUInteger uidOfOldestLocalMesssage = [self firstUID];

    // First fetch again the oldest message we have to update its sequence number (MSN)
    if ([self isFirstCallToFetchOlder]) {
        [_store sendCommand: IMAP_UID_FETCH_RFC822 info: nil
                  arguments: @"UID FETCH %u:%u (UID)", uidOfOldestLocalMesssage, uidOfOldestLocalMesssage];
        self.isUpdatingMessageNumber = YES;
        return;
    }

    // After first fetch returned, we fetch fetchMaxMails number of older emails by MSNs
    self.isUpdatingMessageNumber = NO;


    NSUInteger msnOfOldestLocalMessage = [self msnForUID:uidOfOldestLocalMesssage];
    if (!msnOfOldestLocalMessage || msnOfOldestLocalMessage == 1) {
        // We either do not know the MSN for some reason (and thus can not fetch older)
        // or we already fetched all old mails.
        // Do nothing.
        [_store signalFolderFetchCompleted];
        return;
    }
    NSUInteger fromMSN = msnOfOldestLocalMessage - [self maximumNumberOfMessagesToFetch];
    fromMSN = MAX(1, fromMSN);
    NSUInteger toMSN = msnOfOldestLocalMessage - 1;

    [_store sendCommand: IMAP_UID_FETCH_RFC822
                   info: nil
              arguments: @"FETCH %u:%u (UID FLAGS BODY.PEEK[])", fromMSN, toMSN];
}


//
//
//
- (BOOL)fetchOlderNeedsReCall
{
    return self.isUpdatingMessageNumber;
}

//
//
//
- (NSUInteger)maximumNumberOfMessagesToFetch
{
    return  [((CWIMAPStore *) [self store]) maxFetchCount];
}


//
//
//
- (BOOL)isFirstCallToFetchOlder
{
    return !self.isUpdatingMessageNumber;
}


//
//
//
- (BOOL) messagesExistOnServer
{
    return self.existsCount > 0;
}


//
//
//
- (BOOL) previouslyFetchedMessagesExist
{
    return [self firstUID] != 0 && [self lastUID] != 0;
}

@end

#pragma mark - Private Methods Impl

//
//
//
@implementation CWIMAPFolder (Private)


//
//
//
- (BOOL) _noOlderMessagesExistOnServer
{
    return [self firstUID] == 1 || [self msnForUID:[self firstUID]] == 1;
}


//
//
//
- (BOOL) _allMessagesHaveBeenFetched
{
    return self.allMessages.count == self.existsCount;
}

@end
