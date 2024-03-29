/*
 **  CWParser.m
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

#import "Pantomime/CWParser.h"

#import <Foundation/Foundation.h>

#import <PlanckToolboxForExtensions/PEPLogger.h>

#import "CWConstants.h"
#import "CWFlags.h"
#import "CWInternetAddress.h"
#import <PantomimeFramework/CWMessage.h>
#import "CWMIMEUtility.h"
#import "NSMutableString+Extension.h"
#import "NSData+Extensions.h"
#import "NSData+CWParsingUtils.h"
#import "Pantomime/NSString+Extensions.h"

#import <stdlib.h>
#import <string.h>  // For NULL on OS X
#import <ctype.h>
#import <stdio.h>
//#import "Pantomime/elm_defs.h>

#import <Foundation/NSBundle.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>

//
//
//
static char *month_name[12] = {"jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"};

static struct _timezone {
    char *name;          /* time zone name */
    int offset;         /* offset, in minutes, EAST of GMT */
} timezone_info[] = {

    /* the following are from RFC-822 */
    { "ut", 0 },
    { "gmt", 0 },
    { "est", -5*3600 },   { "edt", -4*3600 },       /* USA eastern standard */
    { "cst", -6*3600 },   { "cdt", -5*3600 },       /* USA central standard */
    { "mst", -7*3600 },   { "mdt", -6*3600 },       /* USA mountain standard */
    { "pst", -8*3600 },   { "pdt", -7*3600 },       /* USA pacific standard */
    { "z", 0 }, /* zulu time (the rest of the military codes are bogus) */

    /* popular European timezones */
    { "wet", 0*3600 },                            /* western european */
    { "met", 1*3600 },                            /* middle european */
    { "eet", 2*3600 },                            /* eastern european */
    { "bst", 1*3600 },                            /* ??? british summer time */

    /* Canadian timezones */
    { "ast", -4*3600 },   { "adt", -3*3600 },       /* atlantic */
    { "nst", -3*1800 },{ "ndt", -2*1800 },          /* newfoundland */
    { "yst", -9*3600 },   { "ydt", -8*3600 },       /* yukon */
    { "hst", -10*3600 },                            /* hawaii (not really canada) */

    /* Asian timezones */
    { "jst", 9*3600 },                            /* japan */
    { "sst", 8*3600 },                            /* singapore */

    /* South-Pacific timezones */
    { "nzst", 12*3600 },  { "nzdt", 13*3600 },      /* new zealand */
    { "wst", 8*3600 },    { "wdt", 9*3600 },        /* western australia */

    /*
     * Daylight savings modifiers.  These are not real timezones.
     * They are used for things like "met dst".  The "met" timezone
     * is 1*3600, and applying the "dst" modifier makes it 2*3600.
     */
    { "dst", 1*3600 },
    { "dt", 1*3600 },
    { "st", 1*3600 }
};

//
//
//
NSInteger next_word(unsigned char *buf, NSUInteger start, NSUInteger len, unsigned char *word)
{
    unsigned char *p;
    NSUInteger i;

    for (p = buf+start, i = start; (isspace(*p) || *p == ','); ++p, ++i);

    if (start >= len) return -1;

    while (i < len && !(isspace(*p) || *p == ','))
    {
        *word++ = *p++;
        i++;
    }

    *word = '\0';

    return p-buf-start;
}

// MARK: - private interface

@interface CWParser (Private)
+ (id)_parameterValueUsingLine:(NSData *)theLine
                         range:(NSRange)theRange
                        decode:(BOOL)decode
                       charset:(NSString *)theCharset;
@end


//
//
//
@implementation CWParser

+ (void) parseContentDescription: (NSData *) theLine
                          inPart: (CWPart *) thePart
{
    NSData *aData;

    aData = [[theLine subdataFromIndex: 20] dataByTrimmingWhiteSpaces];

    if (aData && [aData length])
    {
        [thePart setContentDescription: [[aData dataFromQuotedData] asciiString] ];
    }
}


