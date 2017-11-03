//
//  NSData+PantomimeExtensionsTest.m
//  Pantomime
//
//  Created by buff on 11.08.17.
//  Copyright © 2017 pEp Security S.A. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NSData+Extensions.h"

@interface NSData_PantomimeExtensionsTest : XCTestCase
@property (strong, nonatomic) NSString *nastyUtf8String;
@property (strong, nonatomic) NSData *dataNastyUtf8String;
@property (strong, nonatomic) NSString *emptyString;

@property (strong, nonatomic) NSString *searchStr;
@property (strong, nonatomic) NSString *searchStrUpper;
@property (strong, nonatomic) NSString *searchStrLower;
@property (nonatomic) const char *cSearchStr;
@property (nonatomic) const char *cSearchStrUpper;
@property (nonatomic) const char *cSearchStrLower;

@property (strong, nonatomic) NSString *stringContainingSearchStr;
@property (strong, nonatomic) NSString *stringLeadingSearchStr;
@property (strong, nonatomic) NSString *stringTrailingSearchStr;

@property (strong, nonatomic) NSData *dataContainingSearchStr;
@property (strong, nonatomic) NSData *dataLeadingSearchStr;
@property (strong, nonatomic) NSData *dataTrailingSearchStr;
@end

@implementation NSData_PantomimeExtensionsTest

- (void)setUp
{
    [super setUp];
    self.nastyUtf8String = @"Å0ä9Å0å4Å0ç0®¶®®Å0ä5®∫Å0é1Å0ç9®•®≤®π®¥Å0ã4®±®™Å0ä7®¨Å0ä6Å0ê1®©®ÆÅ0Ü2®∞Å0ã2Å0ã0Å0ã1Å0ã3Å0ì4®≠`^[+*]Å0Ö7°ß{Å0ä4Å0á5}-_®C.:°≠,;Å6•7Å0Ñ3Å0Ü7Å6•50=°Ÿ9)°±8(°∞7/°¬6&Å0Ö15%°ﬁ4$Å0Ñ43°§#2°±@1!|";
    self.dataNastyUtf8String = [self.nastyUtf8String dataUsingEncoding:NSUTF8StringEncoding];
    self.emptyString = @"";

    NSString *defaultSearchString = @"defaultSearchString";
    [self setupTestDataForSerachString:defaultSearchString];
}

#pragma mark - RangeOfCString

- (void)testRangeOfCString_ascii
{
    NSString *searchStr = @"asciiSearchStr!";
    [self setupTestDataForSerachString:searchStr];
    [self assertValidSearchResultsCaseSensitive];
    [self assertValidSearchResultsCaseInsensitive];
}

#pragma mark invalid string

- (void)testRangeOfCString_stringShorterSearchString
{
    NSString *searchStr = @"asciiSearchStr!";
    const char *cSearchStr = [searchStr UTF8String];
    NSString *strg = @"asciiStr!";
    NSData *strData = [strg dataUsingEncoding:NSUTF8StringEncoding];

    XCTAssertFalse([self hasBeenFound: [strData rangeOfCString: cSearchStr options:0]]);
}

- (void)testRangeOfCString_stringShorterSearchString_caseInsensitive
{
    NSString *searchStr = @"asciiSearchStr!";
    const char *cSearchStr = [searchStr UTF8String];
    NSString *strg = @"asciiStr!";
    NSData *strData = [strg dataUsingEncoding:NSUTF8StringEncoding];

    XCTAssertFalse([self hasBeenFound: [strData rangeOfCString: cSearchStr options:NSCaseInsensitiveSearch]]);
}

#pragma mark empty string

- (void)testRangeOfCString_emptySearchString
{
    NSString *searchStr = @"";
    const char *cSearchStr = [searchStr UTF8String];
    NSString *strg = @"asciiStr!";
    NSData *strData = [strg dataUsingEncoding:NSUTF8StringEncoding];

    XCTAssertFalse([self hasBeenFound: [strData rangeOfCString: cSearchStr options:0]]);
}

- (void)testRangeOfCString_nullSearchString
{
    const char *cSearchStr = NULL;
    NSString *strg = @"asciiStr!";
    NSData *strData = [strg dataUsingEncoding:NSUTF8StringEncoding];

    XCTAssertFalse([self hasBeenFound: [strData rangeOfCString: cSearchStr options:0]]);
}

- (void)testRangeOfCString_emptyString
{
    NSString *searchStr = @"asciiStr!";
    const char *cSearchStr = [searchStr UTF8String];
    NSString *strg = @"";
    NSData *strData = [strg dataUsingEncoding:NSUTF8StringEncoding];

    XCTAssertFalse([self hasBeenFound: [strData rangeOfCString: cSearchStr options:0]]);
}

