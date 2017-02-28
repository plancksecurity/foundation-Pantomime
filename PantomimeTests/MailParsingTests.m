//
//  MailParsingTests.m
//  Pantomime
//
//  Created by Dirk Zimmermann on 27/02/2017.
//  Copyright © 2017 pEp Security S.A. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "TestUtil.h"
#import "Pantomime.h"

@interface MailParsingTests : XCTestCase

@end

@implementation MailParsingTests

- (void)testParseFailureNotice
{
    NSData *emailData = [TestUtil loadDataWithFileName:@"MailParsingAttachments.txt"];
    XCTAssertNotNil(emailData);
    CWIMAPMessage *msg = [[CWIMAPMessage alloc] initWithData:emailData];
    XCTAssertNotNil(msg);
    XCTAssertFalse([[msg content] isKindOfClass:[CWMIMEMultipart class]]);
    XCTAssertTrue([[msg content] isKindOfClass:[NSData class]]);
    XCTAssertNil(msg.contentType);
    NSLog(@"|%@|", msg.subject);
    XCTAssertTrue([msg.subject isEqualToString:@"Failure Notice"]);
    XCTAssertEqualObjects(msg.subject, @"Failure Notice");
}

@end
