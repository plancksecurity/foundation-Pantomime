//
//  CWParserTest.m
//  PantomimeTests
//
//  Created by Andreas Buff on 14.12.17.
//  Copyright © 2017 pEp Security S.A. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "CWParser.h"
#import "CWPart.h"
#import "NSString+PantomimeTestHelper.h"

@interface CWParserTest : XCTestCase
@property (strong, nonatomic) NSString *contentType;
@property (strong, nonatomic) NSString *contentName;
@property (strong, nonatomic) NSString *charset;
@property PantomimeMessageFormat format;
@end

@implementation CWParserTest

#pragma mark - parseContentType

#pragma mark One Parameter

// Different Valid Versions of: "Content-Type: application/octet-stream; name="msg.asc""

- (void)testParseContentType_nameQuoted_nonTerminated {
    self.contentType = @"application/octet-stream";
    self.contentName = @"\"msg.asc\"";
    NSString *testee = [NSString stringWithFormat:@"Content-Type: %@; name=%@",
                        self.contentType, self.contentName];
    [self assertContentTypeCanBeParsedWithLine: testee];
}

- (void)testParseContentType_nameNotQuoted_nonTerminated {
    self.contentType = @"application/octet-stream";
    self.contentName = @"msg.asc";
    NSString *testee = [NSString stringWithFormat:@"Content-Type: %@; name=%@",
                        self. contentType, self.contentName];
    [self assertContentTypeCanBeParsedWithLine: testee];
}

- (void)testParseContentType_nameQuoted_terminated {
    self.contentType = @"application/octet-stream";
    self.contentName = @"\"msg.asc\"";
    NSString *testee = [NSString stringWithFormat:@"Content-Type: %@; name=%@;",
                        self.contentType, self.contentName];
    [self assertContentTypeCanBeParsedWithLine: testee];
}

- (void)testParseContentType_nameNotQuoted_terminated {
    self.contentType = @"application/octet-stream";
    self.contentName = @"msg.asc";
    NSString *testee = [NSString stringWithFormat:@"Content-Type: %@; name=%@;",
                        self.contentType, self.contentName];
    [self assertContentTypeCanBeParsedWithLine: testee];
}

#pragma mark Two Parameters

/*
 A line where "name=" is not the last parameter
 "Content-Type: text/x-patch; name=mpg321-format-string.diff; charset=ISO-8859-1"
 Assumed causing IOS-880
 */
- (void)testParseContentType_nameNotLastParameter {
    self.contentType = @"text/x-patch";
    self.contentName = @"mpg321-format-string.diff";
    self.charset = @"ISO-8859-1";
    NSString *testee = [NSString stringWithFormat:@"Content-Type: %@; name=%@; charset=%@",
                        self.contentType, self.contentName, self.charset];
    [self assertContentTypeCanBeParsedWithLine: testee];
}

- (void)testParseContentType_nameNotLastParameter_terminated {
    self.contentType = @"text/x-patch";
    self.contentName = @"mpg321-format-string.diff";
    self.charset = @"ISO-8859-1";
    NSString *testee = [NSString stringWithFormat:@"Content-Type: %@; name=%@; charset=%@;",
                        self.contentType, self.contentName, self.charset];
    [self assertContentTypeCanBeParsedWithLine: testee];
}

/*
 A line where "charset=" is not the last parameter
 "Content-Type: text/x-patch; charset=ISO-8859-1; name=mpg321-format-string.diff"
 Assumed causing IOS-880
 */
- (void)testParseContentType_charsetNotLastParameter {
    self.contentType = @"text/x-patch";
    self.contentName = @"mpg321-format-string.diff";
    self.charset = @"ISO-8859-1";
    NSString *testee = [NSString stringWithFormat:@"Content-Type: %@; charset=%@; name=%@",
                        self.contentType, self.charset, self.contentName];
    [self assertContentTypeCanBeParsedWithLine: testee];
}

#pragma mark "format=" Parameter

/*
 A line with "format" parameter
 "Content-Type: text/plain; charset=us-ascii; format=flowed"
 */
- (void)testParseContentType_format {
    self.contentType = @"text/x-patch";
    NSString *formatString = @"flowed";
    self.format = PantomimeFormatFlowed;
    self.charset = @"ISO-8859-1";
    NSString *testee = [NSString stringWithFormat:@"Content-Type: %@; charset=%@; format=%@",
                        self.contentType, self.charset, formatString];
    [self assertContentTypeCanBeParsedWithLine: testee];
}

