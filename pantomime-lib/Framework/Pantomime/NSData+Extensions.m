/*
**  NSData+Extensions.m
**
**  Copyright (c) 2001-2007
**                2014
**
**  Author: Ludovic Marcotte <ludovic@Sophos.ca>
**          Riccardo Mottola <rm@gnu.org>
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

#import "NSData+Extensions.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>

#import "CWConstants.h"

#import <stdlib.h>
#import <string.h>

//
// C functions and constants
//
int getValue(char c);
void nb64ChunkFor3Characters(char *buf, const char *inBuf, NSUInteger numChars);

static const char basis_64[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
static const char *hexDigit = "0123456789ABCDEF";



//!
// add an NSData cluster member NSSubrangeData that retaind its parent and
// used its data. Would make almost all of these operations work without
// copying.
@implementation NSData (PantomimeExtensions)

//
//!  this should ignore characters in the stream that aren't in
//        the base64 alphabet (as per the spec). would remove need for
//        ...removeLinefeeds... too
//
- (NSData *) decodeBase64
{
  NSUInteger i, j, rawIndex, block, pad, data_len;
    NSInteger length;
  const unsigned char *bytes;
  char *raw;

  if ([self length] == 0)
    {
      return [NSData data];
    }

  data_len = [self length];
  bytes = [self bytes];
  pad = 0;

  for (i = data_len - 1; bytes[i] == '='; i--)
    {
      pad++;
    }
  
  length = data_len * 6 / 8 - pad;
  
  raw = (char *)malloc(length);
  rawIndex = 0;

  for (i = 0; i < data_len; i += 4)
    {
      block = (getValue(bytes[i]) << 18) +
	(getValue(bytes[i+1]) << 12) +
	(getValue(bytes[i+2]) << 6) +
	(getValue(bytes[i+3]));
      
      for (j = 0; j < 3 && rawIndex+j < length; j++)
	{
	  raw[rawIndex+j] = (char)((block >> (8 * (2 - j))) & 0xff);
	}

      rawIndex += 3;
    }
  
  // This could happen for broken encoded base64 content such as the following example:
  // ------=_NextPart_KO_X1098V29876N91O412QM815
  // Content-Type: text/plain; charset=UTF-8
  // Content-Disposition: attachment; filename="teste.txt"
  // Content-Transfer-Encoding: base64
  //
  // ====
  //
  if (length < 0)
    {
      free(raw);
      return [NSData data];
    }

  return AUTORELEASE([[NSData alloc] initWithBytesNoCopy: raw  length: length]);
}


//
//
//
- (NSData *) encodeBase64WithLineLength: (NSUInteger) theLength
{
  const char *inBytes = [self bytes];
  const char *inBytesPtr = inBytes;
  NSInteger inLength = [self length];

  char *outBytes = malloc(sizeof(char)*inLength*2);
  char *outBytesPtr = outBytes;

  NSUInteger numWordsPerLine = theLength/4;
  NSUInteger wordCounter = 0;

  // We memset 0 our buffer so with are sure to not have
  // any garbage in it.
  memset(outBytes, 0, sizeof(char)*inLength*2);

  while (inLength > 0)
    {
      nb64ChunkFor3Characters(outBytesPtr, inBytesPtr, inLength);
      outBytesPtr += 4;
      inBytesPtr += 3;
      inLength -= 3;

      wordCounter ++;

      if (theLength && wordCounter == numWordsPerLine)
	{
	  wordCounter = 0;
	  *outBytesPtr = '\n';
	  outBytesPtr++;
	}
    }

  return AUTORELEASE([[NSData alloc] initWithBytesNoCopy: outBytes length: (outBytesPtr-outBytes)]);
}


//
//
//
- (NSData *) unfoldLines
{
  NSMutableData *aMutableData;
  NSUInteger i, length;
  
  const unsigned char *bytes, *b;
  
  length = [self length];
  b = bytes = [self bytes];
  
  aMutableData = [[NSMutableData alloc] initWithCapacity: length];
  
  [aMutableData appendBytes: b  length: 1];
  b++;
  
  for (i = 1; i < length; i++,b++)
    {
      if (b[-1]=='\n' && (*b==' ' || *b=='\t'))
	{
	  [aMutableData setLength: ([aMutableData length] - 1)];
	}
      
      [aMutableData appendBytes: b length: 1];
    }

  return AUTORELEASE(aMutableData);
}

- (NSData *)decodeQuotedPrintableInHeader:(BOOL)aBOOL
{
    NSUInteger len = [self length];
    const unsigned char *bytes = [self bytes];
    unsigned char ch = 0;
    const unsigned char *b = bytes;
    NSMutableData *result = [[NSMutableData alloc] initWithCapacity:len];
    NSUInteger i = 0;
    for (i = 0; i < len; i++,b++) {
        if (b[0] == '=' && i + 1 == len) {
            // Trailing '=', ignore.
            // Example: "Let=E2=80=99s see.="
            break;
        } else if (b[0] == '=' && i + 1 < len && b[1] == '\n') {
            b++;
            i++;
            continue;
        } else if (*b == '=' && i + 2 < len) {
            b++;
            i++;
            if (*b >= 'A' && *b <= 'F') {
                ch = 16 * (*b - 'A' + 10);
            } else if (*b >= 'a' && *b <= 'f') {
                ch = 16 * (*b - 'a' + 10);
            } else if (*b >= '0' && *b <= '9') {
                ch = 16 * (*b - '0');
            } else {
                // The encoding is invalid (Hex data contained invalid char).
                // Nothing we can do.
                return nil;
            }

            b++;
            i++;

            if (*b >= 'A' && *b <= 'F') {
                ch += *b - 'A' + 10;
            } else if (*b >= 'a' && *b <= 'f') {
                ch += *b - 'a' + 10;
            } else if (*b  >= '0' && *b <= '9') {
                ch += *b - '0';
            } else {
                // The encoding is invalid (Hex data contained invalid char).
                // Nothing we can do.
                return nil;
            }
            [result appendBytes:&ch length:1];
        } else if (aBOOL && *b == '_') {
            ch = 0x20;
            [result appendBytes:&ch length:1];
        } else {
            [result appendBytes:b length:1];
        }
    }

    return result;
}


//
//
//
- (NSData *) encodeQuotedPrintableWithLineLength: (NSUInteger) theLength
					inHeader: (BOOL) aBOOL
{
  NSMutableData *aMutableData;
  const unsigned char *b;
  NSUInteger i, length, line;
  char buf[4];
  
  aMutableData = [[NSMutableData alloc] initWithCapacity: [self length]];
  b = [self bytes];
  length = [self length];

  buf[3] = 0;
  buf[0] = '=';
  line = 0;

  for (i = 0; i < length; i++, b++)
    {
      if (theLength && line >= theLength)
	{
	  [aMutableData appendBytes: "=\n" length: 2];
	  line = 0;
	}
      // RFC says must encode space and tab right before end of line
      if ( (*b == ' ' || *b == '\t') && i < length - 1 && b[1] == '\n')
	{
	  buf[1] = hexDigit[(*b)>>4];
	  buf[2] = hexDigit[(*b)&15];
	  [aMutableData appendBytes: buf 
			length: 3];
	  line += 3;
	}
      //!  really always pass \n through here?
      else if (!aBOOL &&
	       (*b == '\n' || *b == ' ' || *b == '\t'
		|| (*b >= 33 && *b <= 60)
		|| (*b >= 62 && *b <= 126)))
	{
	  [aMutableData appendBytes: b  length: 1];
	  if (*b == '\n')
	    {
	      line = 0;
	    }
	  else
	    {
	      line++;
	    }
	}
      else if (aBOOL && ((*b >= 'a' && *b <= 'z') || (*b >= 'A' && *b <= 'Z')))
	{
	  [aMutableData appendBytes: b  length: 1];
	  if (*b == '\n')
	    {
	      line = 0;
	    }
	  else
	    {
	      line++;
	    }
	}
      else if (aBOOL && *b == ' ')
	{
	  [aMutableData appendBytes: "_"  length: 1];
	}
      else
	{
	  buf[1] = hexDigit[(*b)>>4];
	  buf[2] = hexDigit[(*b)&15];
	  [aMutableData appendBytes: buf  length: 3];
	  line += 3;
	}
    }
  
  return AUTORELEASE(aMutableData);
}

- (NSRange)rangeOfData:(NSData *)needle
{
    return [self rangeOfData:needle options:0 range:[self fullRange]];
}

- (NSRange)fullRange;
{
    return NSMakeRange(0, self.length);
}


//
//
//
- (NSRange) rangeOfCString: (const char *) theCString
{
  return [self rangeOfCString: theCString
	       options: 0
	       range: NSMakeRange(0,[self length])];
}


//
//
//
-(NSRange) rangeOfCString: (const char *) theCString
		  options: (NSUInteger) theOptions
{
  return [self rangeOfCString: theCString 
	       options: theOptions 
	       range: NSMakeRange(0,[self length])];
}

//
//
//
-(NSRange) rangeOfCString: (const char *) theCString
                  options: (NSUInteger) theOptions
                    range: (NSRange) theRange
{
  const char *b, *bytes;
  NSUInteger i, len, slen;

    bytes = [self bytes];

    len = [self length];
    if (!bytes || !theCString || len == 0 || theCString[0] == '\0' ||
        theRange.length == 0) {
        return NSMakeRange(NSNotFound,0);
    }


  slen = strlen(theCString);

    if (theRange.length < slen) {
        return NSMakeRange(NSNotFound,0);
    }

  b = bytes;
  
  if (len > theRange.location + theRange.length)
    {
      len = theRange.location + theRange.length;
    }

//!  this could be optimized
  if (theOptions & NSCaseInsensitiveSearch)
    {
      i = theRange.location;
      b += i;
      
      for (; i <= len-slen; i++, b++)
	{
	  if (!strncasecmp(theCString,b,slen))
	    {
	      return NSMakeRange(i,slen);
	    }
	}
    }
  else
    {
      i = theRange.location;
      b += i;
      
      for (; i <= len-slen; i++, b++)
	{
	  if (!memcmp(theCString,b,slen))
	    {
	      return NSMakeRange(i,slen);
	    }
	}
    }

  return NSMakeRange(NSNotFound,0);
}


//
//
//
- (NSData *) subdataFromIndex: (NSUInteger) theIndex
{
  return [self subdataWithRange: NSMakeRange(theIndex, [self length] - theIndex)];
}


//
//
//
- (NSData *) subdataToIndex: (NSUInteger) theIndex
{
  return [self subdataWithRange: NSMakeRange(0, theIndex)];
}

- (NSData *)dataByTrimmingWhiteSpaces
{
    const char *bytes = [self bytes];
    NSUInteger len = [self length];
    long i = 0;
    for (i = 0; i < len && (bytes[i] == ' ' || bytes[i] == '\t'); i++);
    long j = 0;
    for (j = len - 1; j >= 0 && (bytes[j] == ' ' || bytes[j] == '\t'); j--);

    if (j < i) {
        return [NSData new];
    }
    return [self subdataWithRange: NSMakeRange(i, j - i + 1)];
}


//
//
//
- (NSData *) dataByRemovingLineFeedCharacters
{
  NSMutableData *aMutableData;
  const char *bytes;
  NSUInteger i, j, len;
  char *dest;
  
  bytes = [self bytes];
  len = [self length];
  
  aMutableData = [[NSMutableData alloc] init];
  [aMutableData setLength: len];
  
  dest = [aMutableData mutableBytes];
  
  for (i = j = 0; i < len; i++)
    {
      if (bytes[i] != '\n')
	{
	  dest[j++] = bytes[i];
	}
    }
  
  [aMutableData setLength: j];
  
  return AUTORELEASE(aMutableData);
}


//
//
//
- (NSData *) dataFromQuotedData
{
  const char *bytes;
  NSUInteger len;
  
  bytes = [self bytes];
  len = [self length];

  if (len < 2)
    {
      return AUTORELEASE(RETAIN(self));
    }
  
  if (bytes[0] == '"' && bytes[len-1] == '"')
    {
      return [self subdataWithRange: NSMakeRange(1, len-2)];
    }
  
  return AUTORELEASE(RETAIN(self));
}


//
//
//
- (NSData *) dataFromSemicolonTerminatedData
{
  const char *bytes;
  NSUInteger len;
  
  bytes = [self bytes];
  len = [self length];

  if (len < 2)
    {
      return AUTORELEASE(RETAIN(self));
    }

  if (bytes[len-1] == ';')
    {
      return [self subdataToIndex: len-1];
    }

  return AUTORELEASE(RETAIN(self));
}

//
//
//
- (NSInteger) indexOfCharacter: (char) theCharacter
{
  const char *b;
  NSUInteger i, len;
 
  b = [self bytes];
  len = [self length];

  for ( i = 0; i < len; i++, b++)
    if (*b == theCharacter)
      {
	return i;
      }
  
  return -1;
}


//
//
//
- (BOOL) hasCPrefix: (const char *) theCString
{
  const char *bytes;
  NSUInteger len, slen;
  
  if (!theCString)
    {
      return NO;
    }
  
  bytes = [self bytes];
  len = [self length];

  slen = strlen(theCString);
  
  if ( slen > len)
    {
      return NO;
    }

  if (!strncmp(bytes,theCString,slen))
    {
      return YES;
    }
  
  return NO;
}


//
//
//
- (BOOL) hasCSuffix: (const char *) theCString
{
  const char *bytes;
  NSUInteger len, slen;
  
  if (!theCString) 
    {
      return NO;
    }

  bytes = [self bytes];
  len = [self length];

  slen = strlen(theCString);

  if (slen > len) 
    {
      return NO;
    }

  if (!strncmp(&bytes[len-slen],theCString,slen))
    {
      return YES;
    }
  
  return NO;
}


//
//
//
- (BOOL) hasCaseInsensitiveCPrefix: (const char *) theCString
{
  const char *bytes;
  NSUInteger len, slen;
  
  if (!theCString) 
    {
      return NO;
    }

  bytes = [self bytes];
  len = [self length];
  slen = strlen(theCString);
  
  if ( slen > len)
    {
      return NO;
    }
      
  if ( !strncasecmp(bytes,theCString,slen) )
    {
      return YES;
    }

  return NO;
}


//
//
//
- (BOOL) hasCaseInsensitiveCSuffix: (const char *) theCString
{
  const char *bytes;
  NSUInteger len, slen;
  
  if (!theCString)
    {
      return NO;
    }
  
  bytes = [self bytes];
  len = [self length];
  slen = strlen(theCString);

  if (slen > len) 
    {
      return NO;
    }  

  if (!strncasecmp(&bytes[len-slen],theCString,slen))
    {
      return YES;
    }
  
  return NO;
}


//
//
//
- (NSComparisonResult) caseInsensitiveCCompare: (const char *) theCString
{
  NSUInteger slen, len, clen;
    NSInteger i;
  const char *bytes;
  
  // Is this ok?
  if (!theCString)
    {
      return NSOrderedDescending;
    }
      
  bytes = [self bytes];
  len = [self length];
  slen = strlen(theCString);
  
  if (slen > len)
    {
      clen = len;
    }
  else
    {
      clen = slen;
    }

  i = strncasecmp(bytes,theCString,clen);
  
  if (i < 0)
    {
      return NSOrderedAscending;
    }
  
  if (i > 0)
    {
      return NSOrderedDescending;
    }
  
  if (slen == len)
    {
      return NSOrderedSame;
    }

  if (slen < len)
    {
      return NSOrderedAscending;
    }
  
  return NSOrderedDescending;
}

- (NSArray *) componentsSeparatedByCString: (const char *) theCString
{
  NSMutableArray *aMutableArray;
  NSRange r1, r2;
  NSUInteger len;
  
  aMutableArray = [[NSMutableArray alloc] init];
  len = [self length];
  r1 = NSMakeRange(0,len);
  
  r2 = [self rangeOfCString: theCString
	     options: 0 
	     range: r1];
  
  while (r2.length)
    {
      [aMutableArray addObject: [self subdataWithRange: NSMakeRange(r1.location, r2.location - r1.location)]];
      r1.location = r2.location + r2.length;
      r1.length = len - r1.location;
      
      r2 = [self rangeOfCString: theCString  options: 0  range: r1];
    }

  [aMutableArray addObject: [self subdataWithRange: NSMakeRange(r1.location, len - r1.location)]];
  
  return AUTORELEASE(aMutableArray);
}

- (void)enumerateComponentsSeperatedByString:(const char *)theCString
                                       block:(void (^)(NSData *aLine, NSUInteger count, BOOL isLast))block
{
    NSUInteger len = [self length];
    NSRange r1 = NSMakeRange(0,len);

    NSRange r2 = [self rangeOfCString:theCString
                              options:0
                                range:r1];


    NSUInteger count = 0;
    while (r2.length) {
        block([self subdataWithRange:NSMakeRange(r1.location, r2.location - r1.location)],
              count,
              NO);
        count++;
        r1.location = r2.location + r2.length;
        r1.length = len - r1.location;

        r2 = [self rangeOfCString: theCString  options: 0  range: r1];
    }

    block([self subdataWithRange:NSMakeRange(r1.location, len - r1.location)], count, YES);
}

//
//
//
- (NSString *) asciiString
{
  return AUTORELEASE([[NSString alloc] initWithData: self  encoding: NSASCIIStringEncoding]);
}


//
//
//
- (NSString *) imapUtf7String
{
    NSStringEncoding encoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingUTF7_IMAP);
    return AUTORELEASE([[NSString alloc] initWithData: self  encoding: encoding]);
}


//
//
//
- (const char *) cString
{
  NSMutableData *aMutableData;
  
  aMutableData = [[NSMutableData alloc] init];
  AUTORELEASE_VOID(aMutableData);
   
  [aMutableData appendData: self];
  [aMutableData appendBytes: "\0"  length: 1];
  
  return [aMutableData mutableBytes];
}


//
//
//
- (unichar) characterAtIndex: (NSUInteger) theIndex
{
  const char *bytes;
  NSUInteger i, len;
  
  len = [self length];

  if (len == 0 || theIndex >= len)
    {
      [[NSException exceptionWithName: NSRangeException
		    reason: @"Index out of range."
		    userInfo: nil] raise];
      
      return (unichar)0;
    }

  bytes = [self bytes];

  for (i = 0; i < theIndex; i++)
    {
      bytes++;
    }

  return (unichar)*bytes;
}


//
//
//
- (NSData *) unwrap
{
    NSData *result = self;
    if (self.length >= 2 &&
        [self characterAtIndex: 0] == '<' && [self characterAtIndex: self.length - 1] == '>') {
        NSRange rangeWithoutWrappers = NSMakeRange(1, self.length - 2);
        result = [self subdataWithRange:rangeWithoutWrappers];
    }
    return result;
}


//
//
//
- (NSData *) unwrapWithLimit: (NSUInteger) theQuoteLimit
{
  NSMutableData *aMutableData, *lines;
  NSData *aLine;

  NSUInteger i, len, quote_depth, line_quote_depth, line_start;
  BOOL is_flowed;

  len = [self length];

  aMutableData = [[NSMutableData alloc] init];//WithCapacity: len];
  lines = [[NSMutableData alloc] init];
  quote_depth = -1;
  
  // We analyse the string until the last character
  for (i = 0; i < len;)
    {
      // We analyse the quote depth of the current line
      if ([self characterAtIndex: i] == '>')
	{
	  for (line_quote_depth = 0; i < len && [self characterAtIndex: i] == '>'; i++)
	    {
	      line_quote_depth++;
	    }
	}
      else
	{
	  line_quote_depth = 0;
	}
      
      // If the current quote depth is not defined, set it to quote depth of current line
      if (quote_depth == -1)
	{
	  quote_depth = line_quote_depth;
	}
      
      // We verify if the line has been space-stuffed
      if (i < len && [self characterAtIndex: i] == ' ')
	{
	  i++;
	}
      line_start = i;

      // We look for the next line break
      for (; i < len && [self characterAtIndex: i] != '\n'; i++);
      
      // We get the actual content of the current line
      aLine = [self subdataWithRange: NSMakeRange(line_start, i-line_start)];
      
      // We verify if the line ends with a soft break 
      is_flowed = [aLine length] > 0 && [aLine characterAtIndex: [aLine length]-1] == ' ';

      // We must handle usenet signature as a special case
      if (is_flowed && [aLine caseInsensitiveCCompare: "-- "] == NSOrderedSame)
	{
	  is_flowed = NO;
	}

      if (is_flowed && quote_depth == line_quote_depth)
	{ 
	  // The current line is flowed;
	  // we append it to the buffer without quote characters
	  [lines appendData: aLine];
	}
      else if (is_flowed)
	{ 
	  // The current line is flowed but has mis-matched quoting

	  // We first append the previous paragraph to the buffer with the necessary quote characters
	  if (quote_depth)
	    {
	      [lines replaceBytesInRange: NSMakeRange(0, [lines length])
		     withBytes: [[lines quoteWithLevel: quote_depth  wrappingLimit: theQuoteLimit] bytes]];
	    }

	  [aMutableData appendData: lines];
	  [aMutableData appendCString: "\n"];
	  
	  // We initialize the current paragraph with the current line
	  [lines replaceBytesInRange: NSMakeRange(0, [lines length])  withBytes: [aLine bytes]];
	  
	  // We set the paragraph depth with the current line depth
	  quote_depth = line_quote_depth;
	}
      else if (!is_flowed && quote_depth == line_quote_depth)
	{ 
	  // The line is fixed, we append it.
	  [lines appendData: aLine];
	  
	  // We add the necessary quote characters in the paragraph
	  if (quote_depth)
	    {
	      NSData *d;
	      
	      d = [lines quoteWithLevel: quote_depth   wrappingLimit: theQuoteLimit];
	      [lines replaceBytesInRange: NSMakeRange(0, [lines length])
		     withBytes: [d bytes]  length: [d length]];
	    }

	  // We append the paragraph (if any)
	  if ([lines length])
	    {
	      [aMutableData appendData: lines];
	    }
	  [aMutableData appendCString: "\n"];
	  
	  // We empty the paragraph buffer
	  [lines replaceBytesInRange: NSMakeRange(0,[lines length])
			   withBytes: NULL
			      length: 0];

	  // We reset the paragraph depth
	  quote_depth = -1;
	}
      else
	{
	  // The line is fixed but has mis-matched quoting
	  
	  // We first append the previous paragraph (if any) to the buffer with the necessary quote characters
	  if (quote_depth)
	    {
	      [lines replaceBytesInRange: NSMakeRange(0, [lines length])
		     withBytes: [[lines quoteWithLevel: quote_depth  wrappingLimit: theQuoteLimit] bytes]];
	    }
	  
	  [aMutableData appendData: lines];
	  [aMutableData appendCString: "\n"];

	  // We append the fixed line to the buffer with the necessary quote characters
	  if (line_quote_depth)
	    {
	      aLine = [aLine quoteWithLevel: line_quote_depth  wrappingLimit: theQuoteLimit];
	    }

	  [aMutableData appendData: aLine];
	  [aMutableData appendCString: "\n"];

	  // We empty the paragraph buffer
	  [lines replaceBytesInRange: NSMakeRange(0,[lines length])
			   withBytes: NULL
			      length: 0];

	  // We reset the paragraph depth
	  quote_depth = -1;
	}
      
      // The next iteration must starts after the line break
      i++;
    }

  // We must handle flowed lines that don't have a fixed line break at the end of the message
  if ([lines length])
    {
      if (quote_depth)
	{
	  [lines replaceBytesInRange: NSMakeRange(0, [lines length])
		 withBytes: [[lines quoteWithLevel: quote_depth  wrappingLimit: theQuoteLimit] bytes]];
	}

      [aMutableData appendData: lines];
      [aMutableData appendCString: "\n"];
    }

  DESTROY(lines);

  return AUTORELEASE(aMutableData);
}


//
//
//
- (NSData *) wrapWithLimit: (NSUInteger) theLimit
{
  NSMutableData *aMutableData;
  NSData *aLine, *part;
  NSArray *lines;
  NSUInteger i, j, k, split;
  int depth;

  // We first verify if the string is valid
  if ([self length] == 0)
    {
      return [NSData data];
    }
  
  // We then verify if the limit is valid
  if (theLimit == 0 || theLimit > 998)
    {
      theLimit = 998;
    }
  
  // We initialize our local variables
  aMutableData = [[NSMutableData alloc] init];//WithCapacity: [self length]];
  lines = [self componentsSeparatedByCString: "\n"];
  
  // We analyse each line
  for (i = 0; i < [lines count]; i++)
    {
      aLine = [lines objectAtIndex: i];

      // We compute the quote depth
      for (depth = 0; depth < [aLine length] && [aLine characterAtIndex: depth] == '>'; depth++);
      j = depth;
      
      // We remove the leading whitespace if any
      if (depth && [aLine length] > j && [aLine characterAtIndex: j] == 32)
	{
	  j++;
	}

      aLine = [aLine subdataFromIndex: j];

      // If the line is NOT the signature separator, we remove the trailing space(s)
      if ([aLine caseInsensitiveCCompare: "-- "] != NSOrderedSame)
	{
	  for (j = [aLine length]; j > 0 && [aLine characterAtIndex: j-1] == 32; j--);
	  if (depth && j < [aLine length])
	    {
	      // If line is quoted, we preserve a whitespace for the soft-break
	      j++;
	    }
	  aLine = [aLine subdataToIndex: j];
	}

      // If the line is the signature separator or if the line length with the
      // quote characters and the space-stuffing is lower than the limit,
      // we directly append the line to the buffer
      if ([aLine caseInsensitiveCCompare: "-- "] == NSOrderedSame || depth+1+[aLine length] <= theLimit)
	{
	  // We add the quote characters
	  for (j = 0; j < depth; j++)
	    {
	      [aMutableData appendCString: ">"];
	    }
	  
	  // We space-stuff the line if necessary. The conditions are:
	  // - the line is quoted or
	  // - the line starts with a quote character or
	  // - the line starts with a whitespace or
	  // - the line starts with the word From.
	  if (depth ||
	      ([aLine length] && ([aLine characterAtIndex: 0] == '>' || [aLine characterAtIndex: 0] == ' ' || [aLine hasCPrefix: "From"])))
	    {
	      [aMutableData appendCString: " "];
	    }

	  // We append the line to the buffer
	  [aMutableData appendData: aLine];
	  [aMutableData appendCString: "\n"];
	  
	  // We jump to the next line
	  continue;
	}

      // We look for the right place to split the line
      for (j = 0; j < [aLine length];)
	{
	  // We verify if the line after character j has a length lower than the limit
	  if ([aLine length] - j + depth + 1 < theLimit)
	    {
	      split = [aLine length];
	    }
	  // No it hasn't
	  else
	    {
	      split = j;
	      
	      // We search for the last whitespace before the limit
	      for (k = j; k < [aLine length] && k - j + depth + 1 < theLimit; k++)
		{
		  if ([aLine characterAtIndex: k] == 32)
		    {
		      split = k;
		    }
		}

		/*
		No good spot; include the entire next word. This isn't really
		optimal, but the alternative is to split the word, and that
		would be horribly ugly. Also, it'd mean that deeply quoted
		text might appear with one letter on each row, which is even
		uglier and means that the receiver won't be able to
		reconstruct the text.

		A proper fix would be to have both parameters for a 'soft'
		line limit that we _try_ to break before, and a 'hard' line
		limit that specifies an actual hard limit of a protocol or
		something. In NNTP, the values would be 72 and 998
		respectively. This means that text quoted 70 levels (and yes,
		I have seen such posts) will appear with one unbroken word on
		each line (as long as the word is shorter than 928
		characters). This is still ugly, but:

		a. invalid (protocol-wise) lines will never be generated
		   (unless something's quoted >998 levels)

		b. a MIME decoder that handles format=flowed will be able to
		   reconstruct the text properly

		(Additionally, it might turn out to be useful to have a lower
		limit on wrapping length, eg. 20. If the effective line
		length is shorter than this, wrap to quote-depth+soft-limit
		(so eg. text quoted 60 times would be wrapped at 60+72
		characters instead of 72). This wouldn't make any difference
		on flowed capable MIME decoders, but might turn out to look
		better when viewed with non-flowed handling programs.
		Hopefully, such deeply quoted text won't be common enough to
		be worth the trouble, so people with non-flowed capable
		software will simply have to live with the ugly posts in
		those cases.)
 		*/
	      if (split == j)
		{
		  // No whitespace found before the limit;
		  // continue farther until a whitespace or the last character of the line
		  for (; k < [aLine length] && [aLine characterAtIndex: k] != 32; k++);
		  split = k;
		}
	    }

	  // Since the line will be splitted, we must keep a whitespace for
	  // the soft-line break
	  if (split < [aLine length])
	    {
	      split++;
	    }
	  
	  // Retrieve splitted part of line
	  part = [aLine subdataWithRange: NSMakeRange(j, split - j)];

	  // We add the quote characters
	  for (k = 0; k < depth; k++)
	    {
	      [aMutableData appendCString: ">"];
	    }
	  
	  // We space-stuff the line if necesary.
	  if (depth ||
	      ([part length] && ([part characterAtIndex: 0] == '>' || [part characterAtIndex: 0] == ' ' || [part hasCPrefix: "From"])))
	    {
	      [aMutableData appendCString: " "];
	    }

	  // Append line part to buffer
	  [aMutableData appendData: part];
	  [aMutableData appendCString: "\n"];
	  
	  // Next iteration continues where current split occured 
	  j = split;
	}

      
    }
  
  if (i > 0)
    {
      [aMutableData replaceBytesInRange: NSMakeRange([aMutableData length]-1, 1)  withBytes: NULL  length: 0];
    }
  
  return AUTORELEASE(aMutableData);
}

