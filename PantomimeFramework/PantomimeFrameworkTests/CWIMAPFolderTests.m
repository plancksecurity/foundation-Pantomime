//
//  FolderTests.m
//  Pantomime
//
//  Created by Dirk Zimmermann on 02/12/16.
//  Copyright © 2016 pEp Security S.A. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "Pantomime.h"
#import "CWIMAPStore+Protected.h"
#import "CWIMAPFolder+CWProtected.h"
#import "TestUtil.h"

#pragma mark - Helper Classes

#define IGNORE  NSIntegerMin

@interface TestCWIMAPStore : CWIMAPStore
@property (nonatomic, copy, nonnull)
void (^assertionBlockForSendCommandInfoArguments)(IMAPCommand, NSDictionary *, NSString *);
@property (nonatomic, copy, nonnull)
void (^assertionBlockForSignalFolderFetchNothingToFetch)(void);
@end
@implementation TestCWIMAPStore
// overrride methods to get test feedback
- (void) sendCommand: (IMAPCommand) theCommand  info: (NSDictionary *) theInfo
           arguments: (NSString *) theFormat, ...NS_REQUIRES_NIL_TERMINATION;
{
    va_list args;
    va_start(args, theFormat);
    NSString *argsResolved = [[NSString alloc] initWithFormat:theFormat arguments:args];
    va_end(args);
    
    if (self.assertionBlockForSendCommandInfoArguments) {
        self.assertionBlockForSendCommandInfoArguments(theCommand, theInfo, argsResolved);
    }
}
- (void)signalFolderFetchCompleted
{
    if (self.assertionBlockForSignalFolderFetchNothingToFetch) {
        self.assertionBlockForSignalFolderFetchNothingToFetch();
    }
}
@end

@interface FechTestCWIMAPFolder: CWIMAPFolder
@property NSUInteger testFirstUID;
@property NSUInteger testLastUID;
@property NSUInteger msnOfOldestLocalMessage;
@end
@implementation FechTestCWIMAPFolder
- (NSUInteger) firstUID { return self.testFirstUID; }
- (NSUInteger)lastUID { return self.testLastUID; }
- (BOOL)isFirstCallToFetchOlder
{
    return NO;
}
- (NSUInteger)msnForUID:(NSUInteger)uid
{
    return self.msnOfOldestLocalMessage;
}
@end

#pragma mark - Test

@interface FolderTests : XCTestCase
@property (nonatomic) TestCWIMAPStore *testStore;
@property (nonatomic) FechTestCWIMAPFolder *testFolder;
@end

@implementation FolderTests

- (void)testExpungedMSN
{
    const NSUInteger numberOfMSNs = 11;
    const NSUInteger expungedMSN = 5;
    
    CWIMAPFolder *folder = [[CWIMAPFolder alloc] initWithName:@"name"];
    
    for (int i = 1; i < numberOfMSNs; ++i) {
        [folder matchUID:i withMSN:i];
    }
    
    for (int i = 1; i < numberOfMSNs; ++i) {
        XCTAssertEqual([folder uidForMSN:i], i);
    }
    
    [folder expungeMSN:expungedMSN];
    
    for (int i = 1; i < expungedMSN + 1; ++i) {
        XCTAssertEqual([folder uidForMSN:i], i);
    }
    
    for (int i = expungedMSN + 1; i < numberOfMSNs; ++i) {
        XCTAssertEqual([folder uidForMSN:i], i);
    }
}

#pragma mark - fetchFrom:to:

// |<------------------ Existing messages on server (self.existsCount == 20) ------------------------->|
// | 1  | 2  | 3  | 4  | 5  | 6  | 7  | 8  | 9  | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 |
//                                              |<-- allready fetched -->|
//                                              |<---- fetchedRange ---->|
//                                                 ^                   ^
//                                                 |                   |
//                                              firstUid            lastUid
//------------------------------------------------------------------------------------------------------
// case 1:
//                                                      |             |
//                                                     from           to
//          Range already fetched. Do nothing.
//------------------------------------------------------------------------------------------------------
- (void)testFetchFromTo_alreadyFetched
{
    NSInteger numMessagesOnServer = 20;
    NSInteger fetchedRangeFirstUid = 10;
    NSInteger fetchedRangeLastUid = 14;
    NSInteger from = 11;
    NSInteger to = 14;
    BOOL shouldSignalNothingNeedsToBeFetched = YES;
    BOOL succeeded = NO;
    [self setupFolderFetchTestWithMaxFetchNum:0
                          numMessagesOnServer:numMessagesOnServer
                      msnOfOldestLocalMessage: nil
                          firstFetchedRageUid:fetchedRangeFirstUid
                           lastFetchedRageUid:fetchedRangeLastUid
                   expectedSendCommandFromUid:0
                     expectedSendCommandToUid:0
             shouldSignalFolderFetchCompleted:shouldSignalNothingNeedsToBeFetched
                                      success:&succeeded];
    [self.testFolder fetchFrom:from to:to];
    XCTAssertTrue(succeeded);
}

