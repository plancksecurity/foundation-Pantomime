//
//  CWIMAPStoreTest.m
//  Pantomime
//
//  Created by buff on 31.07.17.
//  Copyright © 2017 pEp Security S.A. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "CWIMAPStore.h"
#import "CWIMAPStore+TestVisibility.h"

#pragma mark - HELPER

#pragma mark CRLF

static NSString *CRLF = @"\r\n";

@interface NSString(SWIMAPStoreTest)
@end
@implementation NSString(SWIMAPStoreTest)
- (NSString *)crLfTerminated
{
    return [NSString stringWithFormat:@"%@%@", self, CRLF];
}
@end

#pragma mark Publish Methos

@interface CWIMAPStore (Testing)
- (PantomimeSpecialUseMailboxType)_specialUseTypeForServerResponse:(NSString *)listResponse;
- (PantomimeFolderAttribute)_folderAttributesForServerResponse:(NSString *)listResponse;
@end

#pragma mark Test Store

#import "CWIMAPStore+Protected.h"
#import "CWThreadSafeData.h"
@class TestableImapStore;

@protocol TestableImapStoreDelegate
- (void)testableImapStoreDidCallParseBad:(TestableImapStore *)store;
@end

@interface TestableImapStore:CWIMAPStore
@property (weak, nonatomic) id<TestableImapStoreDelegate> testDelegate;
@property (weak, nonatomic) CWIMAPQueueObject *currentQueueObject;
- (void)setReadBufferData:(NSData *)data;
@end
@implementation TestableImapStore
@dynamic currentQueueObject;
- (void)setReadBufferData:(NSData *)data
{
    _rbuf = [[CWThreadSafeData alloc] initWithData:data];
}
- (void) _parseBAD
{
    [self.testDelegate testableImapStoreDidCallParseBad:self];
}
@end

@interface StoreTestDelegate:NSObject<TestableImapStoreDelegate>
@property (nonatomic, strong) XCTestExpectation *badCalledExp;
@end
@implementation StoreTestDelegate
- (instancetype)initWithBadCalledExpectation:(XCTestExpectation *)badCalledExp
{
    self = [super init];
    if (self) {
        self.badCalledExp = badCalledExp;
    }
    return self;
}

- (void)testableImapStoreDidCallParseBad:(TestableImapStore *)store
{
    [self.badCalledExp fulfill];
}
@end

#pragma mark - CWIMAPStoreTest

@interface CWIMAPStoreTest : XCTestCase
@end

@implementation CWIMAPStoreTest

#pragma mark - testSpecialUseTypeFor

- (void)testSpecialUseTypeFor_All {
    CWIMAPStore *store = [CWIMAPStore new];
    NSString *serverResponse = @"* LIST (\\All \\HasNoChildren) \"/\" \"Bulk Mail\"";
    PantomimeSpecialUseMailboxType testee = [store _specialUseTypeForServerResponse:serverResponse];

    XCTAssertEqual(PantomimeSpecialUseMailboxAll, testee);
}

- (void)testSpecialUseTypeFor_Archive {
    CWIMAPStore *store = [CWIMAPStore new];
    NSString *serverResponse = @"* LIST (\\Archive \\HasNoChildren) \"/\" \"Bulk Mail\"";
    PantomimeSpecialUseMailboxType testee = [store _specialUseTypeForServerResponse:serverResponse];

    XCTAssertEqual(PantomimeSpecialUseMailboxArchive, testee);
}

- (void)testSpecialUseTypeFor_Drafts {
    CWIMAPStore *store = [CWIMAPStore new];
    NSString *serverResponse = @"* LIST (\\Drafts \\HasNoChildren) \"/\" \"Bulk Mail\"";
    PantomimeSpecialUseMailboxType testee = [store _specialUseTypeForServerResponse:serverResponse];

    XCTAssertEqual(PantomimeSpecialUseMailboxDrafts, testee);
}

- (void)testSpecialUseTypeFor_Junk {
    CWIMAPStore *store = [CWIMAPStore new];
    NSString *serverResponse = @"* LIST (\\Junk \\HasNoChildren) \"/\" \"Bulk Mail\"";
    PantomimeSpecialUseMailboxType testee = [store _specialUseTypeForServerResponse:serverResponse];

    XCTAssertEqual(PantomimeSpecialUseMailboxJunk, testee);
}

