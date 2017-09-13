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

#pragma mark - Helper Classes

@interface TestCWIMAPStore : CWIMAPStore

@property (nonatomic, copy, nonnull)
void (^assertionBlockForSendCommandInfoArguments)(IMAPCommand, NSDictionary *, NSString *);

@property (nonatomic, copy, nonnull)
void (^assertionBlockForSignalFolderFetchNothingToFetch)();

@end

@implementation TestCWIMAPStore

/// overrride methods to get test feedback
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

@end

@implementation FechTestCWIMAPFolder

- (NSUInteger) firstUID { return self.testFirstUID; }
- (NSUInteger)lastUID { return self.testLastUID; }

@end


#pragma mark - Test

@interface FolderTests : XCTestCase
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

    TestCWIMAPStore *testStore = [[TestCWIMAPStore alloc] init];
    FechTestCWIMAPFolder *testFolder = [[FechTestCWIMAPFolder alloc] initWithName:@"TestFolder"];
    testFolder.store = testStore;
    testFolder.existsCount = numMessagesOnServer;
    testFolder.testFirstUID = fetchedRangeFirstUid;
    testFolder.testLastUID = fetchedRangeLastUid;

    testStore.assertionBlockForSendCommandInfoArguments = ^(IMAPCommand command,
                                                             NSDictionary *info,
                                                             NSString *arguments) {
        XCTFail(@"Should not be called.");
    };
    __block BOOL blockCalled = NO;
    testStore.assertionBlockForSignalFolderFetchNothingToFetch = ^() {
        blockCalled = YES;
    };

    [testFolder fetchFrom:from to:to];

    XCTAssertTrue(blockCalled);
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

    TestCWIMAPStore *testStore = [[TestCWIMAPStore alloc] init];
    FechTestCWIMAPFolder *testFolder = [[FechTestCWIMAPFolder alloc] initWithName:@"TestFolder"];
    testFolder.store = testStore;
    testFolder.existsCount = numMessagesOnServer;
    testFolder.testFirstUID = fetchedRangeFirstUid;
    testFolder.testLastUID = fetchedRangeLastUid;

    __block BOOL blockCalled = NO;
    testStore.assertionBlockForSendCommandInfoArguments = ^(IMAPCommand command,
                                                             NSDictionary *info,
                                                             NSString *arguments) {
        blockCalled = YES;
        [self assertArguments:arguments wouldFetchUidsFrom:expectedFrom to:expectedTo];
    };
    testStore.assertionBlockForSignalFolderFetchNothingToFetch = ^() {
        XCTFail(@"Should not be called");
    };

    [testFolder fetchFrom:from to:to];

    XCTAssertTrue(blockCalled);
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

    TestCWIMAPStore *testStore = [[TestCWIMAPStore alloc] init];
    FechTestCWIMAPFolder *testFolder = [[FechTestCWIMAPFolder alloc] initWithName:@"TestFolder"];
    testFolder.store = testStore;
    testFolder.existsCount = numMessagesOnServer;
    testFolder.testFirstUID = fetchedRangeFirstUid;
    testFolder.testLastUID = fetchedRangeLastUid;

    __block BOOL blockCalled = NO;
    testStore.assertionBlockForSendCommandInfoArguments = ^(IMAPCommand command,
                                                             NSDictionary *info,
                                                             NSString *arguments) {
        blockCalled = YES;
        [self assertArguments:arguments wouldFetchUidsFrom:expectedFrom to:expectedTo];
    };
    testStore.assertionBlockForSignalFolderFetchNothingToFetch = ^() {
        XCTFail(@"Should not be called");
    };

    [testFolder fetchFrom:from to:to];

    XCTAssertTrue(blockCalled);
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

    TestCWIMAPStore *testStore = [[TestCWIMAPStore alloc] init];
    FechTestCWIMAPFolder *testFolder = [[FechTestCWIMAPFolder alloc] initWithName:@"TestFolder"];
    testFolder.store = testStore;
    testFolder.existsCount = numMessagesOnServer;
    testFolder.testFirstUID = fetchedRangeFirstUid;
    testFolder.testLastUID = fetchedRangeLastUid;

    __block BOOL blockCalled = NO;
    testStore.assertionBlockForSendCommandInfoArguments = ^(IMAPCommand command,
                                                             NSDictionary *info,
                                                             NSString *arguments) {
        blockCalled = YES;
        [self assertArguments:arguments wouldFetchUidsFrom:expectedFrom to:expectedTo];
    };
    testStore.assertionBlockForSignalFolderFetchNothingToFetch = ^() {
        XCTFail(@"Should not be called");
    };

    [testFolder fetchFrom:from to:to];

    XCTAssertTrue(blockCalled);
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

    TestCWIMAPStore *testStore = [[TestCWIMAPStore alloc] init];
    FechTestCWIMAPFolder *testFolder = [[FechTestCWIMAPFolder alloc] initWithName:@"TestFolder"];
    testFolder.store = testStore;
    testFolder.existsCount = numMessagesOnServer;
    testFolder.testFirstUID = fetchedRangeFirstUid;
    testFolder.testLastUID = fetchedRangeLastUid;

    __block BOOL blockCalled = NO;
    testStore.assertionBlockForSendCommandInfoArguments = ^(IMAPCommand command,
                                                             NSDictionary *info,
                                                             NSString *arguments) {
        blockCalled = YES;
        [self assertArguments:arguments wouldFetchUidsFrom:expectedFrom to:expectedTo];
    };
    testStore.assertionBlockForSignalFolderFetchNothingToFetch = ^() {
        XCTFail(@"Should not be called");
    };

    [testFolder fetchFrom:from to:to];

    XCTAssertTrue(blockCalled);
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

    TestCWIMAPStore *testStore = [[TestCWIMAPStore alloc] init];
    FechTestCWIMAPFolder *testFolder = [[FechTestCWIMAPFolder alloc] initWithName:@"TestFolder"];
    testFolder.store = testStore;
    testFolder.existsCount = numMessagesOnServer;
    testFolder.testFirstUID = fetchedRangeFirstUid;
    testFolder.testLastUID = fetchedRangeLastUid;

    __block BOOL blockCalled = NO;
    testStore.assertionBlockForSendCommandInfoArguments = ^(IMAPCommand command,
                                                             NSDictionary *info,
                                                             NSString *arguments) {
        blockCalled = YES;
        [self assertArguments:arguments wouldFetchUidsFrom:expectedFrom to:expectedTo];
    };
    testStore.assertionBlockForSignalFolderFetchNothingToFetch = ^() {
        XCTFail(@"Should not be called");
    };

    [testFolder fetchFrom:from to:to];

    XCTAssertTrue(blockCalled);
}