//
//
//
- (NSData *) quoteWithLevel: (NSUInteger) theLevel
	      wrappingLimit: (NSUInteger) theLimit
{
  NSMutableData *aMutableData, *aQuotePrefix;
  NSData *aData, *aLine;
  NSArray *lines;
  BOOL isQuoted;
  int i;

  // We verify if the wrapping limit is smaller then the quote level
  if (theLevel > theLimit) 
    {
      return [NSData data];
    }
  
  aMutableData = [[NSMutableData alloc] initWithCapacity: [self length]];
  aQuotePrefix = [[NSMutableData alloc] initWithCapacity: theLevel];

  // We wrap the string to the proper limit
  aData = [self wrapWithLimit: (theLimit - theLevel)];
  lines = [aData componentsSeparatedByCString: "\n"];

  // We prepare the line prefix
  for (i = 0; i < theLevel; i++)
    {
      [aQuotePrefix appendCString: ">"];
    }
  
  // We add the line prefix to each wrapped line
  for (i = 0; i < [lines count]; i++)
    {
      aLine = [lines objectAtIndex: i];
      isQuoted = ([aLine length] > 0 && [aLine characterAtIndex: 0] == '>');
      
      [aMutableData appendData: aQuotePrefix];
      if (!isQuoted)
	{
	  [aMutableData appendCString: " "];
	}
      [aMutableData appendData: aLine];
      [aMutableData appendCString: "\n"];
    }

  if (i > 0)
    {
      [aMutableData replaceBytesInRange: NSMakeRange([aMutableData length]-1, 1)  withBytes: NULL  length: 0];
    }

  RELEASE(aQuotePrefix);

  return AUTORELEASE(aMutableData);
}