//IOS-196
- (void)testRangeOfCString_emptyStringAndEmptySearchString
{
    NSString *searchStr = @"";
    const char *cSearchStr = [searchStr UTF8String];
    NSString *strg = @"";
    NSData *strData = [strg dataUsingEncoding:NSUTF8StringEncoding];

    XCTAssertFalse([self hasBeenFound: [strData rangeOfCString: cSearchStr options:0]]);
}

#pragma mark escapees
//IOS-196
- (void)testRangeOfCString_escapedChars
{
    NSArray *escapees = @[@"\n",
                         @"\t",
                         @"\"",
                         @"\0",
                         @"\\",
                         @"\b",
                         @"\f",
                         @"\r",
                         @"\v"];
    for (int i = 0; i < escapees.count; ++i) {
        XCTAssertTrue([self hasBeenFound:
                       [self.dataContainingSearchStr rangeOfCString:self.cSearchStr options:0]]);
        XCTAssertFalse([self hasBeenFound:
                       [self.dataNastyUtf8String rangeOfCString:self.cSearchStr options:0]]);
        XCTAssertTrue([self hasBeenFound:
                       [self.dataContainingSearchStr rangeOfCString:self.cSearchStr
                                                            options:NSCaseInsensitiveSearch]]);
        XCTAssertFalse([self hasBeenFound:
                        [self.dataNastyUtf8String rangeOfCString:self.cSearchStr
                                                         options:NSCaseInsensitiveSearch]]);
    }
}

#pragma mark RangeOfCString Helper

-(void)assertValidSearchResultsCaseSensitive
{
    XCTAssertTrue([self hasBeenFound:
                   [self.dataContainingSearchStr rangeOfCString:self.cSearchStr options:0]]);
    XCTAssertFalse([self hasBeenFound:
                    [self.dataContainingSearchStr rangeOfCString:self.cSearchStrUpper options:0]]);
    XCTAssertFalse([self hasBeenFound:
                    [self.dataContainingSearchStr rangeOfCString:self.cSearchStrLower options:0]]);

}

-(void)assertValidSearchResultsCaseInsensitive
{
    XCTAssertTrue([self hasBeenFound:
                   [self.dataContainingSearchStr rangeOfCString:self.cSearchStr
                                                        options:NSCaseInsensitiveSearch]]);
    XCTAssertTrue([self hasBeenFound:
                   [self.dataContainingSearchStr rangeOfCString:self.cSearchStrUpper
                                                        options:NSCaseInsensitiveSearch]]);
    XCTAssertTrue([self hasBeenFound:
                   [self.dataContainingSearchStr rangeOfCString:self.cSearchStrLower
                                                        options:NSCaseInsensitiveSearch]]);
}

#pragma mark - componentsSeparatedByCString