// |<------------------ Existing messages on server (self.existsCount == 20) ------------------------->|
// | 1  | 2  | 3  | 4  | 5  | 6  | 7  | 8  | 9  | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 |
//                                              |<-- allready fetched -->|
//                                              |<---- fetchedRange ---->|
//                                                 ^                   ^
//                                                 |                   |
//                                              firstUid            lastUid
//------------------------------------------------------------------------------------------------------
// case 2:
//          before:
//                                                                               |             |
//                                                                             from            to
//          Would result in a second fetchedRange. Move "from" down.
//          after:
//                                                                          |<---------        |
//                                                                        from                 to
//------------------------------------------------------------------------------------------------------
- (void)testFetchFromTo_NoAdditionalFetchedRangeAbove
{
    NSInteger numMessagesOnServer = 20;
    NSInteger fetchedRangeFirstUid = 10;
    NSInteger fetchedRangeLastUid = 14;
    NSInteger from = 16;
    NSInteger to = 19;
    NSUInteger expectedFrom = 15;
    NSUInteger expectedTo = to;
    BOOL shouldSignalNothingNeedsToBeFetched = NO;
    BOOL succeeded = NO;
    [self setupFolderFetchTestWithMaxFetchNum:0
                          numMessagesOnServer:numMessagesOnServer
                      msnOfOldestLocalMessage: nil
                          firstFetchedRageUid:fetchedRangeFirstUid
                           lastFetchedRageUid:fetchedRangeLastUid
                   expectedSendCommandFromUid:expectedFrom
                     expectedSendCommandToUid:expectedTo
             shouldSignalFolderFetchCompleted:shouldSignalNothingNeedsToBeFetched
                                      success:&succeeded];
    [self.testFolder fetchFrom:from to:to];
    XCTAssertTrue(succeeded);
}

// | 1  | 2  | 3  | 4  | 5  | 6  | 7  | 8  | 9  | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 |
//                                              |<-- allready fetched -->|
//                                              |<---- fetchedRange ---->|
//                                                 ^                   ^
//                                                 |                   |
//                                              firstUid            lastUid
//------------------------------------------------------------------------------------------------------
// case 3:
//          before:
//                  |             |
//                from            to
//          Would result in a second fetchedRange. Move "to" up.
//          after:
//                  |              --------->|
//                from                       to
//------------------------------------------------------------------------------------------------------
- (void)testFetchFromTo_NoAdditionalFetchedRangeBelow
{
    NSInteger numMessagesOnServer = 20;
    NSInteger fetchedRangeFirstUid = 10;
    NSInteger fetchedRangeLastUid = 14;
    NSInteger from = 4;
    NSInteger to = 7;
    NSUInteger expectedFrom = from;
    NSUInteger expectedTo = 9;
    BOOL shouldSignalNothingNeedsToBeFetched = NO;
    BOOL succeeded = NO;
    [self setupFolderFetchTestWithMaxFetchNum:0
                          numMessagesOnServer:numMessagesOnServer
                      msnOfOldestLocalMessage: nil
                          firstFetchedRageUid:fetchedRangeFirstUid
                           lastFetchedRageUid:fetchedRangeLastUid
                   expectedSendCommandFromUid:expectedFrom
                     expectedSendCommandToUid:expectedTo
             shouldSignalFolderFetchCompleted:shouldSignalNothingNeedsToBeFetched
                                      success:&succeeded];
    [self.testFolder fetchFrom:from to:to];
    XCTAssertTrue(succeeded);
}

