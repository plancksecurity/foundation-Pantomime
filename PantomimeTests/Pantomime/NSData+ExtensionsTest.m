//
//  NSData+ExtensionsTest.m
//  PantomimeTests
//
//  Created by Andreas Buff on 06.11.17.
//  Copyright © 2017 pEp Security S.A. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "NSData+Extensions.h"

@interface NSData_ExtensionsTest : XCTestCase
@end

@implementation NSData_ExtensionsTest

#pragma mark - unwrap

- (void)testUnwrap_wrapped
{
    NSString *testStr = @"<35BE75EB.74E6.4CB7.9C5D.432B241FDF90@pretty.Easy.privacy>";
    NSString *expected = @"35BE75EB.74E6.4CB7.9C5D.432B241FDF90@pretty.Easy.privacy";
    NSData *testData = [testStr dataUsingEncoding:NSUTF8StringEncoding];
    NSData *testeeData = [testData unwrap];
    NSString* testee = [[NSString alloc] initWithData:testeeData encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(testee, expected);
}

- (void)testUnwrap_unwrapped
{
    NSString *testStr = @"35BE75EB.74E6.4CB7.9C5D.432B241FDF90@pretty.Easy.privacy";
    NSString *expected = @"35BE75EB.74E6.4CB7.9C5D.432B241FDF90@pretty.Easy.privacy";
    NSData *testData = [testStr dataUsingEncoding:NSUTF8StringEncoding];
    NSData *testeeData = [testData unwrap];
    NSString* testee = [[NSString alloc] initWithData:testeeData encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(testee, expected);
}

//IOS-1175 "Let=E2=80=99s see.=" decdoded as "Let's see.="
- (void)testDecodeQuotedPrintableInHeader
{
    NSString *testStr = @"Let=E2=80=99s see.=";
    NSString *expected = @"Let’s see.";
    NSData *testData = [testStr dataUsingEncoding:NSASCIIStringEncoding];
    NSData *testeeData = [testData decodeQuotedPrintableInHeader:NO];
    NSString* testee = [[NSString alloc] initWithData:testeeData encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(testee, expected);
}

#pragma mark - dataByTrimmingWhiteSpaces

static NSString *text = @"My test\t Text containing 1234567890ß? stuff";

// Space

- (void)testDataByTrimmingWhiteSpaces_space
{
    NSString *testee = @" ";
    NSString *expected = @"";
    [self assertDataByTrimmingWhiteSpacesWithSource:testee expectedResult:expected];
}

- (void)testDataByTrimmingWhiteSpaces_spaceSpace
{
    NSString *testee = @" ";
    NSString *expected = @"";
    [self assertDataByTrimmingWhiteSpacesWithSource:testee expectedResult:expected];
}

- (void)testDataByTrimmingWhiteSpaces_spaceSpaceSpace
{
    NSString *testee = @"   ";
    NSString *expected = @"";
    [self assertDataByTrimmingWhiteSpacesWithSource:testee expectedResult:expected];
}

- (void)testDataByTrimmingWhiteSpaces_spaceTextspace
{
    NSString *testFormat = @" %@ ";
    [self assertDataByTrimmingWhiteSpacesFromTestStringUsedInFormat:testFormat];
}

- (void)testDataByTrimmingWhiteSpaces_textSpace
{
    NSString *testFormat = @"%@ ";
    [self assertDataByTrimmingWhiteSpacesFromTestStringUsedInFormat:testFormat];
}

- (void)testDataByTrimmingWhiteSpaces_spaceText
{
    NSString *testFormat = @" %@";
    [self assertDataByTrimmingWhiteSpacesFromTestStringUsedInFormat:testFormat];
}

// Tabs
- (void)testDataByTrimmingWhiteSpaces_tab
{
    NSString *testee = @"\t";
    NSString *expected = @"";
    [self assertDataByTrimmingWhiteSpacesWithSource:testee expectedResult:expected];
}

- (void)testDataByTrimmingWhiteSpaces_tabtab
{
    NSString *testee = @"\t\t";
    NSString *expected = @"";
    [self assertDataByTrimmingWhiteSpacesWithSource:testee expectedResult:expected];
}

- (void)testDataByTrimmingWhiteSpaces_tabtabtab
{
    NSString *testee = @"\t\t\t";
    NSString *expected = @"";
    [self assertDataByTrimmingWhiteSpacesWithSource:testee expectedResult:expected];
}

- (void)testDataByTrimmingWhiteSpaces_tabTextTab
{
    NSString *testFormat = @"\t%@\t";
    [self assertDataByTrimmingWhiteSpacesFromTestStringUsedInFormat:testFormat];
}

- (void)testDataByTrimmingWhiteSpaces_textTab
{
    NSString *testFormat = @"%@\t";
    [self assertDataByTrimmingWhiteSpacesFromTestStringUsedInFormat:testFormat];
}

- (void)testDataByTrimmingWhiteSpaces_tabText
{
    NSString *testFormat = @"\t%@";
    [self assertDataByTrimmingWhiteSpacesFromTestStringUsedInFormat:testFormat];
}

// Mixed

- (void)testDataByTrimmingWhiteSpaces_textOnly
{
    NSString *testFormat = @"%@";
    NSString *testee = [NSString stringWithFormat:testFormat, text];
    NSString *expected = text;
    [self assertDataByTrimmingWhiteSpacesWithSource:testee expectedResult:expected];
}

- (void)testDataByTrimmingWhiteSpaces_empty
{
    NSString *testee = @"";
    NSString *expected = @"";
    [self assertDataByTrimmingWhiteSpacesWithSource:testee expectedResult:expected];
}

- (void)testDataByTrimmingWhiteSpaces_tabSpacetabSpaceSpacetabSpace
{
    NSString *testee = @"\t \t  \t ";
    NSString *expected = @"";
    [self assertDataByTrimmingWhiteSpacesWithSource:testee expectedResult:expected];
}

///
- (void)testDataByTrimmingWhiteSpaces_tabSpace
{
    NSString *testee = @"\t ";
    NSString *expected = @"";
    [self assertDataByTrimmingWhiteSpacesWithSource:testee expectedResult:expected];
}

- (void)testDataByTrimmingWhiteSpaces_spaceTab
{
    NSString *testee = @" \t";
    NSString *expected = @"";
    [self assertDataByTrimmingWhiteSpacesWithSource:testee expectedResult:expected];
}

- (void)testDataByTrimmingWhiteSpaces_tabSpacetab
{
    NSString *testee = @"\t \t";
    NSString *expected = @"";
    [self assertDataByTrimmingWhiteSpacesWithSource:testee expectedResult:expected];
}

- (void)testDataByTrimmingWhiteSpaces_tabTextSapce
{
    NSString *testFormat = @"\t%@ ";
    [self assertDataByTrimmingWhiteSpacesFromTestStringUsedInFormat:testFormat];
}

- (void)testDataByTrimmingWhiteSpaces_textTabSpace
{
    NSString *testFormat = @"%@\t ";
    [self assertDataByTrimmingWhiteSpacesFromTestStringUsedInFormat:testFormat];
}

- (void)testDataByTrimmingWhiteSpaces_spaceTabText
{
    NSString *testFormat = @" \t%@";
    [self assertDataByTrimmingWhiteSpacesFromTestStringUsedInFormat:testFormat];
}

- (void)testDataByTrimmingWhiteSpaces_tabSpaceText
{
    NSString *testFormat = @"\t %@";
    [self assertDataByTrimmingWhiteSpacesFromTestStringUsedInFormat:testFormat];
}

#pragma mark helper

- (void)assertDataByTrimmingWhiteSpacesFromTestStringUsedInFormat:(NSString *)format
{
    NSString *testee = [NSString stringWithFormat:format, text];
    NSString *expected = text;
    [self assertDataByTrimmingWhiteSpacesWithSource:testee expectedResult:expected];
}

- (void)assertDataByTrimmingWhiteSpacesWithSource:(NSString *)source
                                   expectedResult:(NSString *)exp
{
    NSData *srcData = [source dataUsingEncoding:NSUTF8StringEncoding];
    NSData *expData = [exp dataUsingEncoding:NSUTF8StringEncoding];
    NSData *testee = [srcData dataByTrimmingWhiteSpaces];
    XCTAssertEqualObjects(testee, expData);
}

#pragma mark -

@end
