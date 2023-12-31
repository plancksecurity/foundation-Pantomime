/*
 **  CWPart.m
 **
 **  Copyright (c) 2001-2007
 **
 **  Author: Ludovic Marcotte <ludovic@Sophos.ca>
 **
 **  This library is free software; you can redistribute it and/or
 **  modify it under the terms of the GNU Lesser General Public
 **  License as published by the Free Software Foundation; either
 **  version 2.1 of the License, or (at your option) any later version.
 **
 **  This library is distributed in the hope that it will be useful,
 **  but WITHOUT ANY WARRANTY; without even the implied warranty of
 **  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 **  Lesser General Public License for more details.
 **
 **  You should have received a copy of the GNU Lesser General Public
 **  License along with this library; if not, write to the Free Software
 **  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
 */

#import "CWPart.h"

#import "CWConstants.h"
#import <PantomimeFramework/CWMessage.h>
#import "CWMIMEMultipart.h"
#import "CWMIMEUtility.h"
#import "NSData+Extensions.h"
#import "Pantomime/NSString+Extensions.h"
#import "Pantomime/CWParser.h"
#import "CWFlags.h"
#import "CWIMAPMessage.h"

#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSException.h>
#import <Foundation/NSValue.h>

#import <string.h>

#define LF "\n"

static int currentPartVersion = 2;

//
//
//
@implementation CWPart

- (id) init
{
    self = [super init];

    [CWPart setVersion: currentPartVersion];

    // We initialize our dictionary that will hold all our headers with a capacity of 25.
    // This is an empirical number that is used to speedup the addition of headers w/o
    // reallocating our array everytime we add a new element.
    _headers = [[NSMutableDictionary alloc] initWithCapacity: 25];
    _parameters = [[NSMutableDictionary alloc] init];
    _line_length = _size = 0;
    _content = nil;

    return self;
}


//
//
//
- (void) dealloc
{
    RELEASE(_defaultCharset);
    RELEASE(_parameters);
    RELEASE(_headers);
    RELEASE(_content);

    //[super dealloc];
}


//
//
//
- (id) initWithData: (NSData *) theData
{
    NSRange aRange;

    aRange = [theData rangeOfCString: "\n\n"];

    if (aRange.length == 0)
    {
        AUTORELEASE_VOID(self);
        return nil;
    }

    // We initialize our message with the headers and the content
    self = [self init];

    [CWPart setVersion: currentPartVersion];

    // We verify if we have an empty body part content like:
    // X-UID: 5dc5aa4b82240000
    //
    // This is a MIME Message
    //
    // ------=_NextPart_000_007F_01BDF6C7.FABAC1B0
    //
    //
    // ------=_NextPart_000_007F_01BDF6C7.FABAC1B0
    // Content-Type: text/html; name="7english.co.kr.htm"
    if ([theData length] == 2)
    {
        [self setContent: [NSData data]];
        return self;
    }

    [self setHeadersFromData:[theData subdataWithRange:NSMakeRange(0,aRange.location)]];
    [CWMIMEUtility setContentFromRawSource:
     [theData subdataWithRange:NSMakeRange(aRange.location + 2,
                                           [theData length]-(aRange.location+2))] inPart: self];

    return self;
}


//
//
//
- (id) initWithData: (NSData *) theData
            charset: (NSString *) theCharset
{
    [CWPart setVersion: currentPartVersion];

    [self setDefaultCharset: theCharset];

    return [self initWithData: theData];
}


//
// NSCoding protocol
//
- (void) encodeWithCoder: (NSCoder *) theCoder
{
    [CWPart setVersion: currentPartVersion];

    [theCoder encodeObject: [self contentType]];
    [theCoder encodeObject: [self contentID]];
    [theCoder encodeObject: [self contentDescription]];
    [theCoder encodeObject: [NSNumber numberWithInt: [self contentDisposition]]];
    [theCoder encodeObject: [self filename]];

    [theCoder encodeObject: [NSNumber numberWithInteger: [self contentTransferEncoding]]];
    [theCoder encodeObject: [NSNumber numberWithInteger: [self format]]];
    [theCoder encodeObject: [NSNumber numberWithInteger: _size]];

    [theCoder encodeObject: [self boundary]];
    [theCoder encodeObject: [self charset]];
    [theCoder encodeObject: _defaultCharset];
}