// |<------------------ Existing messages on server (self.existsCount == 20) ------------------------->|
// | 1  | 2  | 3  | 4  | 5  | 6  | 7  | 8  | 9  | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 |
//                                              |<-- allready fetched -->|
//                                              |<---- fetchedRange ---->|
//                                                 ^                   ^
//                                                 |                   |
//                                              firstUid            lastUid
//------------------------------------------------------------------------------------------------------
// case 4:
//          before:
//                                                                    |                    |
//                                                                  from                   to
//          "from" is in fetchedRange. Move it up.
//          after:
//                                                                  ------->|              |
//                                                                        from             to
//------------------------------------------------------------------------------------------------------
- (void)testFetchFromTo_FromInFetchedRange
{
    NSInteger numMessagesOnServer = 20;
    NSInteger fetchedRangeFirstUid = 10;
    NSInteger fetchedRangeLastUid = 14;
    NSInteger from = 14;
    NSInteger to = 18;
    NSUInteger expectedFrom = 15;
    NSUInteger expectedTo = to;
    BOOL shouldSignalNothingNeedsToBeFetched = NO;
    BOOL succeeded = NO;
    [self setupFolderFetchTestWithMaxFetchNum:0
                          numMessagesOnServer:numMessagesOnServer
                      msnOfOldestLocalMessage: nil
                          firstFetchedRageUid:fetchedRangeFirstUid
                           lastFetchedRageUid:fetchedRangeLastUid
                   expectedSendCommandFromUid:expectedFrom
                     expectedSendCommandToUid:expectedTo
             shouldSignalFolderFetchCompleted:shouldSignalNothingNeedsToBeFetched
                                      success:&succeeded];
    [self.testFolder fetchFrom:from to:to];
    XCTAssertTrue(succeeded);
}

// | 1  | 2  | 3  | 4  | 5  | 6  | 7  | 8  | 9  | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 |
//                                              |<-- allready fetched -->|
//                                              |<---- fetchedRange ---->|
//                                                 ^                   ^
//                                                 |                   |
//                                              firstUid            lastUid
//------------------------------------------------------------------------------------------------------
// case 5:
//          before:
//                            |                         |
//                          from                        to
//          "to" is in fetchedRange. Move it down.
//          after:
//                            |              |<---------
//                          from             to
//------------------------------------------------------------------------------------------------------
- (void)testFetchFromTo_ToInFetchedRange
{
    NSInteger numMessagesOnServer = 20;
    NSInteger fetchedRangeFirstUid = 10;
    NSInteger fetchedRangeLastUid = 14;
    NSInteger from = 6;
    NSInteger to = 11;
    NSUInteger expectedFrom = from;
    NSUInteger expectedTo = 9;
    BOOL shouldSignalNothingNeedsToBeFetched = NO;
    BOOL succeeded = NO;
    [self setupFolderFetchTestWithMaxFetchNum:0
                          numMessagesOnServer:numMessagesOnServer
                      msnOfOldestLocalMessage: nil
                          firstFetchedRageUid:fetchedRangeFirstUid
                           lastFetchedRageUid:fetchedRangeLastUid
                   expectedSendCommandFromUid:expectedFrom
                     expectedSendCommandToUid:expectedTo
             shouldSignalFolderFetchCompleted:shouldSignalNothingNeedsToBeFetched
                                      success:&succeeded];
    [self.testFolder fetchFrom:from to:to];
    XCTAssertTrue(succeeded);
}

// | 1  | 2  | 3  | 4  | 5  | 6  | 7  | 8  | 9  | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 |
//                                              |<-- allready fetched -->|
//                                              |<---- fetchedRange ---->|
//                                                 ^                   ^
//                                                 |                   |
//                                              firstUid            lastUid
//------------------------------------------------------------------------------------------------------
// case 6:
//          before:
//                            |                                                            |
//                          from                                                           to
//          fetchedRange is included in from-to range.
//          We ignore this fact and fetch the messaged in fetchedRange again.
//------------------------------------------------------------------------------------------------------
- (void)testFetchFromTo_FetchedRangeIncluded
{
    NSInteger numMessagesOnServer = 20;
    NSInteger fetchedRangeFirstUid = 10;
    NSInteger fetchedRangeLastUid = 14;
    NSInteger from = 6;
    NSInteger to = 18;
    NSUInteger expectedFrom = from;
    NSUInteger expectedTo = to;
    BOOL shouldSignalNothingNeedsToBeFetched = NO;
    BOOL succeeded = NO;
    [self setupFolderFetchTestWithMaxFetchNum:0
                          numMessagesOnServer:numMessagesOnServer
                      msnOfOldestLocalMessage: nil
                          firstFetchedRageUid:fetchedRangeFirstUid
                           lastFetchedRageUid:fetchedRangeLastUid
                   expectedSendCommandFromUid:expectedFrom
                     expectedSendCommandToUid:expectedTo
             shouldSignalFolderFetchCompleted:shouldSignalNothingNeedsToBeFetched
                                      success:&succeeded];
    [self.testFolder fetchFrom:from to:to];
    XCTAssertTrue(succeeded);
}

