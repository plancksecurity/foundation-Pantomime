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

- (CWIMAPMessage *)parseEmailFilePath:(NSString *)emailFilePath
{
    NSMutableData *emailData = [[TestUtil loadDataWithFileName:emailFilePath]
                                mutableCopy];
    [emailData replaceCRLFWithLF]; // This is what pantomime does with everything it receives
    XCTAssertNotNil(emailData);
    CWIMAPMessage *msg = [[CWIMAPMessage alloc] initWithData:emailData];
    XCTAssertNotNil(msg);
    return msg;
}

- (void)testParseFailureNotice
{
    CWIMAPMessage *msg = [self parseEmailFilePath:@"MailParsingAttachments.txt"];
    XCTAssertFalse([[msg content] isKindOfClass:[CWMIMEMultipart class]]);
    XCTAssertTrue([[msg content] isKindOfClass:[NSData class]]);
    XCTAssertNil(msg.contentType);
    XCTAssertEqualObjects(msg.subject, @"Failure Notice");
}

/// IOS-421_messed up encoding on special characters ("â" in this specific case)
- (void)testMessageHeapOverflowCanBeParsed
{
    CWIMAPMessage *msg = [self parseEmailFilePath:@"IOS-421_MessageHeapOverflow.txt"];
    XCTAssertTrue([msg.content isKindOfClass:CWMIMEMultipart.class]);
    XCTAssertEqualObjects(msg.contentType, @"multipart/signed");
    XCTAssertEqualObjects(msg.subject, @"test");
    XCTAssertEqualObjects(msg.from.personal, @"\"Hernâni Marques (p≡p foundation)\"");
    XCTAssertEqualObjects(msg.from.address, @"hernani.marques@pep.foundation");
}

- (void)testJpgAttached
{
    CWIMAPMessage *msg = [self parseEmailFilePath:@"MailWithJpgAttached.txt"];
    XCTAssertTrue([msg.content isKindOfClass:CWMIMEMultipart.class]);
    XCTAssertEqualObjects(msg.contentType, @"multipart/mixed");
    XCTAssertEqualObjects(msg.subject, @"Attachment");
    XCTAssertEqualObjects(msg.from.address, @"iostest001@peptest.ch");
    XCTAssertEqualObjects(msg.from.personal, @"\"Test 001\"");
}

- (void)testDocAttached
{
    CWIMAPMessage *msg = [self parseEmailFilePath:@"MailWithDocAttached.txt"];
    XCTAssertTrue([msg.content isKindOfClass:CWMIMEMultipart.class]);
    XCTAssertEqualObjects(msg.contentType, @"multipart/mixed");
    XCTAssertEqualObjects(msg.subject, @"Some attachment :)");
    XCTAssertEqualObjects(msg.from.address, @"iostest001@peptest.ch");
    XCTAssertEqualObjects(msg.from.personal, @"\"Test 001\"");
}

#pragma mark - IOS-1268 - Reference Parsing

//IOS-1268
- (void)testReferenceParsing_referencesSeperatedByTabs_OriginalMail
{
    NSSet *refsThatShouldBeContained =
    [NSSet
     setWithObjects:@"5B54E741.1020405@theover.org",
     @"trinity-4cc32f62-339f-4005-a04b-47332ae6a9c6-1532444355985@3c-app-webde-bs06",
     @"df6602fd08c731e4cee36b21bde6fbcb@synth.net",
     @"b188e0da-522f-fa7e-58df-1697d572526a@gmx.de", nil];

    [self assureReferenceParsingFilename:@"Reference_Parsing_Orig.txt"
                      expectedReferences:refsThatShouldBeContained];
}

//IOS-1268
- (void)testReferenceParsing_referencesSeperatedByTabs_CleanedMail
{
    NSSet *refsThatShouldBeContained =
    [NSSet
     setWithObjects:@"1", @"2", @"3", @"5", nil];

    [self assureReferenceParsingFilename:@"Reference_Parsing_Cleaned.txt"
                      expectedReferences:refsThatShouldBeContained];
}

#pragma mark - HELPER

- (void)assureReferenceParsingFilename:(NSString *)filename
                    expectedReferences:(NSSet *)expectedReferences
{
    CWIMAPMessage *msg = [self parseEmailFilePath:filename];
    NSSet *actualReferences = [[NSSet alloc] initWithArray:msg.allReferences];
    XCTAssertEqualObjects(actualReferences, expectedReferences);
}

@end