- (id) initWithCoder: (NSCoder *) theCoder
{
    self = [super init];

    _headers = [[NSMutableDictionary alloc] initWithCapacity: 25];
    _parameters = [[NSMutableDictionary alloc] init];

    [self setContentType: [theCoder decodeObject]];
    [self setContentID: [theCoder decodeObject]];
    [self setContentDescription: [theCoder decodeObject]];
    [self setContentDisposition: [[theCoder decodeObject] intValue]];
    [self setFilename: [theCoder decodeObject]];

    [self setContentTransferEncoding: [[theCoder decodeObject] intValue]];
    [self setFormat: [[theCoder decodeObject] intValue]];
    [self setSize: [[theCoder decodeObject] intValue]];

    [self setBoundary: [theCoder decodeObject]];
    [self setCharset: [theCoder decodeObject]];
    [self setDefaultCharset: [theCoder decodeObject]];

    _content = nil;

    return self;
}


//
// access / mutation methods
//
- (NSObject *) content
{
    return _content;
}


//
//
//
- (void) setContent: (NSObject *) theContent
{
    if (theContent && !([theContent isKindOfClass: [NSData class]] ||
                        [theContent isKindOfClass: [CWMessage class]] ||
                        [theContent isKindOfClass: [CWMIMEMultipart class]]))
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"Invalid argument to CWPart: -setContent:  The content MUST be either a NSData, CWMessage or CWMIMEMessage instance."];
    }

    ASSIGN(_content, theContent);
}

//
//
//
- (NSString *) contentType
{
    return [_headers objectForKey: @"Content-Type"];
}

- (void) setContentType: (NSString*) theContentType
{
    if (theContentType)
    {
        [_headers setObject: theContentType  forKey: @"Content-Type"];
    }
}

//
//
//
- (NSString *) contentID
{
    return [_headers objectForKey: @"Content-Id"];
}        

- (void) setContentID: (NSString *) theContentID
{ 
    if (theContentID)
    {
        [_headers setObject: theContentID  forKey: @"Content-Id"];
    }
}

//
//
//
- (NSString *) contentDescription
{
    return [_headers objectForKey: @"Content-Description"];
}

- (void) setContentDescription: (NSString *) theContentDescription
{
    if (theContentDescription)
    {
        [_headers setObject: theContentDescription  forKey: @"Content-Description"];
    }
}


//
//
//
- (PantomimeContentDisposition) contentDisposition
{
    id o;

    o = [_headers objectForKey: @"Content-Disposition"];

    return (o ? [o intValue] : PantomimeAttachmentDisposition);
}

- (void) setContentDisposition: (PantomimeContentDisposition) theContentDisposition
{
    [_headers setObject: [NSNumber numberWithInt: theContentDisposition]  forKey: @"Content-Disposition"];
}


//
//
//
- (PantomimeEncoding) contentTransferEncoding
{
    id o;

    o = [_headers objectForKey: @"Content-Transfer-Encoding"];

    if (o)
    {
        return [o intValue];
    }

    // Default value for the Content-Transfer-Encoding.
    // See RFC2045 - 6.1. Content-Transfer-Encoding Syntax.
    return PantomimeEncodingNone;
}

- (void) setContentTransferEncoding: (PantomimeEncoding) theEncoding
{
    [_headers setObject: [NSNumber numberWithInt: theEncoding]  forKey: @"Content-Transfer-Encoding"];
}

- (NSString *)filename
{
    return [_parameters objectForKey: @"filename"];
}

- (void)setFilename:(NSString *)theFilename
{
    if (theFilename && ([theFilename length] > 0)) {
        [_parameters setObject: theFilename  forKey: @"filename"];
    } else {
        [_parameters setObject: @"unknown"  forKey: @"filename"];
    }
}


//
//
//
- (PantomimeMessageFormat) format
{
    id o;

    o = [_parameters objectForKey: @"format"];

    if (o)
    {
        return [o intValue];
    }

    return PantomimeFormatUnknown;
}

- (void) setFormat: (PantomimeMessageFormat) theFormat
{
    [_parameters setObject: [NSNumber numberWithInt: theFormat]  forKey: @"format"];
}


//
//
//
- (NSUInteger) lineLength
{
    return _line_length;
}