//
//
//
+ (void)parseContentDisposition:(NSData *)theLine
                         inPart: (CWPart *)thePart;
{
    NSInteger keyLength = @"Content-Disposition: ".length;
    if ([theLine length] > keyLength) {
        NSData *aData = [theLine subdataFromIndex: keyLength];

        NSRange aRange = [aData firstSemicolonOrNewlineInRange:NSMakeRange(0, aData.length)];
        if (aRange.location != NSNotFound) {
            // We set the content disposition to this part
            [thePart setContentDisposition:
             ([[[aData subdataWithRange: NSMakeRange(0, aRange.location)] asciiString] caseInsensitiveCompare:@"inline"] == NSOrderedSame ?
              PantomimeInlineDisposition :
              PantomimeAttachmentDisposition)];
            // We now decode our filename
            NSRange filenameRange = [aData rangeOfCString: "filename"];
            if (filenameRange.location != NSNotFound) {
                [thePart setFilename: [CWParser _parameterValueUsingLine: aData
                                                                   range: filenameRange
                                                                  decode: YES
                                                                 charset: [thePart defaultCharset]]];
            }
        } else {
            [thePart setContentDisposition:
             ([[[aData dataByTrimmingWhiteSpaces] asciiString] caseInsensitiveCompare: @"inline"] == NSOrderedSame ?
              PantomimeInlineDisposition :
              PantomimeAttachmentDisposition)];
        }
    } else {
        [thePart setContentDisposition: PantomimeAttachmentDisposition];
    }
}

//
//
//
+ (void) parseContentID: (NSData *) theLine
                 inPart: (CWPart *) thePart
{
    if ([theLine length] > 12)
    {
        NSData *aData;

        aData = [theLine subdataFromIndex: 12];

        if ([aData hasCPrefix: "<"] && [aData hasCSuffix: ">"])
        {
            [thePart setContentID: [[aData subdataWithRange: NSMakeRange(1, [aData length]-2)] asciiString]];
        }
        else
        {
            [thePart setContentID: [aData asciiString]];
        }
    }
    else
    {
        [thePart setContentID: @""];
    }
}


//
//
//
+ (void) parseContentTransferEncoding: (NSData *) theLine
                               inPart: (CWPart *) thePart
{
    if ([theLine length] > 26)
    {
        NSData *aData;

        aData = [[theLine subdataFromIndex: 26] dataByTrimmingWhiteSpaces];

        if ([aData caseInsensitiveCCompare: "quoted-printable"] == NSOrderedSame)
        {
            [thePart setContentTransferEncoding: PantomimeEncodingQuotedPrintable];
        }
        else if ([aData caseInsensitiveCCompare: "base64"] == NSOrderedSame)
        {
            [thePart setContentTransferEncoding: PantomimeEncodingBase64];
        }
        else if ([aData caseInsensitiveCCompare: "8bit"] == NSOrderedSame)
        {
            [thePart setContentTransferEncoding: PantomimeEncoding8bit];
        }
        else if ([aData caseInsensitiveCCompare: "binary"] == NSOrderedSame)
        {
            [thePart setContentTransferEncoding: PantomimeEncodingBinary];
        }
        else
        {
            [thePart setContentTransferEncoding: PantomimeEncodingNone];
        }
    }
    else
    {
        [thePart setContentTransferEncoding: PantomimeEncodingNone];
    }
}

/**
 Shrinks any valid range by one in length.
 A valid range is one with a valid position (not NSNotFound) and a length > 0.
 */
NSRange shrinkRange(NSRange range)
{
    if (range.location != NSNotFound && range.location != NSNotFound) {
        return NSMakeRange(range.location, range.length - 1);
    } else {
        return range;
    }
}