- (void)testSpecialUseTypeFor_Sent {
    CWIMAPStore *store = [CWIMAPStore new];
    NSString *serverResponse = @"* LIST (\\Sent \\HasNoChildren) \"/\" \"Bulk Mail\"";
    PantomimeSpecialUseMailboxType testee = [store _specialUseTypeForServerResponse:serverResponse];

    XCTAssertEqual(PantomimeSpecialUseMailboxSent, testee);
}

- (void)testSpecialUseTypeFor_Trash {
    CWIMAPStore *store = [CWIMAPStore new];
    NSString *serverResponse = @"* LIST (\\Trash \\HasNoChildren) \"/\" \"Bulk Mail\"";
    PantomimeSpecialUseMailboxType testee = [store _specialUseTypeForServerResponse:serverResponse];

    XCTAssertEqual(PantomimeSpecialUseMailboxTrash, testee);
}

#pragma mark - testSpecialUseTypeFor

- (void)testFolderTypeFor_HasChildren {
    CWIMAPStore *store = [CWIMAPStore new];
    NSString *serverResponse = @"* LIST (\\All \\HasChildren) \"/\" \"Bulk Mail\"";
    PantomimeFolderAttribute testee = [store _folderAttributesForServerResponse:serverResponse];
    PantomimeFolderAttribute expected = PantomimeHoldsMessages | PantomimeHoldsFolders;

    XCTAssertEqual(expected, testee);
}

- (void)testFolderTypeFor_HoldsMessages {
    CWIMAPStore *store = [CWIMAPStore new];
    NSString *serverResponse = @"* LIST (\\All) \"/\" \"Bulk Mail\"";
    PantomimeFolderAttribute testee = [store _folderAttributesForServerResponse:serverResponse];
    PantomimeFolderAttribute expected = PantomimeHoldsMessages;

    XCTAssertEqual(expected, testee);
}

- (void)testFolderTypeFor_NoInferiors {
    CWIMAPStore *store = [CWIMAPStore new];
    NSString *serverResponse = @"* LIST (\\All \\NoInferiors) \"/\" \"Bulk Mail\"";
    PantomimeFolderAttribute testee = [store _folderAttributesForServerResponse:serverResponse];
    PantomimeFolderAttribute expected = PantomimeHoldsMessages | PantomimeNoInferiors;

    XCTAssertEqual(expected, testee);
}

// The current implementation supposes that all folder potentially hold messages
- (void)testFolderTypeFor_NoSelect {
    CWIMAPStore *store = [CWIMAPStore new];
    NSString *serverResponse = @"* LIST (\\All \\NoSelect) \"/\" \"Bulk Mail\"";
    PantomimeFolderAttribute testee = [store _folderAttributesForServerResponse:serverResponse];
    PantomimeFolderAttribute expected = PantomimeHoldsMessages | PantomimeNoSelect;

    XCTAssertEqual(expected, testee);
}

- (void)testFolderTypeFor_Marked {
    CWIMAPStore *store = [CWIMAPStore new];
    NSString *serverResponse = @"* LIST (\\All \\Marked) \"/\" \"Bulk Mail\"";
    PantomimeFolderAttribute testee = [store _folderAttributesForServerResponse:serverResponse];
    PantomimeFolderAttribute expected = PantomimeHoldsMessages | PantomimeMarked;

    XCTAssertEqual(expected, testee);
}

- (void)testFolderTypeFor_Unmarked {
    CWIMAPStore *store = [CWIMAPStore new];
    NSString *serverResponse = @"* LIST (\\All \\Unmarked) \"/\" \"Bulk Mail\"";
    PantomimeFolderAttribute testee = [store _folderAttributesForServerResponse:serverResponse];
    PantomimeFolderAttribute expected = PantomimeHoldsMessages | PantomimeUnmarked;

    XCTAssertEqual(expected, testee);
}

#pragma mark - updateRead

