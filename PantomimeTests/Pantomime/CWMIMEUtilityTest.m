//
//  CWMIMEUtility.m
//  Pantomime
//
//  Created by buff on 21.07.17.
//  Copyright © 2017 pEp Security S.A. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "CWMIMEUtility.h"
#import "CWInternetAddress.h"

@interface CWMIMEUtilityTest : XCTestCase
@end

@implementation CWMIMEUtilityTest

// IOS-411 Sender coding text encoding could be wrong
- (void)testDecodeHeader_utf8_Q {
    NSData *data =[@"=?utf-8?Q?Igor_Vojinovi=C4=87?= <igor.vojinovic@appculture.com>" dataUsingEncoding:NSUTF8StringEncoding];
    NSString *charSet = nil;
    NSString *testee = [CWMIMEUtility decodeHeader:data charset:charSet];
    CWInternetAddress *internetAddress = [[CWInternetAddress alloc] initWithString:testee];

    NSString *expectedAddress =  @"igor.vojinovic@appculture.com";
    XCTAssert([internetAddress.address isEqualToString:expectedAddress]);

    NSString *expectedPersonal =  @"Igor Vojinović";
    XCTAssert([internetAddress.personal isEqualToString:expectedPersonal]);
}

@end