- (void)testFetchFromTo_noMailsOnServer
{
    NSInteger numMessagesOnServer = 0;
    NSInteger fetchedRangeFirstUid = 10;
    NSInteger fetchedRangeLastUid = 14;
    NSInteger from = 11;
    NSInteger to = 14;
    BOOL shouldSignalNothingNeedsToBeFetched = YES;
    BOOL succeeded = NO;
    [self setupFolderFetchTestWithMaxFetchNum:0
                          numMessagesOnServer:numMessagesOnServer
                      msnOfOldestLocalMessage: nil
                          firstFetchedRageUid:fetchedRangeFirstUid
                           lastFetchedRageUid:fetchedRangeLastUid
                   expectedSendCommandFromUid:0
                     expectedSendCommandToUid:0
             shouldSignalFolderFetchCompleted:shouldSignalNothingNeedsToBeFetched
                                      success:&succeeded];
    [self.testFolder fetchFrom:from to:to];
    XCTAssertTrue(succeeded);
}

//     | 1  | 2  | 3  | 4  | 5  | 6  | 7  | 8  | 9  | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 |
//     |<-------------------------------------- allready fetched ------------------------------------>|
//     |<---------------------------------------- fetchedRange -------------------------------------->|
//        ^                                                                                         ^
//        |                                                                                         |
//     firstUid                                                                                   lastUid
//------------------------------------------------------------------------------------------------------
// case 6:
//          before:
//  |                                                                                                    |
// from                                                                                                  to
//          fetchedRange is included in from-to range.
//          We ignore this fact and fetch the messaged in fetchedRange again.
//------------------------------------------------------------------------------------------------------
- (void)testFetchFromTo_allFetchedPlusUidsOutOfRange
{
    NSInteger numMessagesOnServer = 19;
    NSInteger fetchedRangeFirstUid = 1;
    NSInteger fetchedRangeLastUid = 19;
    NSInteger from = 0;
    NSInteger to = 20;
    BOOL shouldSignalNothingNeedsToBeFetched = YES;
    BOOL succeeded = NO;
    [self setupFolderFetchTestWithMaxFetchNum:0
                          numMessagesOnServer:numMessagesOnServer
                      msnOfOldestLocalMessage: nil
                          firstFetchedRageUid:fetchedRangeFirstUid
                           lastFetchedRageUid:fetchedRangeLastUid
                   expectedSendCommandFromUid:0
                     expectedSendCommandToUid:0
             shouldSignalFolderFetchCompleted:shouldSignalNothingNeedsToBeFetched
                                      success:&succeeded];
    [self.testFolder fetchFrom:from to:to];
    XCTAssertTrue(succeeded);
}

#pragma mark - fetchOlder

// | 1  | 2  | 3  | 4  | 5  | 6  | 7  | 8  | 9  | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 |
//                                              |<-- allready fetched -->|
//                                              |<---- fetchedRange ---->|
//                                                 ^                   ^
//                                                 |                   |
//                                              firstMsn            lastMsn
//------------------------------------------------------------------------------------------------------
- (void)testFetchOlder
{
    NSInteger maxFetchNum = 2;
    NSInteger msnOfLastLocalMessage = 10;
    NSInteger expectedFetchedFromMsn = msnOfLastLocalMessage - maxFetchNum;
    NSInteger expectedFetchedToMsn = msnOfLastLocalMessage - 1;
    NSInteger numMessagesOnServer = 20;
    NSInteger fetchedRangeFirstUid = 10;
    NSInteger fetchedRangeLastUid = 14;
    BOOL shouldSignalNothingNeedsToBeFetched = NO;
    BOOL succeeded = NO;
    
    [self setupFolderFetchTestWithMaxFetchNum:maxFetchNum
                          numMessagesOnServer:numMessagesOnServer
                      msnOfOldestLocalMessage: @(msnOfLastLocalMessage)
                          firstFetchedRageUid:fetchedRangeFirstUid
                           lastFetchedRageUid:fetchedRangeLastUid
                   expectedSendCommandFromMsn:expectedFetchedFromMsn
                     expectedSendCommandToMsn:expectedFetchedToMsn
             shouldSignalFolderFetchCompleted:shouldSignalNothingNeedsToBeFetched
                                      success:&succeeded];
    [self.testFolder fetchOlderProtected];
    XCTAssertTrue(succeeded);
}