//IOS-292: server responce without sequence number ignored
- (void)testUpdateRead_BadWithoutSequenceNumber {
    NSString *serverResponseString = [@"* BAD internal server error" crLfTerminated];
    XCTestExpectation *expBadCalled = [self expectationWithDescription:@"expBadCalled"];
    StoreTestDelegate *delegate = [[StoreTestDelegate alloc]
                                   initWithBadCalledExpectation:expBadCalled];
    TestableImapStore *store = [TestableImapStore new];
    store.testDelegate = delegate;
    NSData *serverResponseData = [serverResponseString dataUsingEncoding:NSUTF8StringEncoding];
    [store setReadBufferData:serverResponseData];
    [store updateRead];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testUpdateRead_BadWithSequenceNumber {
    NSString *serverResponseString =
    [@"A00000009 BAD Error in IMAP command FETCH: Invalid messageset (0.000 + 0.040 + 0.039 secs)" crLfTerminated];
    XCTestExpectation *expBadCalled = [self expectationWithDescription:@"expBadCalled"];
    StoreTestDelegate *delegate = [[StoreTestDelegate alloc]
                                   initWithBadCalledExpectation:expBadCalled];
    TestableImapStore *store = [TestableImapStore new];
    store.testDelegate = delegate;
    NSData *serverResponseData = [serverResponseString dataUsingEncoding:NSUTF8StringEncoding];
    [store setReadBufferData:serverResponseData];
    [store updateRead];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

#pragma mark - UID PARSING

#pragma mark _uniqueIdentifiersFromSearchResponseData

- (void)test_uniqueIdentifiersFromSearchResponseData
{
    NSDictionary *testInputs = @{@"* SEARCH 1 4 59 81": @[@1, @4, @59, @81],
                                 @"* SEARCH": @[],
                                 @"* SEARCH 11": @[@11],
                                 @"": @[]};
    CWIMAPStore *store = [CWIMAPStore new];
    for (int i = 0; i < testInputs.count; ++i) {
        NSString *testee = testInputs.allKeys[i];
        NSData *testeeData = [testee dataUsingEncoding:NSISOLatin1StringEncoding];

        NSArray *results = [store _uniqueIdentifiersFromSearchResponseData:testeeData];

        if (testInputs.allValues.count == 0) {
            XCTAssertEqual(results.count, 0);
        } else {
            for (NSNumber *expected in testInputs.allValues[i]) {
                XCTAssertTrue([results containsObject:expected]);
            }
        }
    }
}

#pragma mark _uniqueIdentifiersFromFetchUidsResponseData

- (void)test_uniqueIdentifiersFromFetchUidsResponseData
{
    NSDictionary *testInputs = @{@"* 1 FETCH (UID 1)": @[@(1)],
                                 @"* 1 FETCH (UID 12)": @[@(12)],
                                 @"* 1 FETCH (UID 123)": @[@(123)],
                                 @"* 1 FETCH (UID 1234)": @[@(1234)],
                                 @"* 1 FETCH (UID 12345)": @[@(12345)],
                                 @"* 12 FETCH (UID 1)": @[@(1)],
                                 @"* 12 FETCH (UID 12)": @[@(12)],
                                 @"* 12 FETCH (UID 123)": @[@(123)],
                                 @"* 12 FETCH (UID 1234)": @[@(1234)],
                                 @"* 12 FETCH (UID 12345)": @[@(12345)],
                                 @"* 123 FETCH (UID 1)": @[@(1)],
                                 @"* 123 FETCH (UID 12)": @[@(12)],
                                 @"* 123 FETCH (UID 123)": @[@(123)],
                                 @"* 123 FETCH (UID 1234)": @[@(1234)],
                                 @"* 123 FETCH (UID 12345)": @[@(12345)],
                                 @"* 1235 FETCH (UID 1)": @[@(1)],
                                 @"* 1235 FETCH (UID 12)": @[@(12)],
                                 @"* 1235 FETCH (UID 123)": @[@(123)],
                                 @"* 1235 FETCH (UID 1234)": @[@(1234)],
                                 @"* 1235 FETCH (UID 12345)": @[@(12345)]
    };
    CWIMAPStore *store = [CWIMAPStore new];
    for (int i = 0; i < testInputs.count; ++i) {
        NSString *testee = testInputs.allKeys[i];
        NSData *testeeData = [testee dataUsingEncoding:NSISOLatin1StringEncoding];

        NSArray *results = [store _uniqueIdentifiersFromFetchUidsResponseData:testeeData];

        if (testInputs.allValues.count == 0) {
            XCTAssertEqual(results.count, 0);
        } else {
            for (NSNumber *expected in testInputs.allValues[i]) {
                XCTAssertTrue([results containsObject:expected]);
            }
        }
    }
}

@end
