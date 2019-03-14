//
//  CWMessageTest.m
//  PantomimeTests
//
//  Created by Andreas Buff on 31.01.18.
//  Copyright © 2018 pEp Security S.A. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <PantomimeFramework/CWMessage.h>
#import "TestUtil.h"

@interface CWMessageTest : XCTestCase
@end

@implementation CWMessageTest

#pragma mark - setHeadersFromData:

// This test always succeeds.
// It is handy to quickly debug parsing issues. To do so:
// - set a breakpoint and log your problem message data
// - use the logged data (somthing like <44656c69 ... 76657265>) as msg in the test below.
- (void)testSetHeadersFromData {
    NSString *msg = @"TEST MSG DATA IN HEX STRING REPRESENTATION GOES HERE <44656c69 76657265>";
    NSData *msgData = [msg dataFromHexString];
    CWMessage *testee = [CWMessage new];
    [testee setHeadersFromData:msgData];
}

@end