// | 1  | 2  | 3  | 4  | 5  | 6  | 7  | 8  | 9  | 10 |
// |<-- allready fetched -->|
// |<---- fetchedRange ---->|
//    ^                   ^
//    |                   |
//  firstMsn            lastMsn
//------------------------------------------------------------------------------------------------------
- (void)testFetchOlder_noOlderExist
{
    NSInteger maxFetchNum = 2;
    NSInteger msnOfLastLocalMessage = 1;
    NSInteger numMessagesOnServer = 10;
    NSInteger fetchedRangeFirstUid = 1;
    NSInteger fetchedRangeLastUid = 5;
    BOOL shouldSignalNothingNeedsToBeFetched = YES;
    BOOL succeeded = NO;
    [self setupFolderFetchTestWithMaxFetchNum:maxFetchNum
                          numMessagesOnServer:numMessagesOnServer
                      msnOfOldestLocalMessage: @(msnOfLastLocalMessage)
                          firstFetchedRageUid:fetchedRangeFirstUid
                           lastFetchedRageUid:fetchedRangeLastUid
                   expectedSendCommandFromMsn:IGNORE
                     expectedSendCommandToMsn:IGNORE
             shouldSignalFolderFetchCompleted:shouldSignalNothingNeedsToBeFetched
                                      success:&succeeded];
    [self.testFolder fetchOlderProtected];
    XCTAssertTrue(succeeded);
}

// | 1  | 2  | 3  | 4  | 5  | 6  | 7  | 8  | 9  | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 |
//                                              |<-- allready fetched -->|
//                                              |<---- fetchedRange ---->|
//                                                 ^                   ^
//                                                 |                   |
//                                              firstMsn            lastMsn
//------------------------------------------------------------------------------------------------------
- (void)testFetchOlder_maxFetchGreaterExisting
{
    NSInteger maxFetchNum = 100;
    NSInteger msnOfLastLocalMessage = 10;
    NSInteger numMessagesOnServer = 20;
    NSInteger fetchedRangeFirstUid = 10;
    NSInteger fetchedRangeLastUid = 14;
    NSUInteger expectedFrom = 1;
    NSUInteger expectedTo = msnOfLastLocalMessage - 1;
    BOOL shouldSignalNothingNeedsToBeFetched = NO;
    BOOL succeeded = NO;
    
    [self setupFolderFetchTestWithMaxFetchNum:maxFetchNum
                          numMessagesOnServer:numMessagesOnServer
                      msnOfOldestLocalMessage: @(msnOfLastLocalMessage)
                          firstFetchedRageUid:fetchedRangeFirstUid
                           lastFetchedRageUid:fetchedRangeLastUid
                   expectedSendCommandFromMsn:expectedFrom
                     expectedSendCommandToMsn:expectedTo
             shouldSignalFolderFetchCompleted:shouldSignalNothingNeedsToBeFetched
                                      success:&succeeded];
    
    [self.testFolder fetchOlderProtected];
    XCTAssertTrue(succeeded);
}

// firstUid == lastUid == 0
// Expected: Nothing fetched.
// fetchOlder should do nothing if we never fetched before
- (void)testFetchOlder__neverFetchedBefore
{
    NSInteger maxFetchNum = 20;
    NSInteger msnOfLastLocalMessage = 0;
    NSInteger numMessagesOnServer = 20;
    NSInteger fetchedRangeFirstUid = 0;
    NSInteger fetchedRangeLastUid = 0;
    BOOL shouldSignalNothingNeedsToBeFetched = YES;
    BOOL succeeded = NO;
    
    [self setupFolderFetchTestWithMaxFetchNum:maxFetchNum
                          numMessagesOnServer:numMessagesOnServer
                      msnOfOldestLocalMessage: @(msnOfLastLocalMessage)
                          firstFetchedRageUid:fetchedRangeFirstUid
                           lastFetchedRageUid:fetchedRangeLastUid
                   expectedSendCommandFromMsn:IGNORE
                     expectedSendCommandToMsn:IGNORE
             shouldSignalFolderFetchCompleted:shouldSignalNothingNeedsToBeFetched
                                      success:&succeeded];
    [self.testFolder fetchOlderProtected];
    XCTAssertTrue(succeeded);
}

