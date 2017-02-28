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
    NSMutableData *emailData = [[TestUtil loadDataWithFileName:@"MailParsingAttachments.txt"]
                                mutableCopy];
    [emailData replaceCRLFWithLF]; // This is what pantomime does with everything it receives
    XCTAssertNotNil(emailData);
    CWIMAPMessage *msg = [[CWIMAPMessage alloc] initWithData:emailData];
    XCTAssertNotNil(msg);
    XCTAssertFalse([[msg content] isKindOfClass:[CWMIMEMultipart class]]);
    XCTAssertTrue([[msg content] isKindOfClass:[NSData class]]);
    XCTAssertNil(msg.contentType);
    XCTAssertTrue([msg.subject isEqualToString:@"Failure Notice"]);
    XCTAssertEqualObjects(msg.subject, @"Failure Notice");
}

@end