- (void)testFetchFromTo_noMailsOnServer
{
    NSInteger numMessagesOnServer = 0;
    NSInteger fetchedRangeFirstUid = 10;
    NSInteger fetchedRangeLastUid = 14;
    NSInteger from = 11;
    NSInteger to = 14;

    TestCWIMAPStore *testStore = [[TestCWIMAPStore alloc] init];
    FechTestCWIMAPFolder *testFolder = [[FechTestCWIMAPFolder alloc] initWithName:@"TestFolder"];
    testFolder.store = testStore;
    testFolder.existsCount = numMessagesOnServer;
    testFolder.testFirstUID = fetchedRangeFirstUid;
    testFolder.testLastUID = fetchedRangeLastUid;

    testStore.assertionBlockForSendCommandInfoArguments = ^(IMAPCommand command,
                                                             NSDictionary *info,
                                                             NSString *arguments) {
        XCTFail(@"Should not be called.");
    };
    __block BOOL blockCalled = NO;
    testStore.assertionBlockForSignalFolderFetchNothingToFetch = ^() {
        blockCalled = YES;
    };

    [testFolder fetchFrom:from to:to];

    XCTAssertTrue(blockCalled);
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

    TestCWIMAPStore *testStore = [[TestCWIMAPStore alloc] init];
    FechTestCWIMAPFolder *testFolder = [[FechTestCWIMAPFolder alloc] initWithName:@"TestFolder"];
    testFolder.store = testStore;
    testFolder.existsCount = numMessagesOnServer;
    testFolder.testFirstUID = fetchedRangeFirstUid;
    testFolder.testLastUID = fetchedRangeLastUid;

    testStore.assertionBlockForSendCommandInfoArguments = ^(IMAPCommand command,
                                                             NSDictionary *info,
                                                             NSString *arguments) {
        XCTFail(@"Should not be called.");
    };
    __block BOOL blockCalled = NO;
    testStore.assertionBlockForSignalFolderFetchNothingToFetch = ^() {
        blockCalled = YES;
    };

    [testFolder fetchFrom:from to:to];

    XCTAssertTrue(blockCalled);
}

#pragma mark - fetchOlder