#pragma mark - fetch

// | 1  | 2  | 3  | 4  | 5  | 6  | 7  | 8  | 9  | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 |
//                                              |<-- allready fetched -->|
//                                              |<---- fetchedRange ---->|
//                                                 ^                   ^
//                                                 |                   |
//                                              firstUid            lastUid
//------------------------------------------------------------------------------------------------------
- (void)testFetch_somePreveouslyFetched
{
    NSInteger maxFetchNum = 2;
    NSInteger numMessagesOnServer = 20;
    NSInteger fetchedRangeFirstUid = 10;
    NSInteger fetchedRangeLastUid = 14;
    NSUInteger expectedFrom = 15;
    NSString *expectedTo = @"*";
    
    TestCWIMAPStore *testStore = [[TestCWIMAPStore alloc] init];
    testStore.maxFetchCount = maxFetchNum;
    FechTestCWIMAPFolder *testFolder = [[FechTestCWIMAPFolder alloc] initWithName:@"TestFolder"];
    testFolder.store = testStore;
    testFolder.existsCount = numMessagesOnServer;
    testFolder.testFirstUID = fetchedRangeFirstUid;
    testFolder.testLastUID = fetchedRangeLastUid;
    
    __block BOOL blockCalled = NO;
    testStore.assertionBlockForSendCommandInfoArguments = ^(IMAPCommand command, NSDictionary *info,
                                                            NSString *arguments) {
        blockCalled = YES;
        NSString *expected = [NSString stringWithFormat:@"UID FETCH %lu:%@ (UID FLAGS BODY.PEEK[])",
                              (unsigned long)expectedFrom, expectedTo];
        XCTAssertTrue([expected isEqualToString:arguments]);
    };
    testStore.assertionBlockForSignalFolderFetchNothingToFetch = ^() {
        XCTFail(@"Should not be called");
    };
    
    [testFolder fetch];
    
    XCTAssertTrue(blockCalled);
}

// | 1  | 2  | 3  | 4  | 5  | 6  | 7  | 8  | 9  | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 |
//------------------------------------------------------------------------------------------------------
// firstUid == 0
// lastUid == 0
- (void)testFetch_nothingPreveouslyFetched
{
    NSInteger maxFetchNum = 2;
    NSInteger numMessagesOnServer = 20;
    NSInteger fetchedRangeFirstUid = 0;
    NSInteger fetchedRangeLastUid = 0;
    TestCWIMAPStore *testStore = [[TestCWIMAPStore alloc] init];
    testStore.maxFetchCount = maxFetchNum;
    FechTestCWIMAPFolder *testFolder = [[FechTestCWIMAPFolder alloc] initWithName:@"TestFolder"];
    testFolder.store = testStore;
    testFolder.existsCount = numMessagesOnServer;
    testFolder.testFirstUID = fetchedRangeFirstUid;
    testFolder.testLastUID = fetchedRangeLastUid;
    __block BOOL blockCalled = NO;
    testStore.assertionBlockForSendCommandInfoArguments = ^(IMAPCommand command, NSDictionary *info,
                                                            NSString *arguments) {
        blockCalled = YES;
        [self assertArguments:arguments wouldFetchMSNsFrom:19 to:20];
    };
    testStore.assertionBlockForSignalFolderFetchNothingToFetch = ^() {
        XCTFail(@"Should not be called");
    };
    [testFolder fetch];
    XCTAssertTrue(blockCalled);
}

- (void)testFetch_nothingPreveouslyFetched_maxFetchNumGreaterExistsCount
{
    NSInteger maxFetchNum = 100;
    NSInteger numMessagesOnServer = 20;
    NSInteger fetchedRangeFirstUid = 0;
    NSInteger fetchedRangeLastUid = 0;
    TestCWIMAPStore *testStore = [[TestCWIMAPStore alloc] init];
    testStore.maxFetchCount = maxFetchNum;
    FechTestCWIMAPFolder *testFolder = [[FechTestCWIMAPFolder alloc] initWithName:@"TestFolder"];
    testFolder.store = testStore;
    testFolder.existsCount = numMessagesOnServer;
    testFolder.testFirstUID = fetchedRangeFirstUid;
    testFolder.testLastUID = fetchedRangeLastUid;
    __block BOOL blockCalled = NO;
    testStore.assertionBlockForSendCommandInfoArguments = ^(IMAPCommand command, NSDictionary *info,
                                                            NSString *arguments) {
        blockCalled = YES;
        [self assertArguments:arguments wouldFetchMSNsFrom:1 to:20];
    };
    testStore.assertionBlockForSignalFolderFetchNothingToFetch = ^() {
        XCTFail(@"Should not be called");
    };
    [testFolder fetch];
    XCTAssertTrue(blockCalled);
}