- (void) setLineLength: (int) theLineLength
{
    _line_length = theLineLength;
}


//
// This method is used to very if the part is of the following primaryType / subType
//
- (BOOL) isMIMEType: (NSString *) thePrimaryType
            subType: (NSString *) theSubType
{
    NSString *aString;

    if (![self contentType])
    {
        return NO;//[self setContentType: @"text/plain"];
    }

    if ([theSubType compare: @"*"] == NSOrderedSame)
    {
        if ([[self contentType] hasCaseInsensitivePrefix: thePrimaryType])
        {
            return YES;
        }
    }
    else
    {
        aString = [NSString stringWithFormat: @"%@/%@", thePrimaryType, theSubType];

        if ([aString caseInsensitiveCompare: [self contentType]] == NSOrderedSame)
        {
            return YES;
        }
    }

    return NO;
}


//
//
//
- (long) size
{
    return _size;
}

- (void) setSize: (NSInteger) theSize
{
    _size = theSize;
}

- (NSData *)dataValue
{
    NSMutableData *dataValue = [[NSMutableData alloc] init];

    // We start off by exactring the filename of the part.
    NSString *filename;
    if ([[self filename] is7bitSafe]) {
        filename = [self filename];
    } else {
        filename = [[NSString alloc] initWithData: [CWMIMEUtility encodeWordUsingQuotedPrintable: [self filename]
                                                                                    prefixLength: 0]
                                         encoding: NSASCIIStringEncoding];
    }

    // We encode our Content-Transfer-Encoding header.
    if ([self contentTransferEncoding] != PantomimeEncodingNone) {
        [dataValue appendCFormat: @"Content-Transfer-Encoding: %@%s",
         [NSString stringValueOfTransferEncoding: [self contentTransferEncoding]],
         LF];
    }

    // We encode our Content-ID header.
    if ([self contentID]) {
        [dataValue appendCFormat: @"Content-ID: %@%s", [self contentID], LF];
    }

    // We encode our Content-Description header.
    if ([self contentDescription]) {
        [dataValue appendCString: "Content-Description: "];
        [dataValue appendData: [CWMIMEUtility encodeWordUsingQuotedPrintable: [self contentDescription]
                                                                prefixLength: 21]];
        [dataValue appendCString: LF];
    }

    // We now encode the Content-Type header with its parameters.
    [dataValue appendCFormat: @"Content-Type: %@", [self contentType]];

    if ([self charset]) {
        [dataValue appendCFormat: @"; charset=\"%@\"", [self charset]];
    } else {
        // Charset unknown, default to UTF-8
        [dataValue appendCFormat: @"; charset=\"%@\"", @"UTF-8"];
    }
    if ([self format] == PantomimeFormatFlowed &&
        ([self contentTransferEncoding] == PantomimeEncodingNone || [self contentTransferEncoding] == PantomimeEncoding8bit)) {
        [dataValue appendCString: "; format=\"flowed\""];
    }
    if (filename && [filename length]) {
        [dataValue appendCFormat: @"; name=\"%@\"", filename];
    }

    // Before checking for all other parameters, we check for the boundary one
    // If we got a CWMIMEMultipart instance as the content but no boundary
    // was set, we create a boundary and we set it.
    if ([self boundary] || [_content isKindOfClass: [CWMIMEMultipart class]]) {
        if (![self boundary]) {
            [self setBoundary: [CWMIMEUtility globallyUniqueBoundary]];
        }
        [dataValue appendCFormat: @";%s\tboundary=\"",LF];
        [dataValue appendData: [self boundary]];
        [dataValue appendCString: "\""];
    }

    // We now check for any other additional parameters. If we have some,
    // we add them one per line. We first REMOVE what we have added! We'll
    // likely and protocol= here.
    NSMutableArray *allKeys = [NSMutableArray arrayWithArray: [_parameters allKeys]];
    [allKeys removeObject: @"boundary"];
    [allKeys removeObject: @"charset"];
    [allKeys removeObject: @"filename"];
    [allKeys removeObject: @"format"];

    for (int i = 0; i < [allKeys count]; i++) {
        [dataValue appendCFormat: @";%s", LF];
        [dataValue appendCFormat: @"\t%@=\"%@\"", [allKeys objectAtIndex: i], [_parameters objectForKey: [allKeys objectAtIndex: i]]];
    }

    [dataValue appendCString: LF];

    // We encode our Content-Disposition header. We ignore other parameters
    // (other than the filename one) since they are pretty much worthless.
    // See RFC2183 for details.
    PantomimeContentDisposition disposition = [self contentDisposition];
    if (disposition == PantomimeAttachmentDisposition ||
        disposition == PantomimeInlineDisposition) {
        if (disposition == PantomimeAttachmentDisposition) {
            [dataValue appendCString: "Content-Disposition: attachment"];
        } else {
            [dataValue appendCString: "Content-Disposition: inline"];
        }

        if (filename && [filename length]) {
            [dataValue appendCFormat: @"; filename=\"%@\"", filename];
        }

        [dataValue appendCString: LF];
    }

    NSData *dataToSend;
    if ([_content isKindOfClass: [CWMessage class]]) {
        dataToSend = [(CWMessage *)_content rawSource];
    } else if ([_content isKindOfClass: [CWMIMEMultipart class]]) {
        CWMIMEMultipart *aMimeMultipart;
        NSMutableData *md;
        CWPart *aPart;

        md = [[NSMutableData alloc] init];
        aMimeMultipart = (CWMIMEMultipart *)_content;
        NSUInteger count = [aMimeMultipart count];

        for (int i = 0; i < count; i++) {
            aPart = [aMimeMultipart partAtIndex: i];
            if (i > 0) {
                [md appendBytes: LF  length: strlen(LF)];
            }
            [md appendBytes: "--"  length: 2];
            [md appendData: [self boundary]];
            [md appendBytes: LF  length: strlen(LF)];
            [md appendData: [aPart dataValue]];
        }
        [md appendBytes: "--"  length: 2];
        [md appendData: [self boundary]];
        [md appendBytes: "--"  length: 2];
        [md appendBytes: LF  length: strlen(LF)];

        dataToSend = md;
    } else {
        dataToSend = (NSData *)_content;
    }

    // We separe our part's headers from the content
    [dataValue appendCFormat: @"%s", LF];

    // We now encode our content the way it was specified
    if ([self contentTransferEncoding] == PantomimeEncodingQuotedPrintable) {
        dataToSend = [dataToSend encodeQuotedPrintableWithLineLength: 72  inHeader: NO];
    } else if ([self contentTransferEncoding] == PantomimeEncodingBase64) {
        dataToSend = [dataToSend encodeBase64WithLineLength: 72];
    } else if (([self contentTransferEncoding] == PantomimeEncodingNone || [self contentTransferEncoding] == PantomimeEncoding8bit) &&
               [self format] == PantomimeFormatFlowed) {
        NSUInteger limit = _line_length;
        if (limit < 2 || limit > 998) {
            limit = 72;
        }
        dataToSend = [dataToSend wrapWithLimit: limit];
    }

    [dataToSend enumerateComponentsSeperatedByString:"\n"
                                               block:^(NSData *aLine, NSUInteger count, BOOL isLast) {
        if (isLast && [aLine length] == 0) {
            return;
        }
        [dataValue appendData:aLine];
        [dataValue appendBytes:LF length:1];
    }];

    return dataValue;
}


