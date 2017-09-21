//
//  CWInternetAddressTest.m
//  Pantomime
//
//  Created by Andreas Buff on 12.09.17.
//  Copyright © 2017 pEp Security S.A. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "CWInternetAddress.h"

@interface CWInternetAddressTest : XCTestCase

@end

@implementation CWInternetAddressTest

#pragma mark - setPersonal

- (void)testInit
{
    NSString *userName = @"me@some.ch";
    NSString *address = @"unittest@some.ch";
    NSString *expectedUsername = @"\"me@some.ch\"";
    CWInternetAddress *testee = [[CWInternetAddress alloc] initWithPersonal:userName
                                                                    address:address];
    XCTAssertTrue([testee.personal isEqualToString:expectedUsername]);
}

- (void)testInit_alreadyQuoted
{
    NSString *userName = @"\"me@some.ch\"";
    NSString *address = @"unittest@some.ch";
    NSString *expectedUsername = @"\"me@some.ch\"";
    CWInternetAddress *testee = [[CWInternetAddress alloc] initWithPersonal:userName
                                                                    address:address];
    XCTAssertTrue([testee.personal isEqualToString:expectedUsername]);
}

- (void)testInit_prefixQuoted
{
    NSString *userName = @"\"me@some.ch";
    NSString *address = @"unittest@some.ch";
    NSString *expectedUsername = @"\"me@some.ch\"";
    CWInternetAddress *testee = [[CWInternetAddress alloc] initWithPersonal:userName
                                                                    address:address];
    XCTAssertTrue([testee.personal isEqualToString:expectedUsername]);
}

- (void)testInit_postfixQuoted
{
    NSString *userName = @"me@some.ch\"";
    NSString *address = @"unittest@some.ch";
    NSString *expectedUsername = @"\"me@some.ch\"";
    CWInternetAddress *testee = [[CWInternetAddress alloc] initWithPersonal:userName
                                                                    address:address];
    XCTAssertTrue([testee.personal isEqualToString:expectedUsername]);
}

#pragma mark - setPersonal

- (void)testSetPersonal
{
    NSString *userName = @"me@some.ch";
    NSString *expectedUsername = @"\"me@some.ch\"";
    CWInternetAddress *testee = [CWInternetAddress new];
    testee.personal = userName;
    XCTAssertTrue([testee.personal isEqualToString:expectedUsername]);
}

- (void)testSetPersonal_alreadyQuoted
{
    NSString *userName = @"\"me@some.ch\"";
    NSString *expectedUsername = @"\"me@some.ch\"";
    CWInternetAddress *testee = [CWInternetAddress new];
    testee.personal = userName;
    XCTAssertTrue([testee.personal isEqualToString:expectedUsername]);
}

- (void)testSetPersonal_prefixQuoted
{
    NSString *userName = @"\"me@some.ch";
    NSString *expectedUsername = @"\"me@some.ch\"";
    CWInternetAddress *testee = [CWInternetAddress new];
    testee.personal = userName;
    XCTAssertTrue([testee.personal isEqualToString:expectedUsername]);
}

- (void)testSetPersonal_postfixQuoted
{
    NSString *userName = @"me@some.ch\"";
    NSString *expectedUsername = @"\"me@some.ch\"";
    CWInternetAddress *testee = [CWInternetAddress new];
    testee.personal = userName;
    XCTAssertTrue([testee.personal isEqualToString:expectedUsername]);
}

@end