#pragma mark - Helpers

- (NSNumber *)firstGreaterOrEqual:(NSNumber *)num in:(NSArray<NSNumber*> *)array
{
    for (NSNumber *current in array) {
        if (current.integerValue >= num.integerValue) {
            return current;
        }
    }
    
    return nil;
}

- (void)setupTestStoreWithMaxFetchNum:(NSInteger)maxFetchNum
{
    self.testStore = [[TestCWIMAPStore alloc] init];
    self.testStore.maxFetchCount = maxFetchNum;
}

- (void)setupTestFolderWithTestStore:(TestCWIMAPStore *)testStore
                 numMessagesOnServer:(NSInteger)exists
                 firstFetchedRageUid:(NSInteger)firstFetchedRangeUid
                  lastFetchedRageUid:(NSInteger)lastFetchedRangeUid
{
    self.testFolder = [[FechTestCWIMAPFolder alloc] initWithName:@"TestFolder"];
    self.testFolder.store = testStore;
    self.testFolder.existsCount = exists;
    self.testFolder.testFirstUID = firstFetchedRangeUid;
    self.testFolder.testLastUID = lastFetchedRangeUid;
}

- (void)setupFolderFetchTestClassesWithMaxFetchNum:(NSInteger)maxFetchNum
                               numMessagesOnServer:(NSInteger)exists
                               firstFetchedRageUid:(NSInteger)firstFetchedRangeUid
                                lastFetchedRageUid:(NSInteger)lastFetchedRangeUid
{
    [self setupTestStoreWithMaxFetchNum:maxFetchNum];
    [self setupTestFolderWithTestStore:self.testStore numMessagesOnServer:exists
                   firstFetchedRageUid:firstFetchedRangeUid
                    lastFetchedRageUid:lastFetchedRangeUid];
}

- (void)setupFolderFetchTestWithMaxFetchNum:(NSInteger)maxFetchNum
                        numMessagesOnServer:(NSInteger)exists
                    msnOfOldestLocalMessage:(NSNumber *)msnOfOldestLocalMessage
                        firstFetchedRageUid:(NSInteger)firstFetchedRangeUid
                         lastFetchedRageUid:(NSInteger)lastFetchedRangeUid
                 expectedSendCommandFromUid:(NSInteger)expSentFromUid
                   expectedSendCommandToUid:(NSInteger)expSentToUid
           shouldSignalFolderFetchCompleted:(BOOL)shouldSignal
                                    success:(BOOL*)success;
{
    [self setupTestStoreWithMaxFetchNum:maxFetchNum];
    [self setupTestFolderWithTestStore:self.testStore numMessagesOnServer:exists
                   firstFetchedRageUid:firstFetchedRangeUid
                    lastFetchedRageUid:lastFetchedRangeUid];
    self.testFolder.msnOfOldestLocalMessage = msnOfOldestLocalMessage.integerValue;
    __block BOOL* blockSuccess = success;
    __weak typeof(self) weakSelf = self;
    if (shouldSignal) {
        self.testStore.assertionBlockForSendCommandInfoArguments = ^(IMAPCommand command,
                                                                     NSDictionary *info,
                                                                     NSString *arguments) {
            XCTFail(@"Should not be called.");
        };
        self.testStore.assertionBlockForSignalFolderFetchNothingToFetch = ^() {
            *blockSuccess = YES;
        };
    } else {
        self.testStore.assertionBlockForSendCommandInfoArguments = ^(IMAPCommand command,
                                                                     NSDictionary *info,
                                                                     NSString *arguments) {
            typeof(self) self = weakSelf;
            *blockSuccess = YES;
            if (expSentToUid != IGNORE && expSentFromUid != IGNORE) {
                // Assert UIDs sent to server
                [self assertArguments:arguments wouldFetchUidsFrom:expSentFromUid to:expSentToUid];
            }
        };
        self.testStore.assertionBlockForSignalFolderFetchNothingToFetch = ^() {
            XCTFail(@"Should not be called");
        };
    }
}

