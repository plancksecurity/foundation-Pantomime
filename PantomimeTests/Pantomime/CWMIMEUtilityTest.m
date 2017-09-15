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
#import "CWMessage.h"
#import "NSString+Extensions.h"

@interface CWMIMEUtilityTest : XCTestCase
@end

@implementation CWMIMEUtilityTest

// IOS-411 Sender coding text encoding could be wrong
- (void)testDecodeHeader_utf8_Q_personal {
    NSData *data =[@"=?utf-8?Q?Igor_Vojinovi=C4=87?= <igor.vojinovic@appculture.com>"
                   dataUsingEncoding:NSUTF8StringEncoding];
    NSString *charSet = nil;
    NSString *testee = [CWMIMEUtility decodeHeader:data charset:charSet];
    CWInternetAddress *internetAddress = [[CWInternetAddress alloc] initWithString:testee];

    NSString *expectedAddress =  @"igor.vojinovic@appculture.com";
    XCTAssertEqualObjects(internetAddress.address, expectedAddress);

    NSString *expectedPersonal =  @"\"Igor Vojinović\"";
    XCTAssertEqualObjects(internetAddress.personal, expectedPersonal);
}

//IOS-710 Subject messed up for p≡p
- (void)testDecodeHeader_subject {
    NSData *data =[@"=?iso-2022-jp?q?p=1B=24B=22a=1B=28Bp?="
                   dataUsingEncoding:NSUTF8StringEncoding];
    NSString *expected = @"p≡p";
    NSString *charSet = nil;
    NSString *testee = [CWMIMEUtility decodeHeader:data charset:charSet];
    XCTAssertTrue([expected isEqualToString:testee]);
}

@end