// | 1  | 2  | 3  | 4  | 5  | 6  | 7  | 8  | 9  | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 |
//                                              |<-- allready fetched -->|
//                                              |<---- fetchedRange ---->|
//                                                 ^                   ^
//                                                 |                   |
//                                              firstUid            lastUid
//------------------------------------------------------------------------------------------------------
- (void)testFetchOlder
{
    NSInteger maxFetchNum = 2;
    NSInteger numMessagesOnServer = 20;
    NSInteger fetchedRangeFirstUid = 10;
    NSInteger fetchedRangeLastUid = 14;
    NSUInteger expectedFrom = 8;
    NSUInteger expectedTo = 9;

    TestCWIMAPStore *testStore = [[TestCWIMAPStore alloc] init];
    testStore.maxPrefetchCount = maxFetchNum;
    FechTestCWIMAPFolder *testFolder = [[FechTestCWIMAPFolder alloc] initWithName:@"TestFolder"];
    testFolder.store = testStore;
    testFolder.existsCount = numMessagesOnServer;
    testFolder.testFirstUID = fetchedRangeFirstUid;
    testFolder.testLastUID = fetchedRangeLastUid;

    __block BOOL blockCalled = NO;
    testStore.assertionBlockForSendCommandInfoArguments = ^(IMAPCommand command, NSDictionary *info,
                                                             NSString *arguments) {
        blockCalled = YES;
        [self assertArguments:arguments wouldFetchUidsFrom:expectedFrom to:expectedTo];
    };
    testStore.assertionBlockForSignalFolderFetchNothingToFetch = ^() {
        XCTFail(@"Should not be called");
    };

    [testFolder fetchOlder];

    XCTAssertTrue(blockCalled);
}

// | 1  | 2  | 3  | 4  | 5  | 6  | 7  | 8  | 9  | 10 |
// |<-- allready fetched -->|
// |<---- fetchedRange ---->|
//    ^                   ^
//    |                   |
//  firstUid            lastUid
//------------------------------------------------------------------------------------------------------
- (void)testFetchOlder_noOlderExist
{
    NSInteger maxFetchNum = 2;
    NSInteger numMessagesOnServer = 10;
    NSInteger fetchedRangeFirstUid = 1;
    NSInteger fetchedRangeLastUid = 5;

    TestCWIMAPStore *testStore = [[TestCWIMAPStore alloc] init];
    testStore.maxPrefetchCount = maxFetchNum;
    FechTestCWIMAPFolder *testFolder = [[FechTestCWIMAPFolder alloc] initWithName:@"TestFolder"];
    testFolder.store = testStore;
    testFolder.existsCount = numMessagesOnServer;
    testFolder.testFirstUID = fetchedRangeFirstUid;
    testFolder.testLastUID = fetchedRangeLastUid;

    __block BOOL blockCalled = NO;
    testStore.assertionBlockForSendCommandInfoArguments = ^(IMAPCommand command,
                                                             NSDictionary *info,
                                                             NSString *arguments) {
        XCTFail(@"Should not be called");
    };
    testStore.assertionBlockForSignalFolderFetchNothingToFetch = ^() {
        blockCalled = YES;
    };

    [testFolder fetchOlder];

    XCTAssertTrue(blockCalled);
}

// | 1  | 2  | 3  | 4  | 5  | 6  | 7  | 8  | 9  | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 |
//                                              |<-- allready fetched -->|
//                                              |<---- fetchedRange ---->|
//                                                 ^                   ^
//                                                 |                   |
//                                              firstUid            lastUid
//------------------------------------------------------------------------------------------------------
- (void)testFetchOlder_maxFetchBiggerExisting
{
    NSInteger maxFetchNum = 100;
    NSInteger numMessagesOnServer = 20;
    NSInteger fetchedRangeFirstUid = 10;
    NSInteger fetchedRangeLastUid = 14;
    NSUInteger expectedFrom = 1;
    NSUInteger expectedTo = 9;

    TestCWIMAPStore *testStore = [[TestCWIMAPStore alloc] init];
    testStore.maxPrefetchCount = maxFetchNum;
    FechTestCWIMAPFolder *testFolder = [[FechTestCWIMAPFolder alloc] initWithName:@"TestFolder"];
    testFolder.store = testStore;
    testFolder.existsCount = numMessagesOnServer;
    testFolder.testFirstUID = fetchedRangeFirstUid;
    testFolder.testLastUID = fetchedRangeLastUid;

    __block BOOL blockCalled = NO;
    testStore.assertionBlockForSendCommandInfoArguments = ^(IMAPCommand command, NSDictionary *info,
                                                             NSString *arguments) {
        blockCalled = YES;
        [self assertArguments:arguments wouldFetchUidsFrom:expectedFrom to:expectedTo];
    };
    testStore.assertionBlockForSignalFolderFetchNothingToFetch = ^() {
        XCTFail(@"Should not be called");
    };

    [testFolder fetchOlder];

    XCTAssertTrue(blockCalled);
}