- (void)testParseContentType_format_terminated {
    self.contentType = @"text/x-patch";
    NSString *formatString = @"flowed";
    self.format = PantomimeFormatFlowed;
    self.charset = @"ISO-8859-1";
    NSString *testee = [NSString stringWithFormat:@"Content-Type: %@; charset=%@; format=%@;",
                        self.contentType, self.charset, formatString];
    [self assertContentTypeCanBeParsedWithLine: testee];
}

/*
 A line with "format" parameter where "format=" is not the last parameter
 "Content-Type: text/plain; format=flowed; charset=us-ascii"
 */
- (void)testParseContentType_format_notLastParameter {
    self.contentType = @"text/x-patch";
    NSString *formatString = @"flowed";
    self.format = PantomimeFormatFlowed;
    self.charset = @"ISO-8859-1";
    NSString *testee = [NSString stringWithFormat:@"Content-Type: %@; format=%@; charset=%@",
                        self.contentType, formatString, self.charset];
    [self assertContentTypeCanBeParsedWithLine: testee];
}

- (void)testParseContentType_format_notLastParameter_terminated {
    self.contentType = @"text/x-patch";
    NSString *formatString = @"flowed";
    self.format = PantomimeFormatFlowed;
    self.charset = @"ISO-8859-1";
    NSString *testee = [NSString stringWithFormat:@"Content-Type: %@; format=%@; charset=%@;",
                        self.contentType, formatString, self.charset];
    [self assertContentTypeCanBeParsedWithLine: testee];
}

/*
 A line with "format" parameter, while "format" is also a substring of the line.
 " Content-Type: text/plain; charset=us-ascii; name=mpg321-format-string.diff, format=flowed"
 */
- (void)testParseContentType_format_alsoAsSubstring {
    self.contentType = @"text/x-patch";
    self.contentName = @"mpg321-format-string.diff";
    self.charset = @"ISO-8859-1";
    NSString *formatString = @"flowed";
    self.format = PantomimeFormatFlowed;

    NSString *testee = [NSString stringWithFormat:@"Content-Type: %@; charset=%@; name=%@; format=%@",
                        self.contentType, self.charset, self.contentName, formatString];
    [self assertContentTypeCanBeParsedWithLine: testee];
}

- (void)testParseContentType_format_alsoAsSubstring_terminated {
    self.contentType = @"text/x-patch";
    self.contentName = @"mpg321-format-string.diff";
    self.charset = @"ISO-8859-1";
    NSString *formatString = @"flowed";
    self.format = PantomimeFormatFlowed;

    NSString *testee = [NSString stringWithFormat:@"Content-Type: %@; charset=%@; name=%@; format=%@;",
                        self.contentType, self.charset, self.contentName, formatString];
    [self assertContentTypeCanBeParsedWithLine: testee];
}

/*
 A line with "format" parameter, while "format" is also a substring of the line and "format="
 is not the last parameter.
 " Content-Type: text/plain; charset=us-ascii; format=flowed; name=mpg321-format-string.diff"
 */
- (void)testParseContentType_format_alsoAsSubstring_notLastParameter {
    self.contentType = @"text/x-patch";
    self.contentName = @"mpg321-format-string.diff";
    self.charset = @"ISO-8859-1";
    NSString *formatString = @"flowed";
    self.format = PantomimeFormatFlowed;

    NSString *testee = [NSString stringWithFormat:@"Content-Type: %@; charset=%@; format=%@; name=%@",
                        self.contentType, self.charset, formatString, self.contentName];
    [self assertContentTypeCanBeParsedWithLine: testee];
}

- (void)testParseContentType_format_alsoAsSubstring_notLastParameter_terminated {
    self.contentType = @"text/x-patch";
    self.contentName = @"mpg321-format-string.diff";
    self.charset = @"ISO-8859-1";
    NSString *formatString = @"flowed";
    self.format = PantomimeFormatFlowed;

    NSString *testee = [NSString stringWithFormat:@"Content-Type: %@; charset=%@; format=%@; name=%@;",
                        self.contentType, self.charset, formatString, self.contentName];
    [self assertContentTypeCanBeParsedWithLine: testee];
}

#pragma mark - HELPER

- (void)assertContentTypeCanBeParsedWithLine:(NSString *)line
{
    NSLog(@"Testing line: %@", line);
    CWPart *part = [CWPart new];
    NSData *lineData = [line dataUsingEncoding:NSUTF8StringEncoding];
    [CWParser parseContentType:lineData inPart:part];
    XCTAssertEqualObjects(part.contentType, self.contentType);
    XCTAssertEqualObjects(part.filename, [self.contentName unquoted]);
    XCTAssertEqualObjects(part.charset, [self.charset unquoted]);
    XCTAssertTrue(part.format == self.format);
}

@end