//
//
//
+ (void) parseContentType: (NSData *) theLine
                   inPart: (CWPart *) thePart
{
    NSRange aRange;
    NSData *aData;
    NSInteger x;

    if ([theLine length] <= 14)
    {
        [thePart setContentType: @"text/plain"];
        return;
    }

    aData = [[theLine subdataFromIndex: 13] dataByTrimmingWhiteSpaces];

    // We first skip the parameters, if we need to
    x = [aData indexOfCharacter: ';'];
    if (x > 0)
    {
        aData = [aData subdataToIndex: x];
    }

    // We see if there's a subtype specified for text, if none was specified, we append "/plain"
    x = [aData indexOfCharacter: '/'];

    if (x < 0 && [aData hasCaseInsensitiveCPrefix: "text"])
    {
        [thePart setContentType: [[[aData asciiString] stringByAppendingString: @"/plain"] lowercaseString]];
    }
    else
    {
        [thePart setContentType: [[aData asciiString] lowercaseString]];
    }

    //
    // We decode our protocol (if we need to)
    //
    aRange = shrinkRange([theLine rangeOfCString: "protocol="  options: NSCaseInsensitiveSearch]);

    if (aRange.location != NSNotFound)
    {
        [thePart setProtocol: [CWParser _parameterValueUsingLine: theLine  range: aRange  decode: NO  charset: nil]];
    }

    //
    // We decode our boundary (if we need to)
    //
    aRange = shrinkRange([theLine rangeOfCString: "boundary="  options: NSCaseInsensitiveSearch]);

    if (aRange.location != NSNotFound)
    {
        [thePart setBoundary: [CWParser _parameterValueUsingLine: theLine  range: aRange  decode: NO  charset: nil]];
    }

    //
    // We decode our charset (if we need to)
    //
    aRange = shrinkRange([theLine rangeOfCString: "charset="  options: NSCaseInsensitiveSearch]);

    if (aRange.location != NSNotFound)
    {
        [thePart setCharset: [[CWParser _parameterValueUsingLine: theLine  range: aRange  decode: NO  charset: nil] asciiString]];
    }

    //
    // We decode our format (if we need to). See RFC2646.
    //
    aRange = shrinkRange([theLine rangeOfCString: "format="  options: NSCaseInsensitiveSearch]);

    if (aRange.location != NSNotFound)
    {
        NSData *aFormat;

        aFormat = [CWParser _parameterValueUsingLine: theLine  range: aRange  decode: NO  charset: nil];

        if ([aFormat caseInsensitiveCCompare: "flowed"] == NSOrderedSame)
        {
            [thePart setFormat: PantomimeFormatFlowed];
        }
        else
        {
            [thePart setFormat: PantomimeFormatUnknown];
        }
    }
    else
    {
        [thePart setFormat: PantomimeFormatUnknown];
    }

    //
    // We decode the parameter "name" if the thePart is an instance of Part
    //
    if ([thePart isKindOfClass: [CWPart class]])
    {
        aRange = [theLine rangeOfCString: "name="  options: NSCaseInsensitiveSearch];

        if (aRange.location != NSNotFound)
        {
            [thePart setFilename: [CWParser _parameterValueUsingLine: theLine  range: aRange  decode: YES  charset: [thePart defaultCharset]]];
        }
    }
}