@end


//
//
//
@implementation NSMutableData (PantomimeExtensions)

- (void) appendCFormat: (NSString *) theFormat, ...
{
  NSString *aString;
  va_list args;
  
  va_start(args, theFormat);
  aString = [[NSString alloc] initWithFormat: theFormat  arguments: args];
  va_end(args);
  
  // We allow lossy conversion to not lose any information / raise an exception
  [self appendData: [aString dataUsingEncoding: NSASCIIStringEncoding  allowLossyConversion: YES]];
  
  RELEASE(aString);
}


//
//
//
- (void) appendCString: (const char *) theCString
{
  [self appendBytes: theCString  length: strlen(theCString)];
}


//
//
//
- (void) insertCString: (const char *) theCString
	       atIndex: (NSUInteger) theIndex
{
  NSUInteger s_length, length;

  if (!theCString)
    {
      return;
    }
  
  s_length = strlen(theCString);

  if (s_length == 0)
    {
      return;
    }

  length = [self length];
  
  // We insert at the beginning of the data
  if (theIndex <= 0)
    {
      NSMutableData *data;
      
      data = [NSMutableData dataWithBytes: theCString  length: s_length];
      [data appendData: self];
      [self setData: data];
    }
  // We insert at the end of the data
  else if (theIndex >= length)
    {
      [self appendCString: theCString];
    }
  // We insert somewhere in the middle
  else
    {
      NSMutableData *data;
        NSData *subData = [self subdataWithRange: NSMakeRange(0, theIndex)];
      data = [NSMutableData dataWithBytes:subData.bytes  length: theIndex];
      [data appendCString: theCString];
      [data appendData: [self subdataWithRange: NSMakeRange(theIndex, length - theIndex)]];
      [self setData: data];
    }
}


