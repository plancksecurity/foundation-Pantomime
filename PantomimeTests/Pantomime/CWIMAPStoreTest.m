//
//  CWIMAPStoreTest.m
//  Pantomime
//
//  Created by buff on 31.07.17.
//  Copyright © 2017 pEp Security S.A. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "CWIMAPStore.h"

#pragma mark - HELPER
/**
 Make methods accessable
 */
@interface CWIMAPStore (Testing)
- (PantomimeSpecialUseMailboxType)_specialUseTypeFor:(NSString *)listResponse;
- (PantomimeFolderType)_folderTypeFor:(NSString *)listResponse;
@end

#pragma mark - CWIMAPStoreTest

@interface CWIMAPStoreTest : XCTestCase
@end

@implementation CWIMAPStoreTest

#pragma mark - testSpecialUseTypeFor

- (void)testSpecialUseTypeFor_All {
    CWIMAPStore *store = [CWIMAPStore new];
    NSString *serverResponse = @"* LIST (\\All \\HasNoChildren) \"/\" \"Bulk Mail\"";
    PantomimeSpecialUseMailboxType testee = [store _specialUseTypeFor:serverResponse];

    XCTAssertEqual(PantomimeSpecialUseMailboxAll, testee);
}

- (void)testSpecialUseTypeFor_Archive {
    CWIMAPStore *store = [CWIMAPStore new];
    NSString *serverResponse = @"* LIST (\\Archive \\HasNoChildren) \"/\" \"Bulk Mail\"";
    PantomimeSpecialUseMailboxType testee = [store _specialUseTypeFor:serverResponse];

    XCTAssertEqual(PantomimeSpecialUseMailboxArchive, testee);
}

- (void)testSpecialUseTypeFor_Drafts {
    CWIMAPStore *store = [CWIMAPStore new];
    NSString *serverResponse = @"* LIST (\\Drafts \\HasNoChildren) \"/\" \"Bulk Mail\"";
    PantomimeSpecialUseMailboxType testee = [store _specialUseTypeFor:serverResponse];

    XCTAssertEqual(PantomimeSpecialUseMailboxDrafts, testee);
}

- (void)testSpecialUseTypeFor_Junk {
    CWIMAPStore *store = [CWIMAPStore new];
    NSString *serverResponse = @"* LIST (\\Junk \\HasNoChildren) \"/\" \"Bulk Mail\"";
    PantomimeSpecialUseMailboxType testee = [store _specialUseTypeFor:serverResponse];

    XCTAssertEqual(PantomimeSpecialUseMailboxJunk, testee);
}

- (void)testSpecialUseTypeFor_Sent {
    CWIMAPStore *store = [CWIMAPStore new];
    NSString *serverResponse = @"* LIST (\\Sent \\HasNoChildren) \"/\" \"Bulk Mail\"";
    PantomimeSpecialUseMailboxType testee = [store _specialUseTypeFor:serverResponse];

    XCTAssertEqual(PantomimeSpecialUseMailboxSent, testee);
}

- (void)testSpecialUseTypeFor_Trash {
    CWIMAPStore *store = [CWIMAPStore new];
    NSString *serverResponse = @"* LIST (\\Trash \\HasNoChildren) \"/\" \"Bulk Mail\"";
    PantomimeSpecialUseMailboxType testee = [store _specialUseTypeFor:serverResponse];

    XCTAssertEqual(PantomimeSpecialUseMailboxTrash, testee);
}

#pragma mark - testSpecialUseTypeFor

- (void)testFolderTypeFor_HasChildren {
    CWIMAPStore *store = [CWIMAPStore new];
    NSString *serverResponse = @"* LIST (\\All \\HasChildren) \"/\" \"Bulk Mail\"";
    PantomimeFolderType testee = [store _folderTypeFor:serverResponse];
    PantomimeFolderType expected = PantomimeHoldsMessages | PantomimeHoldsFolders;

    XCTAssertEqual(expected, testee);
}

- (void)testFolderTypeFor_HoldsMessages {
    CWIMAPStore *store = [CWIMAPStore new];
    NSString *serverResponse = @"* LIST (\\All) \"/\" \"Bulk Mail\"";
    PantomimeFolderType testee = [store _folderTypeFor:serverResponse];
    PantomimeFolderType expected = PantomimeHoldsMessages;

    XCTAssertEqual(expected, testee);
}

- (void)testFolderTypeFor_NoInferiors {
    CWIMAPStore *store = [CWIMAPStore new];
    NSString *serverResponse = @"* LIST (\\All \\NoInferiors) \"/\" \"Bulk Mail\"";
    PantomimeFolderType testee = [store _folderTypeFor:serverResponse];
    PantomimeFolderType expected = PantomimeHoldsMessages | PantomimeNoInferiors;

    XCTAssertEqual(expected, testee);
}

// The current implementation supposes that all folder potentially hold messages
- (void)testFolderTypeFor_NoSelect {
    CWIMAPStore *store = [CWIMAPStore new];
    NSString *serverResponse = @"* LIST (\\All \\NoSelect) \"/\" \"Bulk Mail\"";
    PantomimeFolderType testee = [store _folderTypeFor:serverResponse];
    PantomimeFolderType expected = PantomimeHoldsMessages | PantomimeNoSelect;

    XCTAssertEqual(expected, testee);
}

- (void)testFolderTypeFor_Marked {
    CWIMAPStore *store = [CWIMAPStore new];
    NSString *serverResponse = @"* LIST (\\All \\Marked) \"/\" \"Bulk Mail\"";
    PantomimeFolderType testee = [store _folderTypeFor:serverResponse];
    PantomimeFolderType expected = PantomimeHoldsMessages | PantomimeMarked;

    XCTAssertEqual(expected, testee);
}

- (void)testFolderTypeFor_Unmarked {
    CWIMAPStore *store = [CWIMAPStore new];
    NSString *serverResponse = @"* LIST (\\All \\Unmarked) \"/\" \"Bulk Mail\"";
    PantomimeFolderType testee = [store _folderTypeFor:serverResponse];
    PantomimeFolderType expected = PantomimeHoldsMessages | PantomimeUnmarked;

    XCTAssertEqual(expected, testee);
}

@end