//
//
//
+ (void) parseDate: (NSData *) theLine
         inMessage: (CWMessage *) theMessage
{
    if ([[theLine asciiString] containsString:@"__Smtpdate"]) {
        // We have seen spammer to use this date: "Date: __Smtpdate", which we consider invalid.
        // Do nothing.
        return;
    }

    if ([theLine length] > 6)
    {
        NSData *aData;

        NSInteger month;
        int day, year, hours, mins, secs;
        NSUInteger tz, i, j, len, tot, s;
        unsigned char *bytes, *word;

        aData = [theLine subdataFromIndex: 6];

        word = malloc(256);
        *word = '\0';

        //LogInfo(@"Have to parse |%@|", [aData asciiString]);

        bytes = (unsigned char*)[aData bytes];
        tot = [aData length];
        i = len = 0;
        s = 0;
        tz = 0;

        // date-time       =       [ day-of-week "," ] date FWS time [CFWS]
        // day-of-week     =       ([FWS] day-name) / obs-day-of-week
        // day-name        =       "Mon" / "Tue" / "Wed" / "Thu" /
        //                         "Fri" / "Sat" / "Sun"
        // date            =       day month year
        // year            =       4*DIGIT / obs-year
        // month           =       (FWS month-name FWS) / obs-month
        // month-name      =       "Jan" / "Feb" / "Mar" / "Apr" /
        //                         "May" / "Jun" / "Jul" / "Aug" /
        //                         "Sep" / "Oct" / "Nov" / "Dec"
        //
        // day             =       ([FWS] 1*2DIGIT) / obs-day
        // time            =       time-of-day FWS zone
        // time-of-day     =       hour ":" minute [ ":" second ]
        // hour            =       2DIGIT / obs-hour
        // minute          =       2DIGIT / obs-minute
        // second          =       2DIGIT / obs-second
        // zone            =       (( "+" / "-" ) 4DIGIT) / obs-zone
        //
        // We need to handle RFC2822 and UNIX time:
        //
        // Date: Wed, 02 Jan 2002 09:07:19 -0700
        // Date: 02 Jan 2002 19:57:49 +0000
        //
        // And broken dates such as:
        //
        // Date: Thu, 03 Jan 2002 16:40:30 GMT
        // Date: Wed, 2 Jan 2002 08:56:18 -0700 (MST)
        // Date: Wed, 9 Jan 2002 10:04:23 -0500 (Eastern Standard Time)
        // Date: 11-Jan-02
        // Date: Tue, 15 Jan 2002 15:45:53 -0801
        // Date: Thu, 17 Jan 2002 11:54:11 -0900<br>
        //
        //while (i < tot && isspace(*bytes))
        //	{
        //	  i++; bytes++;
        //	}

        len = next_word(bytes, i, tot, word); if (len <= 0) { free(word); return; }

        if (isalpha(*word))
        {
            //LogInfo(@"UNIX DATE");

            // We skip the first word, no need for it.
            i += len+1; len = next_word(bytes, i, tot, word); if (len <= 0) { free(word); return; }
        }


        month = year = -1;

        // We got a RFC 822 date. The syntax is:
        // day month year hh:mm:ss zone
        // For example: 03 Apr 2003 17:27:06 +0200
        //LogInfo(@"RFC-822 time");
        day = atoi((const char*)word);

        //printf("len = %d |%s| day = %d\n", len, word, day);

        // We get the month name and we convert it.
        i += len+1; len = next_word(bytes, i, tot, word); if (len <= 0) { free(word); return; }

        for (j = 0; j < 12; j++)
        {
            if (strncasecmp((const char*)word, month_name[j], 3) == 0)
            {
                month = j+1;
            }
        }

        if (month < 0) { free(word); return; }

        //printf("len = %d |%s| month = %d\n", len, word, month);

        // We get the year.
        i += len+1; len = next_word(bytes, i, tot, word); if (len <= 0) { free(word); return; }
        year = atoi((const char*)word);

        if (year < 70) year += 2000;
        if (year < 100) year += 1900;

        //printf("len = %d |%s| year = %d\n", len, word, year);

        // We parse the time using the hh:mm:ss format.
        i += len+1; len = next_word(bytes, i, tot, word); if (len <= 0) { free(word); return; }
        sscanf((const char*)word, "%d:%d:%d", &hours, &mins, &secs);
        //printf("len = %d |%s| %d:%d:%d\n", len, word, hours, mins, secs);

        // We parse the timezone.
        i += len+1; len = next_word(bytes, i, tot, word);

        if (len <= 0)
        {
            tz = 0;
        }
        else
        {
            unsigned char *p;

            p = word;

            if (*p == '-' || *p == '+')
            {
                s = (*p == '-' ? -1 : 1);
                p++;
            }

            len = strlen((const char*)p);

            if (isdigit(*p))
            {
                if (len == 2)
                {
                    tz = (*(p)-48)*36000+*((p+1)-48)*3600;
                }
                else
                {
                    tz = (*(p)-48)*36000+(*(p+1)-48)*3600+(*(p+2)-48)*10+(*(p+3)-48);
                }
            }
            else
            {
                for (j = 0; j < sizeof(timezone_info)/sizeof(timezone_info[0]); j++)
                {
                    if (strncasecmp((const char*)p, timezone_info[j].name, len) == 0)
                    {
                        tz = timezone_info[j].offset;
                    }
                }
            }
            tz = s*tz;
        }
        NSCalendar *calendar = [NSCalendar currentCalendar];
        NSDateComponents *components = [[NSDateComponents alloc] init];
        [components setDay:day];
        [components setMonth:month];
        [components setYear:year];
        [components setHour:hours];
        [components setMinute:mins];
        [components setSecond:secs];
        [components setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT: tz]];
        NSDate *date = [calendar dateFromComponents:components];

        [theMessage setOriginationDate:date];
        free(word);
    }
}

