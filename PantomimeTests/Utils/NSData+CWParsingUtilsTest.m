//
//  NSData+CWParsingUtilsTest.m
//  PantomimeTests
//
//  Created by Andreas Buff on 07.09.18.
//  Copyright © 2018 pEp Security S.A. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "NSData+CWParsingUtils.h"

@interface NSData_CWParsingUtilsTest : XCTestCase

@end

@implementation NSData_CWParsingUtilsTest

#pragma mark - firstSemicolonOrNewlineInRange

- (void)testFirstSemicolonOrNewlineInRangeOfData_shouldFind
{
    NSString *testee = @"Test string ; goes on";
    NSInteger expectedLocation = 12;
    [self assertFirstSemicolonOrNewlineInRangeWithTestee:testee expectedLocation:expectedLocation];
}

- (void)testFirstSemicolonOrNewlineInRangeOfData_shouldNotFind
{
    NSString *testee = @"Test string  goes on";
    NSInteger expectedLocation = NSNotFound;
    [self assertFirstSemicolonOrNewlineInRangeWithTestee:testee expectedLocation:expectedLocation];
}

- (void)testFirstSemicolonOrNewlineInRangeOfData_inQuotesSemicolon
{
    NSString *testee = @"\"Test string ; goes on\"";
    NSInteger expectedLocation = 13;
    [self assertFirstSemicolonOrNewlineInRangeWithTestee:testee expectedLocation:expectedLocation];
}

- (void)testFirstSemicolonOrNewlineInRangeOfData_inQuotesNewLine
{
    NSString *testee = @"\"Test string \n goes on\"";
    NSInteger expectedLocation = 13;
    [self assertFirstSemicolonOrNewlineInRangeWithTestee:testee expectedLocation:expectedLocation];
}

- (void)testFirstSemicolonOrNewlineInRangeOfData_semicolonFirst
{
    NSString *testee = @"Test string ; goes \n on";
    NSInteger expectedLocation = 12;
    [self assertFirstSemicolonOrNewlineInRangeWithTestee:testee expectedLocation:expectedLocation];
}

- (void)testFirstSemicolonOrNewlineInRangeOfData_newlineFirst
{
    NSString *testee = @"Test string \n goes ; on";
    NSInteger expectedLocation = 12;
    [self assertFirstSemicolonOrNewlineInRangeWithTestee:testee expectedLocation:expectedLocation];
}

- (void)testFirstSemicolonOrNewlineInRangeOfData_doubleNewline
{
    NSString *testee = @"Test string \n goes \n on";
    NSInteger expectedLocation = 12;
    [self assertFirstSemicolonOrNewlineInRangeWithTestee:testee expectedLocation:expectedLocation];
}

- (void)testFirstSemicolonOrNewlineInRangeOfData_doubleSemicolon
{
    NSString *testee = @"Test string ; goes ; on";
    NSInteger expectedLocation = 12;
    [self assertFirstSemicolonOrNewlineInRangeWithTestee:testee expectedLocation:expectedLocation];
}

- (void)testFirstSemicolonOrNewlineInRangeOfData_edgeCaseZero
{
    NSString *testee = @";Test string ; goes ; on";
    NSInteger expectedLocation = 0;
    [self assertFirstSemicolonOrNewlineInRangeWithTestee:testee expectedLocation:expectedLocation];
}

- (void)testFirstSemicolonOrNewlineInRangeOfData_edgeCaseEnd
{
    NSString *testee = @"Test string goes on;";
    NSInteger expectedLocation = 19;
    [self assertFirstSemicolonOrNewlineInRangeWithTestee:testee expectedLocation:expectedLocation];
}

#pragma mark - locationsOfQuotes

- (void)testLocationOfQuotes
{
    NSString *testee = @"Test string goes on;";
    NSInteger expectedLocation = 19;
    [self assertFirstSemicolonOrNewlineInRangeWithTestee:testee expectedLocation:expectedLocation];
}

#pragma mark - Helper

- (void)assertFirstSemicolonOrNewlineInRangeWithTestee:(NSString *)input
                                      expectedLocation:(NSInteger)expectedLocation
{
    NSData *testee = [input dataUsingEncoding:NSASCIIStringEncoding];
    NSRange testRange = NSMakeRange(0, testee.length);
    NSRange foundRange = [testee firstSemicolonOrNewlineInRange:testRange];
    XCTAssertEqual(foundRange.location, expectedLocation);
}

@end
