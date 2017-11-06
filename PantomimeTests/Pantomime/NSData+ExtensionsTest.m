//
//  NSData+ExtensionsTest.m
//  PantomimeTests
//
//  Created by Andreas Buff on 06.11.17.
//  Copyright © 2017 pEp Security S.A. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "NSData+Extensions.h"

@interface NSData_ExtensionsTest : XCTestCase
@end

@implementation NSData_ExtensionsTest

#pragma mark - unwrap

- (void)testUnwrap_wrapped
{
    NSString *testStr = @"<35BE75EB.74E6.4CB7.9C5D.432B241FDF90@pretty.Easy.privacy>";
    NSString *expected = @"35BE75EB.74E6.4CB7.9C5D.432B241FDF90@pretty.Easy.privacy";
    NSData *testData = [testStr dataUsingEncoding:NSUTF8StringEncoding];
    NSData *testeeData = [testData unwrap];
    NSString* testee = [[NSString alloc] initWithData:testeeData encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(testee, expected);
}

- (void)testUnwrap_unwrapped
{
    NSString *testStr = @"35BE75EB.74E6.4CB7.9C5D.432B241FDF90@pretty.Easy.privacy";
    NSString *expected = @"35BE75EB.74E6.4CB7.9C5D.432B241FDF90@pretty.Easy.privacy";
    NSData *testData = [testStr dataUsingEncoding:NSUTF8StringEncoding];
    NSData *testeeData = [testData unwrap];
    NSString* testee = [[NSString alloc] initWithData:testeeData encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(testee, expected);
}

@end