- (void)setupFolderFetchTestWithMaxFetchNum:(NSInteger)maxFetchNum
                        numMessagesOnServer:(NSInteger)exists
                    msnOfOldestLocalMessage:(NSNumber *)msnOfOldestLocalMessage
                        firstFetchedRageUid:(NSInteger)firstFetchedRangeUid
                         lastFetchedRageUid:(NSInteger)lastFetchedRangeUid
                 expectedSendCommandFromMsn:(NSInteger)expSentFromMsn
                   expectedSendCommandToMsn:(NSInteger)expSentToMsn
           shouldSignalFolderFetchCompleted:(BOOL)shouldSignal
                                    success:(BOOL*)success;
{
    [self setupTestStoreWithMaxFetchNum:maxFetchNum];
    [self setupTestFolderWithTestStore:self.testStore numMessagesOnServer:exists
                   firstFetchedRageUid:firstFetchedRangeUid
                    lastFetchedRageUid:lastFetchedRangeUid];
    self.testFolder.msnOfOldestLocalMessage = msnOfOldestLocalMessage.integerValue;
    __block BOOL* blockSuccess = success;
    __weak typeof(self) weakSelf = self;
    if (shouldSignal) {
        self.testStore.assertionBlockForSendCommandInfoArguments = ^(IMAPCommand command,
                                                                     NSDictionary *info,
                                                                     NSString *arguments) {
            XCTFail(@"Should not be called.");
        };
        self.testStore.assertionBlockForSignalFolderFetchNothingToFetch = ^() {
            *blockSuccess = YES;
        };
    } else {
        self.testStore.assertionBlockForSendCommandInfoArguments = ^(IMAPCommand command,
                                                                     NSDictionary *info,
                                                                     NSString *arguments) {
            typeof(self) self = weakSelf;
            *blockSuccess = YES;
            if (expSentToMsn != IGNORE && expSentFromMsn != IGNORE) {
                // Assert UIDs sent to server
                [self assertArguments:arguments wouldFetchMSNsFrom:expSentFromMsn to:expSentToMsn];
            }
        };
        self.testStore.assertionBlockForSignalFolderFetchNothingToFetch = ^() {
            XCTFail(@"Should not be called");
        };
    }
}

- (void)compareStringList:(NSArray<NSString *> *)extracts
              withString1:(NSString *)s1 string2:(NSString *)s2
{
    XCTAssertEqual(extracts.count, 2);
    if (extracts.count == 2) {
        NSString *e1 = extracts[0];
        NSString *e2 = extracts[1];
        XCTAssertEqualObjects(e1, s1);
        XCTAssertEqualObjects(e2, s2);
    }
}

/**
 Used to assure f and t in "FETCH f:t" fit the given uids.
 
 @param arguments IMAP fetch command string
 @param fromUid uid to match f with
 @param toUid uid to match t with
 @return YES if the uids fit f and t, NO otherwize
 */
- (void)assertArguments:(NSString *)arguments
     wouldFetchUidsFrom:(NSUInteger)fromUid
                     to:(NSUInteger)toUid
{
    NSArray<NSString *> *extracts = [TestUtil
                                     extractIntsFromString:arguments
                                     pattern:@"UID FETCH (\\d+):(\\d+) \\([^)]+"];
    
    NSString *fromUidStr = [NSString stringWithFormat:@"%lu", (unsigned long)fromUid];
    NSString *toUidStr = [NSString stringWithFormat:@"%lu", (unsigned long)toUid];
    
    [self compareStringList:extracts withString1:fromUidStr string2:toUidStr];
}

- (void)assertArguments:(NSString *)arguments
     wouldFetchMSNsFrom:(NSUInteger)fromMSN
                     to:(NSUInteger)toMSN
{
    NSArray<NSString *> *extracts = [TestUtil
                                     extractIntsFromString:arguments
                                     pattern:@"FETCH (\\d+):(\\d+) \\([^)]+"];
    
    NSString *fromMSNStr = [NSString stringWithFormat:@"%lu", (unsigned long) fromMSN];
    NSString *toMSNStr = [NSString stringWithFormat:@"%lu", (unsigned long) toMSN];
    
    [self compareStringList:extracts withString1:fromMSNStr string2:toMSNStr];
}

@end