//
//
//
+ (NSData *) parseDestination: (NSData *) theLine
                      forType: (PantomimeRecipientType) theType
                    inMessage: (CWMessage *) theMessage
                        quick: (BOOL) theBOOL
{  
    CWInternetAddress *anInternetAddress;
    NSData *aData;

    NSUInteger i, len, s_len, x, y;
    unsigned char *bytes;
    BOOL b;

    len = 0;
    if (theBOOL)
    {
        aData = theLine;
    }
    else
    {
        switch (theType)
        {
            case PantomimeBccRecipient:
                len = 5;
                break;

            case PantomimeCcRecipient:
            case PantomimeToRecipient:
                len = 4;
                break;

            case PantomimeResentBccRecipient:
                len = 12;
                break;

            case PantomimeResentCcRecipient:
            case PantomimeResentToRecipient:
                len = 11;
                break;
        }

        // We skip over emtpy headers.
        if (len >= [theLine length]) return [NSData data];

        aData = [theLine subdataFromIndex: len];
    }

    bytes = (unsigned char*)[aData bytes];
    len = [aData length];
    b = NO; x = 0;

    for (i = 0; i < len; i++)
    {
        if (*bytes == '"')
        {
            b = !b;
        }

        if (*bytes == ',' || i == len-1)
        {
            if (b)
            {
                bytes++;
                continue;
            }

            y = i;

            // We strip the trailing comma for all but the last entries.
            s_len = y-x;
            if (i == len-1) s_len++;

            anInternetAddress = [[CWInternetAddress alloc]
                                 initWithString: [CWMIMEUtility decodeHeader: [[aData subdataWithRange: NSMakeRange(x, s_len)] dataByTrimmingWhiteSpaces]
                                                                     charset: [theMessage defaultCharset]]];

            if (anInternetAddress) { // ignore malformed addresses
                [anInternetAddress setType: theType];
                [theMessage addRecipient: anInternetAddress];
                RELEASE(anInternetAddress);
            }
            x = y+1;
        }

        bytes++;
    }

    return aData;
}

//
//
//
+ (NSData *) parseFrom: (NSData *) theLine
             inMessage: (CWMessage *) theMessage
                 quick: (BOOL) theBOOL;
{
    CWInternetAddress *anInternetAddress;
    NSData *aData;

    if (!theBOOL && !([theLine length] > 6))
    {
        return [NSData data];
    }

    if (theBOOL)
    {
        aData = theLine;
    }
    else
    {
        aData = [theLine subdataFromIndex: 6];
    }

    anInternetAddress = [[CWInternetAddress alloc] initWithString:
                         [CWMIMEUtility decodeHeader: aData charset: [theMessage defaultCharset]]
                         ];
    [theMessage setFrom: anInternetAddress];
    RELEASE(anInternetAddress);

    return aData;
}


//
// This method is used to parse the In-Reply-To: header value.
//
+ (NSData *)parseInReplyTo:(NSData *)rawLine inMessage:(CWMessage *)message quick:(BOOL)quick
{
    NSData *result = nil;
    if (quick) {
        result = rawLine;
    } else if ([rawLine length] > 13) {
        result = [rawLine subdataFromIndex: 13];
    } else {
        return [NSData data];
    }

    // We check for lame headers like that:
    //
    // In-Reply-To: <4575197F.7020602@de.ibm.com> (Markus Deuling's message of "Tue, 05 Dec 2006 08:02:23 +0100")
    // In-Reply-To: <MABBJIJNAFCGBJJJOEBHEEFGKIAA.reldred@viablelinks.com>; from reldred@viablelinks.com on Wed, Mar 26, 2003 at 11:23:37AM -0800
    //
    NSInteger x = [result indexOfCharacter: ';'];
    NSInteger y = [result indexOfCharacter: ' '];

    if (x > 0 && x < y) {
        result = [result subdataToIndex: x];
    } else if (y > 0) {
        result = [result subdataToIndex: y];
    }

    result = [result unwrap];
    [message setInReplyTo: [result asciiString]];

    return result;
}