#pragma mark - prefetch

// | 1  | 2  | 3  | 4  | 5  | 6  | 7  | 8  | 9  | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 |
//                                              |<-- allready fetched -->|
//                                              |<---- fetchedRange ---->|
//                                                 ^                   ^
//                                                 |                   |
//                                              firstUid            lastUid
//------------------------------------------------------------------------------------------------------
- (void)testPrefetch_somePreveouslyFetched
{
    NSInteger maxFetchNum = 2;
    NSInteger numMessagesOnServer = 20;
    NSInteger fetchedRangeFirstUid = 10;
    NSInteger fetchedRangeLastUid = 14;
    NSUInteger expectedFrom = 15;
    NSUInteger expectedTo = 16;

    TestCWIMAPStore *testStore = [[TestCWIMAPStore alloc] init];
    testStore.maxPrefetchCount = maxFetchNum;
    FechTestCWIMAPFolder *testFolder = [[FechTestCWIMAPFolder alloc] initWithName:@"TestFolder"];
    testFolder.store = testStore;
    testFolder.existsCount = numMessagesOnServer;
    testFolder.testFirstUID = fetchedRangeFirstUid;
    testFolder.testLastUID = fetchedRangeLastUid;

    __block BOOL blockCalled = NO;
    testStore.assertionBlockForSendCommandInfoArguments = ^(IMAPCommand command, NSDictionary *info,
                                                             NSString *arguments) {
        blockCalled = YES;
        [self assertArguments:arguments wouldFetchUidsFrom:expectedFrom to:expectedTo];
    };
    testStore.assertionBlockForSignalFolderFetchNothingToFetch = ^() {
        XCTFail(@"Should not be called");
    };

    [testFolder prefetch];

    XCTAssertTrue(blockCalled);
}

// | 1  | 2  | 3  | 4  | 5  | 6  | 7  | 8  | 9  | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 |
//------------------------------------------------------------------------------------------------------
// firstUid == 0
// lastUid == 0
- (void)testPrefetch_nothingPreveouslyFetched
{
    NSInteger maxFetchNum = 2;
    NSInteger numMessagesOnServer = 20;
    NSInteger fetchedRangeFirstUid = 0;
    NSInteger fetchedRangeLastUid = 0;

    TestCWIMAPStore *testStore = [[TestCWIMAPStore alloc] init];
    testStore.maxPrefetchCount = maxFetchNum;
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

    [testFolder prefetch];

    XCTAssertTrue(blockCalled);
}

- (void)testPrefetch_nothingPreveouslyFetched_maxFetchNumGreaterExistsCount
{
    NSInteger maxFetchNum = 100;
    NSInteger numMessagesOnServer = 20;
    NSInteger fetchedRangeFirstUid = 0;
    NSInteger fetchedRangeLastUid = 0;

    TestCWIMAPStore *testStore = [[TestCWIMAPStore alloc] init];
    testStore.maxPrefetchCount = maxFetchNum;
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

    [testFolder prefetch];

    XCTAssertTrue(blockCalled);
}

#pragma mark - Helpers

/**
 Extracts exactly 2 Int-Strings from a given String.
 */
- (NSArray<NSString *> *)extractIntsFromString:(NSString *)string pattern:(NSString *)pattern
{
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression
                                  regularExpressionWithPattern:pattern
                                  options:0 error:&error];
    XCTAssertNil(error);

    NSArray *matches = [regex matchesInString:string options:0
                                        range:NSMakeRange(0, string.length - 1)];
    XCTAssertEqual(matches.count, 1);
    if (matches.count == 1) {
        NSTextCheckingResult *result = [matches firstObject];
        XCTAssertNotNil(result);
        XCTAssertEqual(result.numberOfRanges, 3);
        if (result.numberOfRanges == 3) {
            NSString *s1 = [string substringWithRange:[result rangeAtIndex:1]];
            NSString *s2 = [string substringWithRange:[result rangeAtIndex:2]];
            return @[s1, s2];
        }
    }
    return @[];
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
    NSArray<NSString *> *extracts = [self
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
    NSArray<NSString *> *extracts = [self
                                     extractIntsFromString:arguments
                                     pattern:@"FETCH (\\d+):(\\d+) \\([^)]+"];

    NSString *fromMSNStr = [NSString stringWithFormat:@"%lu", (unsigned long) fromMSN];
    NSString *toMSNStr = [NSString stringWithFormat:@"%lu", (unsigned long) toMSN];

    [self compareStringList:extracts withString1:fromMSNStr string2:toMSNStr];
}

@end
