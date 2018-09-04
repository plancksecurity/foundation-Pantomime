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

// MARK: - Rf2231 Parameter Value Continuations, Charset & Language

//commented to fix with IOS-1303
//- (void)testRf2231_noContinuation_noCharset_noLanguage_nonSemicolonSeperated_noQuotes {
//    self.contentName = @"yes please!";
//    NSString *rfc2231Exapmle =
//    @"Content-Type: image/jpeg\nfilename=yes please!\n";
//    NSString *testee = rfc2231Exapmle;
//    [self assertFileNameCanBeParsedWithLine: testee mustSucceed:YES];
//}

- (void)testRf2231_noContinuation_noCharset_noLanguage_semicolonSeperated_noQuotes {
    self.contentName = @"yes please!";
    NSString *rfc2231Exapmle =
    @"Content-Type: image/jpeg\nfilename=yes please!;\n";
    NSString *testee = rfc2231Exapmle;
    [self assertFileNameCanBeParsedWithLine: testee mustSucceed:YES];
}

- (void)testRf2231_continuation_charset_language_semicolonSeperated_noQuotes {
    self.contentName = @"This is even more ***fun*** isn't it!";
    NSString *rfc2231Exapmle =
    @"Content-Type: image/jpeg\nfilename*0*=us-ascii'en'This%20is%20even%20more%20;\nfilename*1*=%2A%2A%2Afun%2A%2A%2A%20;\nfilename*2=isn't it!";
    NSString *testee = rfc2231Exapmle;
    [self assertFileNameCanBeParsedWithLine: testee mustSucceed:YES];
}

//commented to fix with IOS-1304
//- (void)testRf2231_continuation_charset_language_semicolonSeperated_quotes {
//    self.contentName = @"This is even more ***fun*** isn't it!";
//    NSString *rfc2231Exapmle =
//    @"Content-Type: image/jpeg;\nfilename*0*=us-ascii'en'This%20is%20even%20more%20;\nfilename*1*=%2A%2A%2Afun%2A%2A%2A%20;\nfilename*2=\"isn't it!\"";
//    NSString *testee = rfc2231Exapmle;
//    [self assertFileNameCanBeParsedWithLine: testee mustSucceed:YES];
//}
//
//- (void)testRf2231_continuation_charset_language_NonSemicolonSeperated_quotes {
//    self.contentName = @"This is even more ***fun*** isn't it!";
//    NSString *rfc2231Exapmle =
//    @"Content-Type: image/jpeg\nfilename*0*=us-ascii'en'This%20is%20even%20more%20\nfilename*1*=%2A%2A%2Afun%2A%2A%2A%20\nfilename*2=\"isn't it!\"";
//    NSString *testee = rfc2231Exapmle;
//    [self assertFileNameCanBeParsedWithLine: testee mustSucceed:YES];
//}
// fix with IOS-1304 ^^^^^^

- (void)testRf2231_noContinuation_charset_language {
    self.contentName = @"This is ***fun***";
    NSString *rfc2231Exapmle =
    @"Content-Type: image/jpeg;\nfilename*=us-ascii'en-us'This%20is%20%2A%2A%2Afun%2A%2A%2A";
    NSString *testee = rfc2231Exapmle;
    [self assertFileNameCanBeParsedWithLine: testee mustSucceed:YES];
}

- (void)testRf2231_noContinuation_charset_language_shouldFail {
    self.contentName = @"Wrong is ***fun***";
    NSString *rfc2231Exapmle =
    @"Content-Type: image/jpeg;\nfilename*=us-ascii'en-us'This%20is%20%2A%2A%2Afun%2A%2A%2A";
    NSString *testee = rfc2231Exapmle;
    [self assertFileNameCanBeParsedWithLine: testee mustSucceed:NO];
}

//IOS-1113: filename parsing crashes
/*
 Content-Disposition: inline;
 filename*0*=utf-8''%6D%61%69%6C%69%6E%67%61%73%73%65%74%73%5F%36%31%32;
 filename*1*=%34%62%37%37%62%66%61%65%36%36%35%39%37%64%64%65%62;
 filename*2*=%65%62%33%35%38%34%63%32%30%31%39%31%30%64%61%34%64;
 filename*3*=%61%34%38%2E%6A%70%67*/
- (void)testRf2231_continuation_charset_noLanguage_filename_parsable {
    self.contentName = @"mailingassets_6124b77bfae66597ddebeb3584c201910da4da48.jpg";
    NSString *ios1113ProblemInput = @"Content-Type: image/jpeg\nContent-Transfer-Encoding: base64\nContent-ID: <FWMAIL39a6e3f936f1e13bb6ef62ea36e639f2>\nContent-Disposition: inline;\nfilename*0*=utf-8''%6D%61%69%6C%69%6E%67%61%73%73%65%74%73%5F%36%31%32;\nfilename*1*=%34%62%37%37%62%66%61%65%36%36%35%39%37%64%64%65%62;\nfilename*2*=%65%62%33%35%38%34%63%32%30%31%39%31%30%64%61%34%64;\nfilename*3*=%61%34%38%2E%6A%70%67";
    NSString *testee = ios1113ProblemInput;
    /*[NSString stringWithFormat:@"Content-Type: %@;\ntitle*=us-ascii'en-us'%@",
                        self.contentType,
                        quoted];
     */
    [self assertFileNameCanBeParsedWithLine: testee mustSucceed:YES];
}

#pragma mark Helper

- (void)assertContentTypeCanBeParsedWithLine:(NSString *)line
{
    CWPart *part = [CWPart new];
    NSData *lineData = [line dataUsingEncoding:NSUTF8StringEncoding];
    [CWParser parseContentType:lineData inPart:part];
    XCTAssertEqualObjects(part.contentType, self.contentType);
    XCTAssertEqualObjects(part.filename, [self.contentName unquoted]);
    XCTAssertEqualObjects(part.charset, [self.charset unquoted]);
    XCTAssertTrue(part.format == self.format);
}

- (void)assertFileNameCanBeParsedWithLine:(NSString *)line mustSucceed:(BOOL)mustSucceed
{
    NSLog(@"Testing line: %@", line);
    CWPart *part = [CWPart new];
    NSData *lineData = [line dataUsingEncoding:NSUTF8StringEncoding];
    [CWParser parseContentDisposition:lineData inPart:part];
    if (mustSucceed) {
        XCTAssertEqualObjects(part.filename, [self.contentName unquoted]);
    } else {
        XCTAssertNotEqualObjects(part.filename, [self.contentName unquoted]);
    }
}

@end