//
//
//
- (void) replaceCRLFWithLF
{
  unsigned char *bytes, *bi, *bo;
  NSUInteger delta, i,length;
  
  bytes = [self mutableBytes];
  length = [self length];
  bi = bo = bytes;
  
  for (i = delta = 0; i < length; i++, bi++)
    {
      if (i+1 < length && bi[0] == '\r' && bi[1] == '\n')
	{
	  i++;
	  bi++;
	  delta++;
	}
      
      *bo = *bi;
      bo++;
    }
  
  [self setLength: length-delta];
}


//
//
//
- (NSMutableData *) replaceLFWithCRLF
{
  NSMutableData *aMutableData;
  unsigned char *bytes, *bi, *bo;
  NSUInteger delta, i, length;
  
  bi = bytes = [self mutableBytes];
  length = [self length];
  delta = 0;
  
  if (bi[0] == '\n')
    {
      delta++;
    }
  
  bi++;
  
  for (i = 1; i < length; i++, bi++)
    {
      if ((bi[0] == '\n') && (bi[-1] != '\r'))
	{
	  delta++;
	}
    }
  
  bi = bytes;
  aMutableData = [[NSMutableData alloc] initWithLength: (length+delta)];
  bo = [aMutableData mutableBytes];
  
  for (i = 0; i < length; i++, bi++, bo++)
    {
      if ((i+1 < length) && (bi[0] == '\r') && (bi[1] == '\n'))
	{
	  *bo = *bi;
	  bo++;
	  bi++;
	  i++;
	}
      else if (*bi == '\n')
	{
	  *bo = '\r';
	  bo++;
	}
      
      *bo = *bi;
    }

  return AUTORELEASE(aMutableData);
}

