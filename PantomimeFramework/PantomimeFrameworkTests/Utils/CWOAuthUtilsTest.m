//
//  CWOAuthUtilsTest.m
//  PantomimeTests
//
//  Created by Andreas Buff on 12.01.18.
//  Copyright © 2018 pEp Security S.A. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "CWOAuthUtils.h"

@interface CWOAuthUtilsTest : XCTestCase
@end

@implementation CWOAuthUtilsTest

- (void)testBase64EncodedClientResponseForUser {
    /*
     base64("user=" {User} "^Aauth=Bearer " {Access Token} "^A^A")
     using the base64 encoding mechanism defined in RFC 4648. ^A represents a Control+A (\001).

     For example, before base64-encoding, the initial client response might look like this:
     user=someuser@example.com^Aauth=Bearer vF9dft4qmTc2Nvb3RlckBhdHRhdmlzdGEuY29tCg==^A^A

     After base64-encoding, this becomes (line breaks inserted for clarity):
     dXNlcj1zb21ldXNlckBleGFtcGxlLmNvbQFhdXRoPUJlYXJlciB2RjlkZnQ0cW1UYzJOdmIzUmxj
     a0JoZEhSaGRtbHpkR0V1WTI5dENnPT0BAQ==
     */

    // Example data from Google docs: https://developers.google.com/gmail/imap/xoauth2-protocol
    NSString *user = @"someuser@example.com";
    NSString *token = @"vF9dft4qmTc2Nvb3RlckBhdHRhdmlzdGEuY29tCg==";
    NSString *expected = @"dXNlcj1zb21ldXNlckBleGFtcGxlLmNvbQFhdXRoPUJlYXJlciB2RjlkZnQ0cW1UYzJOdmIzUmxja0JoZEhSaGRtbHpkR0V1WTI5dENnPT0BAQ==";
    NSString *testee = [CWOAuthUtils base64EncodedClientResponseForUser:user accessToken:token];
    XCTAssertEqualObjects(testee, expected);
}

@end