//
//
//
- (NSData *) boundary
{
    return [_parameters objectForKey: @"boundary"];
}

- (void) setBoundary: (NSData *) theBoundary
{
    if (theBoundary)
    {
        [_parameters setObject: theBoundary  forKey: @"boundary"];
    }
}


//
//
//
- (NSData *) protocol
{
    return [_parameters objectForKey: @"protocol"];
    //return _protocol;
}

- (void) setProtocol: (NSData *) theProtocol
{
    //ASSIGN(_protocol, theProtocol);
    if (theProtocol)
    {
        [_parameters setObject: theProtocol  forKey: @"protocol"];
    }
}


//
//
//
- (NSString *) charset
{
    return [_parameters objectForKey: @"charset"];
}

- (void) setCharset: (NSString *) theCharset
{
    if (theCharset)
    {
        [_parameters setObject: theCharset  forKey: @"charset"];
    }
}


//
//
//
- (NSString *) defaultCharset
{
    return _defaultCharset;
}


//
//
//
- (void) setDefaultCharset: (NSString *) theCharset
{
    ASSIGN(_defaultCharset, theCharset);
}


//
//
//
- (void) setHeadersFromData: (NSData *) theHeaders
{
    //NSAutoreleasePool *pool;
    NSArray *allLines;
    NSUInteger i, count;

    if (!theHeaders || [theHeaders length] == 0)
    {
        return;
    }

    // We initialize a local autorelease pool
    @autoreleasepool {

        // We MUST be sure to unfold all headers properly before
        // decoding the headers
        theHeaders = [theHeaders unfoldLines];

        allLines = [theHeaders componentsSeparatedByCString: "\n"];
        count = [allLines count];

        for (i = 0; i < count; i++)
        {
            NSData *aLine = [allLines objectAtIndex: i];

            // We stop if we found the header separator. (\n\n) since someone could
            // have called this method with the entire rawsource of a message.
            if ([aLine length] == 0)
            {
                break;
            }

            if ([aLine hasCaseInsensitiveCPrefix: "Content-Description"])
            {
                [CWParser parseContentDescription: aLine  inPart: self];
            }
            else if ([aLine hasCaseInsensitiveCPrefix: "Content-Disposition"])
            {
                [CWParser parseContentDisposition: aLine  inPart: self];
            }
            else if ([aLine hasCaseInsensitiveCPrefix: "Content-ID"])
            {
                [CWParser parseContentID: aLine  inPart: self];
            }
            else if ([aLine hasCaseInsensitiveCPrefix: "Content-Length"])
            {
                // We just ignore that for now.
            }
            else if ([aLine hasCaseInsensitiveCPrefix: "Content-Transfer-Encoding"])
            {
                [CWParser parseContentTransferEncoding: aLine  inPart: self];
            }
            else if ([aLine hasCaseInsensitiveCPrefix: "Content-Type"])
            {
                [CWParser parseContentType: aLine  inPart: self];
            }
        }

    } //RELEASE(pool);
}


