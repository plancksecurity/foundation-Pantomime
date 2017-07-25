//
//  FolderTests.m
//  Pantomime
//
//  Created by Dirk Zimmermann on 02/12/16.
//  Copyright © 2016 pEp Security S.A. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "Pantomime.h"

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

@end
