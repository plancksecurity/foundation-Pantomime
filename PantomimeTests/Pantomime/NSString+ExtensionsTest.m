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
@end

@implementation NSString_ExtensionsTest

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