//
//
//
- (id) parameterForKey: (NSString *) theKey
{
    return [_parameters objectForKey: theKey];
}

- (void) setParameter: (NSString *) theParameter  forKey: (NSString *) theKey
{
    if (theParameter)
    {
        [_parameters setObject: theParameter  forKey: theKey];
    }
    else
    {
        [_parameters removeObjectForKey: theKey];
    }
}

//
//
//
- (NSDictionary *) allHeaders
{
    return _headers;
}

//
//
//
- (id) headerValueForName: (NSString *) theName
{
    NSArray *allKeys;
    NSUInteger count;

    allKeys = [_headers allKeys];
    count = [allKeys count];

    while (count--)
    {
        if ([[allKeys objectAtIndex: count] caseInsensitiveCompare: theName] == NSOrderedSame)
        {
            return [_headers objectForKey: [allKeys objectAtIndex: count]];
        }
    }

    return nil;
}

//
//
//
- (void) setHeaders: (NSDictionary *) theHeaders
{
    if (theHeaders)
    {
        [_headers addEntriesFromDictionary: theHeaders];
    }
    else
    {
        [_headers removeAllObjects];
    }
}

- (NSString *)description
{
    NSMutableString *str = [NSMutableString
                            stringWithFormat:@"<CWPart 0x%u Part %ld bytes",
                            (uint) self, self.size];
    if (self.contentType) {
        [str appendFormat:@", %@", self.contentType];
    }
    if (self.filename) {
        [str appendFormat:@", %@", self.filename];
    }
    if ([self isKindOfClass:[CWMessage class]]) {
        [str appendFormat:@" msn %lu", (unsigned long) [((CWIMAPMessage *) self) messageNumber]];
    }
    if ([self isKindOfClass:[CWIMAPMessage class]]) {
        [str appendFormat:@" messageID %@", [((CWIMAPMessage *) self) messageID]];
        [str appendFormat:@" uid %lu", (unsigned long) [((CWIMAPMessage *) self) UID]];

        CWFlags *flags = [((CWMessage *) self) flags];
        NSString *flagsString = [flags asString];
        if (flagsString.length == 0) {
            flagsString = @"NoFlags";
        }
        [str appendFormat:@" %@", flagsString];

        if (((CWMessage *) self).originationDate) {
            [str appendFormat:@" %@", ((CWMessage *) self).originationDate];
        }
    }
    [str appendString:@">"];
    return str;
}

@end
