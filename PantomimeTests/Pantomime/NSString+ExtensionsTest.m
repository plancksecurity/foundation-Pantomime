//
//  NSString+ExtensionsTest.m
//  Pantomime
//
//  Created by buff on 21.07.17.
//  Copyright © 2017 pEp Security S.A. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NSString+Extensions.h"

@interface NSString_ExtensionsTest : XCTestCase
@property NSDictionary *imapUtf7ForUtf8;
@end

@implementation NSString_ExtensionsTest

- (void)setUp
{
    /** modified UTF7 strings (values) for the corresponding UTF8 strings (keys) */
    self.imapUtf7ForUtf8 = @{@"[Gmail]/Entwürfe":@"[Gmail]/Entw&APw-rfe",
                             @"äöüÄÖÜ":@"&AOQA9gD8AMQA1gDc-",
                             @"AäAöAüAÄAÖAÜA":@"A&AOQ-A&APY-A&APw-A&AMQ-A&ANY-A&ANw-A"};
}

#pragma mark - modifiedUTF7String

- (void)testModifiedUTF7String
{
    for (int i = 0; i < self.imapUtf7ForUtf8.count; ++i) {
        NSString *testUtf8 = self.imapUtf7ForUtf8.allKeys[i];
        NSString *expected = self.imapUtf7ForUtf8[testUtf8];
        NSString *testeeImapUtf7 = [testUtf8 modifiedUTF7String];
        XCTAssertEqualObjects(testeeImapUtf7, expected);
    }
}

#pragma mark - stringFromModifiedUTF7

- (void)testStringFromModifiedUTF7
{
    for (int i = 0; i < self.imapUtf7ForUtf8.count; ++i) {
        NSString *expected = self.imapUtf7ForUtf8.allKeys[i];
        NSString *testImapUtf7 = self.imapUtf7ForUtf8[expected];
        NSString *testeeUtf8 = [testImapUtf7 stringFromModifiedUTF7];
        XCTAssertEqualObjects(testeeUtf8, expected);
    }
}

#pragma mark - stringWithData:charset:

- (void)testStringWithData_utf8 {
    NSString *nameEncoding = @"utf-8";
    NSStringEncoding encoding = NSUTF8StringEncoding;

    NSArray<NSString*> *charsOrig = [self allUTF8Chars];
    NSArray<NSData*> *charsDataOrig = [self dataForCharsWith:encoding];
    NSData *charSet = [nameEncoding dataUsingEncoding:NSUTF8StringEncoding];

    for (int i = 0; i < charsOrig.count; ++i) {
        NSString *orig = charsOrig[i];
        NSData *origData = charsDataOrig[i];
        NSString *testee = [NSString stringWithData:origData charset:charSet];
        XCTAssert([testee isEqualToString:orig], @"%@ != %@", testee, orig);
    }
}

#pragma mark - HELPER

- (NSArray<NSData*> *)dataForCharsWith: (NSStringEncoding)encoding {
    NSArray<NSString*> *allChars = [self allUTF8Chars];
    NSMutableArray<NSData*> *result = [NSMutableArray arrayWithCapacity:allChars.count];

    for (NSString *curChar in allChars) {
        NSData *data = [curChar dataUsingEncoding:encoding];
        [result addObject:data];
    }

    return result;
}

- (NSArray<NSString*> *)allUTF8Chars {
    return [self utf16CharsFrom:0 to:UINT8_MAX];
}

- (NSArray *)utf16CharsFrom: (uint16_t) from to: (uint16_t) to {
    NSParameterAssert(from < UINT16_MAX);
    NSParameterAssert(to < UINT16_MAX);

    NSMutableArray *result = [NSMutableArray new];

    for (uint16_t i = from; i < to; i++) {
        NSString *uniString = [NSString stringWithCharacters:(unichar *)&i length:1];
        [result addObject:uniString];
    }

    return [result copy];
}

@end