-(void)testComponentsSeparatedByCString_ascii
{
    NSString *seperator = @"ASCII_AbcdEfg12345678!";
    NSString *wholeStr = [NSString stringWithFormat:@"%@%@%@", self.nastyUtf8String, seperator,
                          self.nastyUtf8String];
    NSData *wholeData = [wholeStr dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *realComponents = [wholeStr componentsSeparatedByString:seperator];
    const char *cSeperator = [seperator UTF8String];

    NSArray *testees = [wholeData componentsSeparatedByCString:cSeperator];
    [self assureEqualStrings:testees strings:realComponents];
}

-(void)testComponentsSeparatedByCString_utf8
{
    NSString *seperator = @"UTF8_Å0ä9Å0å4Å0ç0®¶®®Å0ä5®∫Å0é1Å0ç9®•®≤®π";
    NSString *wholeStr = [NSString stringWithFormat:@"%@%@%@", self.nastyUtf8String, seperator,
                          self.nastyUtf8String];
    NSData *wholeData = [wholeStr dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *realComponents = [wholeStr componentsSeparatedByString:seperator];
    const char *cSeperator = [seperator UTF8String];

    NSArray *testees = [wholeData componentsSeparatedByCString:cSeperator];
    [self assureEqualStrings:testees strings:realComponents];
}

-(void)testComponentsSeparatedByCString_utf8_unknownSeperator
{
    NSString *seperator = @"UTF8_Å0ä9Å0å4Å0ç0®¶®®Å0ä5®∫Å0é1Å0ç9®•®≤®π";
    NSString *wholeStrWithoutSeperatorIncluded = [NSString stringWithFormat:@"%@%@",
                                                  self.nastyUtf8String, self.nastyUtf8String];
    NSData *wholeData = [wholeStrWithoutSeperatorIncluded dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *realComponents = [wholeStrWithoutSeperatorIncluded componentsSeparatedByString:seperator];
    const char *cSeperator = [seperator UTF8String];

    NSArray *testees = [wholeData componentsSeparatedByCString:cSeperator];
    [self assureEqualStrings:testees strings:realComponents];
}

-(void)testComponentsSeparatedByCString_emptyString
{
    NSString *seperator = @"ASCII_AbcdEfg12345678!";
    NSString *wholeStr = @"";
    NSData *wholeData = [wholeStr dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *realComponents = [wholeStr componentsSeparatedByString:seperator];
    const char *cSeperator = [seperator UTF8String];

    NSArray *testees = [wholeData componentsSeparatedByCString:cSeperator];
    [self assureEqualStrings:testees strings:realComponents];
}

-(void)testComponentsSeparatedByCString_emptySearchString
{
    NSString *seperator = @"";
    NSString *wholeStr = [NSString stringWithFormat:@"%@%@%@", self.nastyUtf8String, seperator,
                          self.nastyUtf8String];
    NSData *wholeData = [wholeStr dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *realComponents = [wholeStr componentsSeparatedByString:seperator];
    const char *cSeperator = [seperator UTF8String];

    NSArray *testees = [wholeData componentsSeparatedByCString:cSeperator];
    [self assureEqualStrings:testees strings:realComponents];
}

-(void)testComponentsSeparatedByCString_emptyStringAndSearchString
{
    NSString *seperator = @"";
    NSString *wholeStr = @"";
    NSData *wholeData = [wholeStr dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *realComponents = [wholeStr componentsSeparatedByString:seperator];
    const char *cSeperator = [seperator UTF8String];

    NSArray *testees = [wholeData componentsSeparatedByCString:cSeperator];
    [self assureEqualStrings:testees strings:realComponents];
}

#pragma mark - imapUtf7String

// IOS-734
-(void)testImapUtf7String
{
    NSDictionary *utf7ImapEncodedStringForString = @{@"ä":@"&AOQ-",
                                                     @"ö":@"&APY-",
                                                     @"ü":@"&APw-",
                                                     @"Ä":@"&AMQ-",
                                                     @"Ö":@"&ANY-",
                                                     @"Ü":@"&ANw-",
                                                     @"ß":@"&AN8-",
                                                     @"&":@"&-",
                                                     @"a":@"a",
                                                     @"A":@"A",
                                                     @"Entwürfe":@"Entw&APw-rfe",
                                                     @"Gelöscht":@"Gel&APY-scht"
                                                     };

    for (NSString *key in utf7ImapEncodedStringForString.allKeys) {
        NSString *uft7ImapEncodedString = utf7ImapEncodedStringForString[key];
        NSData *utf7ImapEncodedData = [uft7ImapEncodedString dataUsingEncoding:NSUTF8StringEncoding];

        NSString *expected = key;
        NSString *testee = [utf7ImapEncodedData imapUtf7String];
        NSLog(@"expected:\t%@\ttestee:\t%@", expected, testee);
        XCTAssertTrue([expected isEqualToString:testee]);
    }
}

#pragma mark - HELPER

- (BOOL)equalsNotFound: (NSRange)range
{
    return NSEqualRanges(range, NSMakeRange(NSNotFound,0));
}

- (BOOL)hasBeenFound: (NSRange)range {
    return ![self equalsNotFound: range];
}

- (void)setupTestDataForSerachString:(NSString*)searchStr
{
    self.searchStr = searchStr;
    self.cSearchStr = [searchStr UTF8String];

    self.searchStrUpper = [searchStr uppercaseString];
    self.cSearchStrUpper = [self.searchStrUpper UTF8String];

    self.searchStrLower = [searchStr lowercaseString];
    self.cSearchStrLower = [self.searchStrLower UTF8String];

    self.stringContainingSearchStr = [NSString stringWithFormat:@"%@%@%@",
                                      self.nastyUtf8String,
                                      searchStr,
                                      self.nastyUtf8String];
    self.stringLeadingSearchStr = [NSString stringWithFormat:@"%@%@",searchStr, self.nastyUtf8String];
    self.stringTrailingSearchStr = [NSString stringWithFormat:@"%@%@",self.nastyUtf8String, searchStr];

    self.dataContainingSearchStr = [self.stringContainingSearchStr dataUsingEncoding:NSUTF8StringEncoding];
    self.dataLeadingSearchStr = [self.stringLeadingSearchStr dataUsingEncoding:NSUTF8StringEncoding];
    self.dataTrailingSearchStr = [self.stringTrailingSearchStr dataUsingEncoding:NSUTF8StringEncoding];
}

#pragma mark RangeOfCString Helper

- (void)assureEqualStrings:(NSArray<NSData*> *)datas strings:(NSArray<NSString*> *)strings
{
    if (datas.count != strings.count) {
        XCTFail("Not equal");
        return;
    }

    for (int i = 0; i < datas.count; ++i) {
        NSString *testee = [[NSString alloc] initWithData:datas[i] encoding:NSUTF8StringEncoding];
        XCTAssertEqualObjects(testee, strings[i]);
    }
}

@end
