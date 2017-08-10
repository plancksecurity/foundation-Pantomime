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
    XCTAssertEqualObjects(msg.subject, @"Failure Notice");
}

/// IOS-421_messed up encoding on special characters ("â" in this specific case)
- (void)testMessageHeapOverflowCanBeParsed
{
    NSMutableData *emailData = [[TestUtil loadDataWithFileName:@"IOS-421_MessageHeapOverflow.txt"]
                                mutableCopy];
    [emailData replaceCRLFWithLF]; // This is what pantomime does with everything it receives
    XCTAssertNotNil(emailData);
    CWIMAPMessage *msg = [[CWIMAPMessage alloc] initWithData:emailData];
    XCTAssertNotNil(msg);
    XCTAssertTrue([msg.content isKindOfClass:CWMIMEMultipart.class]);
    XCTAssertEqualObjects(msg.contentType, @"multipart/signed");
    XCTAssertEqualObjects(msg.subject, @"test");
    XCTAssertEqualObjects(msg.from.address, @"Hernâni Marques (p≡p foundation)");
}

@end
