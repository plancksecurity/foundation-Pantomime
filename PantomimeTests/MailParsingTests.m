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

//IOS-1225
- (void)testFromAddressIgnored
{
    CWIMAPMessage *msg = [self parseEmailFilePath:@"IOS-1225_from-address_not_ignored.txt"];
    XCTAssertEqualObjects(msg.from.address, @"ebay@ebay.com");
    XCTAssertEqualObjects(msg.from.personal, @"\"eBay\"");
}

/**
 IOS-1300
 */
- (void)testOdtWithSpaceAttached
{
    CWIMAPMessage *cwMsg = [self parseEmailFilePath:@"IOS-1300_odt_attachment.txt"];
    XCTAssertTrue([cwMsg.content isKindOfClass:CWMIMEMultipart.class]);
    XCTAssertEqualObjects(cwMsg.contentType, @"multipart/mixed");
    XCTAssertEqualObjects(cwMsg.subject, @"needed");
    XCTAssertEqualObjects(cwMsg.from.address, @"someone@yahoo.de");
    XCTAssertEqualObjects(cwMsg.from.personal, @"\"jools\"");

    id theContent = cwMsg.content;
    XCTAssertNotNil(theContent);
    CWMIMEMultipart *part = (CWMIMEMultipart *) theContent;
    XCTAssertEqual(part.count, 2);

    BOOL haveFoundOdt = NO;
    for (int i = 0; i < part.count; ++i) {
        CWPart *subPart = [part partAtIndex:i];
        if ([subPart.contentType isEqualToString:@"application/vnd.oasis.opendocument.text"]) {
            haveFoundOdt = YES;
            XCTAssertEqualObjects(subPart.filename, @"Someone andTextIncludingTheSpace.odt");
        }
    }
    XCTAssertTrue(haveFoundOdt);
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

// IOS-1340
- (void)testNilAttachment
{
    CWIMAPMessage *cwMsg = [self parseEmailFilePath:@"IOS-1340_NilAttachmentMail.txt"];
    XCTAssertTrue([cwMsg.content isKindOfClass:CWMIMEMultipart.class]);
    XCTAssertEqualObjects(cwMsg.contentType, @"multipart/related");
    XCTAssertEqualObjects(cwMsg.subject, @"Re: test 001");
    XCTAssertEqualObjects(cwMsg.from.address, @"iostest001@peptest.ch");
    XCTAssertEqualObjects(cwMsg.from.personal, @"\"Rick Deckard\"");

    id theContent = cwMsg.content;
    XCTAssertNotNil(theContent);
    CWMIMEMultipart *part = (CWMIMEMultipart *) theContent;
    XCTAssertEqual(part.count, 2);

    for (int i = 0; i < part.count; ++i) {
        CWPart *subPart = [part partAtIndex:i];
        if (i == 0) {
            XCTAssertEqualObjects(subPart.contentType, @"text/plain");
        } else if (i == 1) {
            XCTAssertEqualObjects(subPart.contentType, @"application/pgp-keys");
        } else {
            XCTFail(@"Unexpected attachment: %@", subPart);
        }
    }
}

/**
 IOS-1364
 */
- (void)testUndisplayedImageAttached
{
    CWIMAPMessage *cwMsg = [self parseEmailFilePath:@"1364_Mail_missing_attached_image.txt"];
    XCTAssertTrue([cwMsg.content isKindOfClass:CWMIMEMultipart.class]);
    XCTAssertEqualObjects(cwMsg.contentType, @"multipart/mixed");
    XCTAssertEqualObjects(cwMsg.subject, @"blah");
    XCTAssertEqualObjects(cwMsg.from.address, @"blah@example.com");
    XCTAssertEqualObjects(cwMsg.from.personal, @"\"Oh Noes\"");

    id theContent = cwMsg.content;
    XCTAssertNotNil(theContent);
    CWMIMEMultipart *part = (CWMIMEMultipart *) theContent;
    XCTAssertEqual(part.count, 3);

    for (int i = 0; i < part.count; ++i) {
        CWPart *subPart = [part partAtIndex:i];
        if (i == 0 || i == 2) {
            XCTAssertEqualObjects(subPart.contentType, @"text/plain");
            NSString *theContent = [subPart.dataValue asciiString];
            XCTAssertEqualObjects(theContent, @"Version: 1");
        } else if (i == 1) {
            XCTAssertEqualObjects(subPart.contentType, @"image/jpeg");
        }
    }
}

/**
 IOS-1351
 */
/*
- (void)testClassicPGPMime
{
    CWIMAPMessage *cwMsg = [self
                            parseEmailFilePath:@"SimplifiedKeyImport_Harry_To_Rick_with_Leon.txt"];
    XCTAssertTrue([cwMsg.content isKindOfClass:CWMIMEMultipart.class]);
    XCTAssertEqualObjects(cwMsg.contentType, @"multipart/encrypted");
    XCTAssertEqualObjects(cwMsg.subject, @"Simplified Key Import");
    XCTAssertEqualObjects(cwMsg.from.address, @"iostest002@peptest.ch");
    XCTAssertEqualObjects(cwMsg.from.personal, @"\"Harry Bryant\"");

    id theContent = cwMsg.content;
    XCTAssertNotNil(theContent);
    CWMIMEMultipart *part = (CWMIMEMultipart *) theContent;
    XCTAssertEqual(part.count, 2);

    for (int i = 0; i < part.count; ++i) {
        CWPart *subPart = [part partAtIndex:i];
        if (i == 0) {
            XCTAssertEqualObjects(subPart.contentType, @"application/pgp-encrypted");
            NSString *theContent = [subPart.dataValue asciiString];
            XCTAssertEqualObjects(theContent, @"Version: 1");
        } else if (i == 1) {
            XCTAssertEqualObjects(subPart.contentType, @"application/octet-stream");
            NSString *theContent = [subPart.dataValue asciiString];
            NSString *pgpBoilerPlate = [theContent substringToIndex:27];
            XCTAssertEqualObjects(pgpBoilerPlate, @"-----BEGIN PGP MESSAGE-----");
        }
    }
}
 */

#pragma mark - HELPER

- (void)assureReferenceParsingFilename:(NSString *)filename
                    expectedReferences:(NSSet *)expectedReferences
{
    CWIMAPMessage *msg = [self parseEmailFilePath:filename];
    NSSet *actualReferences = [[NSSet alloc] initWithArray:msg.allReferences];
    XCTAssertEqualObjects(actualReferences, expectedReferences);
}

@end
