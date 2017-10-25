//
//  CWIMAPFolder+CWProtected.h
//  PantomimeTests
//
//  Created by Andreas Buff on 25.10.17.
//  Copyright © 2017 pEp Security S.A. All rights reserved.
//

#import "CWIMAPFolder.h"

@interface CWIMAPFolder(CWProtected)

/**
 Fetches  fetchMaxMails number of older messages with decreasing MSN, starting from MSN of oldest local message - 1.
 Internally the method must be called twice until messages are fetched. The first call triggers an MSN update for the oldest local message, the second call actually fetches older messages.
 To figure out if it has be called one more time, call fetchOlderNeedsReCall:
 */
- (void) fetchOlderProtected;

/**
 Whether or not you need to call fetchOlder() again to actually get messages.
 See fetchOlder() for details.

 @return YES, if the last call to fetchOlder: did not fetch any messages, NO: otherwize
 */
- (BOOL)fetchOlderNeedsReCall;

- (BOOL) messagesExistOnServer;

- (BOOL) previouslyFetchedMessagesExist;

- (BOOL)isFirstCallToFetchOlder;

/**
 The max number of mails that must be fetched.

 @return max number of mails to fetch
 */
- (NSUInteger)maximumNumberOfMessagesToFetch;

@end
