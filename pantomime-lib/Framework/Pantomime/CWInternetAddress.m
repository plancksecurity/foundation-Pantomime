/*
**  CWInternetAddress.m
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
#import "CWInternetAddress.h"

#import "CWConstants.h"
#import "CWMIMEUtility.h"
#import "Pantomime/NSString+Extensions.h"

//#import "Pantomime/elm_defs.h>

#import <Foundation/Foundation.h>

//
//
//
@implementation CWInternetAddress : NSObject

- (id) initWithString: (NSString *) theString
{
  NSInteger a, b;

  self = [super init];
  
  if (!theString)
    {
      AUTORELEASE_VOID(self);
      return nil;
    }
  
  // Some potential addresses:
  //
  // Ludovic Marcotte <ludovic@Sophos.ca>
  // ludovic@Sophos.ca
  // <ludovic@Sophos.ca>
  // "Marcotte, Ludovic" <ludovic@Sophos.ca>
  // "Joe" User <joe@acme.com>
  //
//!  also support "joe@acme.com (Joe User)"

  a = [theString indexOfCharacter: '<'];

  if (a >= 0)
    {
      b = [theString indexOfCharacter: '>'  fromIndex: a+1];

      // If the trailing '>' is missing, then just take the rest of the string
      if (b < 0)
	{
	  b = [theString length];
	}
      
      [self setAddress: [theString substringWithRange: NSMakeRange(a+1,b-a-1)]];
	  
      if (a > 0)
	{
	  NSInteger c, d;

	  c = [theString indexOfCharacter: '"'];

	  if (c >= 0)
	    {
	      d = [theString indexOfCharacter: '"'  fromIndex: c+1];
	      
	      //
	      // We make sure we check this. We could get something like:
	      // Joe" User <joe@acme.com>
	      //
	      if (d > c)
		{
		  BOOL b;
		  
		  b = YES;
		  
		  //
		  // Check if between d and a there is only whitespace, this covers
		  // cases like: "Joe" User <joe@acme.com>"
		  //
		  if (d < a)
		    {
		      unichar buf[[theString length]];
		      unsigned idx;
		      
		      [theString getCharacters: buf range: NSMakeRange(d+1, a-d)];
		      idx = 0;
		      while (b && idx < a-d)
			{
			  b = isspace(buf[idx]);
			  idx++;
			}
		    }
		  
		  if (b)
		    {
		      [self setPersonal: [theString substringWithRange: NSMakeRange(c+1,d-c-1)]];
		    }
		  else
		    {
		      [self setPersonal: [[theString substringWithRange: NSMakeRange(0,a)]
					   stringByTrimmingWhiteSpaces]];
		    }
		}
	    }
	  else
	    {
	      [self setPersonal: [[theString substringWithRange: NSMakeRange(0,a)]
				   stringByTrimmingWhiteSpaces]];
	    }
	}
    }
  else
    {
      [self setAddress: theString];
    }

    // Remove trailing back slashes.
    NSString *addressString = [self.address stringFromQuotedString];
    while ([addressString hasSuffix:@"\\"]) {
        NSUInteger lastIndex = addressString.length - 1;
        if (lastIndex > 0) {
            lastIndex -= 1;
        }
        addressString = [addressString substringToIndex:lastIndex];
    }

    if (addressString.length == 0) {
        return nil;
    } else {
        self.address = addressString;
        return self;
    }
}

//
//
//
- (id) initWithPersonal: (NSString *) thePersonal
		address: (NSString *) theAddress
{
  self = [super init];
  
  [self setPersonal: thePersonal];
  [self setAddress: theAddress];

  return self;
}

- (id) initWithPersonal: (NSString *) thePersonal
                address: (NSString *) theAddress
                   type: (PantomimeRecipientType) theType
{
    if (self = [self initWithPersonal:thePersonal address:theAddress]) {
        [self setType: theType];
    }
    return self;
}

//
//
//
- (void) dealloc
{
  RELEASE(_address);
  RELEASE(_personal);
  //[super dealloc];
}


//
// NSCoding protocol
//
- (void) encodeWithCoder: (NSCoder *) theCoder
{
  [theCoder encodeObject: [NSNumber numberWithInteger:_type]];
  [theCoder encodeObject: _address];
  [theCoder encodeObject: [self personal]];
}

- (id) initWithCoder: (NSCoder *) theCoder
{
  self = [super init];

  [self setType: [[theCoder decodeObject] intValue]];
  [self setAddress: [theCoder decodeObject]];
  [self setPersonal: [theCoder decodeObject]];

  return self;
}


//
//
//
- (NSString *) address
{
  return _address;
}

- (void) setAddress: (NSString *) theAddress
{
  ASSIGN(_address, theAddress);
}


//
//
//
- (NSString *) personal
{
  return _personal;
}

- (void) setPersonal: (NSString *) thePersonal
{
    // Avoid quoting nil (leading to @"(null)", and also the empty string,
    // which would produce @"\"".
    if (thePersonal && thePersonal.length > 0) {
        // Assure the name is quoted
        if (![thePersonal hasPrefix: @"\""]) {
            thePersonal = [NSString stringWithFormat: @"\"%@", thePersonal];
        }

        if (![thePersonal hasSuffix: @"\""]) {
            thePersonal = [NSString stringWithFormat: @"%@\"", thePersonal];
        }
    }

  ASSIGN(_personal, thePersonal);
}


//
//
//
- (PantomimeRecipientType) type 
{
  return _type;
}

- (void) setType: (PantomimeRecipientType) theType
{
  _type = theType;
}


//
//
//
- (NSData *) dataValue
{
  if ([self personal] && [[self personal] length] > 0)
    {
      NSMutableData *aMutableData;

      aMutableData = [[NSMutableData alloc] init];

      [aMutableData appendData: [CWMIMEUtility encodeWordUsingQuotedPrintable: [self personal] prefixLength: 0]];

      if (_address)
	{
	  [aMutableData appendBytes: " <"  length: 2];
	  [aMutableData appendData: [_address dataUsingEncoding: NSASCIIStringEncoding]];
	  [aMutableData appendBytes: ">" length: 1];
	}

      return AUTORELEASE(aMutableData);
    }
  else
    {
      return [_address dataUsingEncoding: NSASCIIStringEncoding];
    }
}

//
//
//
- (NSString *) stringValue
{
  if ([self personal] && [[self personal] length] > 0)
    {
      if (_address)
	{
	  return [NSString stringWithFormat: @"%@ <%@>", [self personal], _address];
	}
      else
	{
	  return [NSString stringWithFormat: @"%@", [self personal]];
	}
    }
  else
    {
      return _address;
    }
}

//
//
//
- (NSComparisonResult) compare: (id) theAddress
  
{
  return [[self stringValue] compare: [(NSObject *)theAddress valueForKey: @"stringValue"]];
}

//
//
//
- (BOOL) isEqualToAddress: (CWInternetAddress *) theAddress
{
  if (![theAddress isMemberOfClass: [self class]])
    {
      return NO;
    }

  return [_address isEqualToString: [theAddress address]];
}


//
// For debugging support
//
- (NSString *) description
{
  return [NSString stringWithFormat:@"%@ (%d)", [self stringValue], (int) self.type];
}

//
// For scripting support 
//
- (id) container
{
  return _container;
}

- (void) setContainer: (id) theContainer
{
  _container = theContainer;
}
@end


//
// For scripting support 
//
@implementation ToRecipient

- (id) init
{
  self = [super init];
  [self setType: PantomimeToRecipient];
  return self;
}

@end


//
// For scripting support 
//
@implementation CcRecipient

- (id) init
{
  self = [super init];
  [self setType: PantomimeCcRecipient];
  return self;
}

@end


//
// For scripting support 
//
@implementation BccRecipient

- (id) init
{
  self = [super init];
  [self setType: PantomimeBccRecipient];
  return self;
}


@end