@end


//
// C functions
//
int getValue(char c)
{
  if (c >= 'A' && c <= 'Z') return (c - 'A');
  if (c >= 'a' && c <= 'z') return (c - 'a' + 26);
  if (c >= '0' && c <= '9') return (c - '0' + 52);
  if (c == '+') return 62;
  if (c == '/') return 63;
  if (c == '=') return 0;
  return -1;
}


//
//
//
void nb64ChunkFor3Characters(char *buf, const char *inBuf, NSUInteger theLength)
{
  if (theLength >= 3)
    {
      buf[0] = basis_64[inBuf[0]>>2 & 0x3F];
      buf[1] = basis_64[(((inBuf[0] & 0x3)<< 4) | ((inBuf[1] & 0xF0) >> 4)) & 0x3F];
      buf[2] = basis_64[(((inBuf[1] & 0xF) << 2) | ((inBuf[2] & 0xC0) >>6)) & 0x3F];
      buf[3] = basis_64[inBuf[2] & 0x3F];
    }
  else if(theLength == 2)
    {
      buf[0] = basis_64[inBuf[0]>>2 & 0x3F];
      buf[1] = basis_64[(((inBuf[0] & 0x3)<< 4) | ((inBuf[1] & 0xF0) >> 4)) & 0x3F];
      buf[2] = basis_64[(((inBuf[1] & 0xF) << 2) | ((0 & 0xC0) >>6)) & 0x3F];
      buf[3] = '=';
    }
  else
    {
      buf[0] = basis_64[inBuf[0]>>2 & 0x3F];
      buf[1] = basis_64[(((inBuf[0] & 0x3)<< 4) | ((0 & 0xF0) >> 4)) & 0x3F];
      buf[2] = '=';
      buf[3] = '=';
    }
}