//
//
//
+ (NSData *)parseMessageID:(NSData *)rawLine inMessage:(CWMessage *)message quick:(BOOL)quick
{
    if (!quick && !([rawLine length] > 12)) {
        return [NSData data];
    }
    NSData *result = nil;
    if (quick) {
        result = rawLine;
    } else {
        result = [rawLine subdataFromIndex: 12];
    }
    result =  [result unwrap];

    [message setMessageID: [[result dataByTrimmingWhiteSpaces] asciiString]];

    return result;
}


//
//
//
+ (void) parseMIMEVersion: (NSData *) theLine
                inMessage: (CWMessage *) theMessage
{
    if ([theLine length] > 14)
    {
        [theMessage setMIMEVersion: [[theLine subdataFromIndex: 14] asciiString]];
    }
}


//
//
//
+ (NSData *) parseReferences:(NSData *)rawLine inMessage:(CWMessage *)message quick:(BOOL) quick
{
    NSData *result = nil;

    if (quick) {
        result = rawLine;
    } else if ([rawLine length] > 12) {
        result = [rawLine subdataFromIndex: 12];
    }

    if (result && [result length]) {
        NSString *line = [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding];
        NSArray<NSString*> *wrappedRefs =
        [line componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSMutableArray<NSString*> *references =
        [[NSMutableArray alloc] initWithCapacity: wrappedRefs.count];
        for (NSString *wrappedRef in wrappedRefs) {
            NSMutableString *ref = [wrappedRef stringByTrimmingWhiteSpaces].mutableCopy;
            if ([ref isEqualToString:@""]) {
                continue;
            }
            [ref unwrap];
            [references addObject:ref];
        }
        [message setReferences: references];

        return result;
    }

    return [NSData data];
}


//
//
//
+ (void) parseReplyTo: (NSData *) theLine
            inMessage: (CWMessage *) theMessage
{
    if ([theLine length] > 10)
    {
        CWInternetAddress *anInternetAddress;
        NSMutableArray *aMutableArray;
        NSData *aData;

        unsigned char *bytes;
        NSUInteger i, len, s_len, x, y;
        BOOL b;

        aMutableArray = [[NSMutableArray alloc] init];
        aData = [theLine subdataFromIndex: 10];
        bytes = (unsigned char*)[aData bytes];
        len = [aData length];
        b = NO; x = 0;

        for (i = 0; i < len; i++)
        {
            if (*bytes == '"')
            {
                b = !b;
            }

            if (*bytes == ',' || i == len-1)
            {
                if (b)
                {
                    bytes++;
                    continue;
                }

                y = i;

                // We strip the trailing comma for all but the last entries.
                s_len = y-x;
                if (i == len-1) s_len++;

                anInternetAddress = [[CWInternetAddress alloc]
                                     initWithString: [CWMIMEUtility decodeHeader: [[aData subdataWithRange: NSMakeRange(x, s_len)] dataByTrimmingWhiteSpaces]
                                                                         charset: [theMessage defaultCharset]]];

                [aMutableArray addObject: anInternetAddress];
                RELEASE(anInternetAddress);
                x = y+1;
            }

            bytes++;
        }

        if ([aMutableArray count])
        {
            [theMessage setReplyTo: aMutableArray];
        }

        RELEASE(aMutableArray);
    }
}


//
//
//
+ (void) parseResentFrom: (NSData *) theLine
               inMessage: (CWMessage *) theMessage
{
    if ([theLine length] > 13)
    {
        CWInternetAddress *anInternetAddress;

        anInternetAddress = [[CWInternetAddress alloc] initWithString: [CWMIMEUtility decodeHeader:
                                                                        [theLine subdataFromIndex: 13]
                                                                                           charset: [theMessage defaultCharset]]];

        [theMessage setResentFrom: anInternetAddress];
        RELEASE(anInternetAddress);
    }
}


//
//
//
+ (void) parseStatus: (NSData *) theLine
           inMessage: (CWMessage *) theMessage
{
    if ([theLine length] > 8)
    {
        NSData *aData;

        aData = [theLine subdataFromIndex: 8];
        [[theMessage flags] addFlagsFromData: aData  format: PantomimeFormatMbox];
        [theMessage addHeader: @"Status"  withValue: [aData asciiString]];
    }
}


//
//
//
+ (void) parseXStatus: (NSData *) theLine
            inMessage: (CWMessage *) theMessage
{
    if ([theLine length] > 10)
    {
        NSData *aData;

        aData = [theLine subdataFromIndex: 10];
        [[theMessage flags] addFlagsFromData: aData  format: PantomimeFormatMbox];
        [theMessage addHeader: @"X-Status"  withValue: [aData asciiString]];
    }
}


//
//
//
+ (NSData *) parseSubject: (NSData *) theLine
                inMessage: (CWMessage *) theMessage
                    quick: (BOOL) theBOOL
{
    NSData *aData;

    if (theBOOL)
    {
        aData = theLine;
    }
    else if ([theLine length] > 9)
    {
        aData = [[theLine subdataFromIndex: 8] dataByTrimmingWhiteSpaces];
    }
    else
    {
        return [NSData data];
    }

    [theMessage setSubject: [CWMIMEUtility decodeHeader: aData  charset: [theMessage defaultCharset]]];

    return aData;
}


//
//
//
+ (void) parseUnknownHeader: (NSData *) theLine
                  inMessage: (CWMessage *) theMessage
{
    NSData *aName, *aValue;
    NSRange range;

    range = [theLine rangeOfCString: ":"];

    if (range.location != NSNotFound)
    {
        aName = [theLine subdataWithRange: NSMakeRange(0, range.location)];

        // we keep only the headers that have a value
        if (([theLine length]-range.location-1) > 0)
        {
            aValue = [theLine subdataWithRange: NSMakeRange(range.location + 2, [theLine length]-range.location-2)];

            [theMessage addHeader: [aName asciiString]  withValue: [aValue asciiString]];
        }
    }
}


//
//
//
+ (void) parseOrganization: (NSData *) theLine
                 inMessage: (CWMessage *) theMessage
{
    NSString *organization;

    if ([theLine length] > 14)
    {
        organization = [CWMIMEUtility decodeHeader: [[theLine subdataFromIndex: 13] dataByTrimmingWhiteSpaces]
                                           charset: [theMessage defaultCharset]];
    }
    else
    {
        organization = @"";
    }

    [theMessage setOrganization: organization];
}

@end

// MARK: - private methods

@implementation CWParser (Private)

+ (id)_parameterValueUsingLine:(NSData *)inData
                         range:(NSRange)range
                        decode:(BOOL)decode
                       charset:(NSString *)charset;
{
    NSUInteger len = [inData length];
    // Look for the first occurrence of '=' before the end of the line within
    // our range. That marks the beginning of the value. If we don't find one,
    // we set the beggining right after the end of the key tag.
    // (- 1 because we need to start the search *before* the "=" in "name=" to be able to find
    // the "=")
    NSUInteger searchStart = NSMaxRange(range) - 1;
    NSUInteger endOfLine = len - NSMaxRange(range);
    NSRange r1 = [inData rangeOfCString: "="
                                options: 0
                                  range: NSMakeRange(searchStart, endOfLine)];

    NSUInteger value_start = 0;
    NSUInteger value_end = 0;
    if (r1.location != NSNotFound){
        value_start = r1.location + r1.length;
    } else {
        value_start = range.location + range.length;
    }

    // The parameter can be quoted or not like this (for example, with a charset):
    // charset="us-ascii"
    // charset = "us-ascii"
    // charset=us-ascii
    // charset = us-ascii
    // It can be terminated by ';' or end of line.

    // Look the the first occurrence of ';' or newline/end of line.
    // That marks the end of this key value pair.
    // If we don't find one, we set it to the end of the line.
    r1 = [inData firstSemicolonOrNewlineInRange:NSMakeRange(NSMaxRange(range),
                                                            len - NSMaxRange(range))];

    if (r1.location != NSNotFound) {
        value_end = r1.location - 1;
    } else {
        value_end = len - 1;
    }

    // We now have a range that should contain our value.
    // Build a NSRange out of it.
    if (value_end - value_start + 1 > 0) {
        r1 = NSMakeRange(value_start, value_end - value_start + 1);
    } else {
        r1 = NSMakeRange(value_start, 0);
    }

    NSMutableData *resultData = [[NSMutableData alloc] initWithData:
                                 [[[inData subdataWithRange: r1] dataByTrimmingWhiteSpaces]
                                  dataFromQuotedData]
                                 ];
    // VERY IMPORTANT:
    // We check if something was encoded using RFC2231. We need to adjust
    // value_end if we find a multi-line parameter. We also proceed
    // with data substitution while we loop for parameter values unfolding.
    BOOL is_rfc2231 = NO;
    NSRange r2;
    BOOL has_charset = NO;
    if ([inData characterAtIndex: NSMaxRange(range)] == '*') {
        is_rfc2231 = YES;

        if ([inData characterAtIndex: NSMaxRange(range) + 1] == '0') {
            // We consider parameter value continuations (Section 3. of the RFC)
            // in order the set the appropriate end boundary.

            // We check if we have a charset, in case of a multiline value.
            if ([inData characterAtIndex: NSMaxRange(range) + 2] == '*') {
                has_charset = YES;
            }

            r1.location = range.location;
            r1.length = range.length;
            NSUInteger parameters_count = 1;

            while (YES) {
                r1 = [inData rangeOfCString: [[NSString stringWithFormat: @"%s*%li",
                                               [[inData subdataWithRange: range] cString],
                                               (unsigned long)parameters_count] UTF8String]
                                    options: 0
                                      range: NSMakeRange(NSMaxRange(r1), len-NSMaxRange(r1))];
                parameters_count++;

                if (r1.location == NSNotFound) {
                    break;
                }
                value_start = NSMaxRange(r1) + 1;

                while ([inData characterAtIndex: value_start] == '*' || [inData characterAtIndex: value_start] == '=') {
                    value_start++;
                }
                NSRange r2 = [inData firstSemicolonOrNewlineInRange:NSMakeRange(NSMaxRange(r1),
                                                                                len - NSMaxRange(r1))];
                if (r2.location != NSNotFound) {
                    value_end = r2.location;
                } else {
                    value_end = len;
                }
                [resultData appendData:
                 [[[inData subdataWithRange: NSMakeRange(value_start, value_end - value_start)]
                   dataFromSemicolonTerminatedData]
                  dataFromQuotedData]];
            }
        } else if ([inData characterAtIndex: NSMaxRange(range) + 1] == '=') {
            // Example: "title*=us-ascii'en-us'This%20is%20%2A%2A%2Afun%2A%2A%2A"
            has_charset = YES;
        }
    }

    char *charsetAndLanguageDelimiter = "'";
    // Find first delimiter
    r1 = [resultData rangeOfCString: charsetAndLanguageDelimiter];
    if (is_rfc2231 && has_charset && r1.location != NSNotFound) {
        // Find second delimiter
        r2 = [resultData rangeOfCString: charsetAndLanguageDelimiter
                                options: 0
                                  range:
              NSMakeRange(NSMaxRange(r1), [resultData length] - NSMaxRange(r1))
              ];
        // We intentionally ignore the language. We do not have a use case for it.
        // It would be inbetween r1 and r2 here though.

        // Extract charset (ignore language if any)
        NSData *charsetData = [resultData subdataToIndex: r1.location];

        // Strip charset, language and delimiters from our data
        [resultData replaceBytesInRange: NSMakeRange(0, NSMaxRange(r2))
                              withBytes: NULL
                                 length: 0];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        // Suppress warning. We need to be able to pass the specified charset
        if (decode) {
            NSString *result = [[NSString alloc] initWithData: resultData
                                                     encoding: NSASCIIStringEncoding];
            if (has_charset) {
                return [result stringByReplacingPercentEscapesUsingEncoding:
                        [NSString encodingForCharset: charsetData]];
            } else {
                return result;
            }
        }
#pragma clang diagnostic pop
    } else {
        if (decode) {
            return [CWMIMEUtility decodeHeader: resultData  charset: charset];
        }
    }

    return resultData;
}

@end
