/*
**  CWCharset.m
**
**  Copyright (c) 2001-2004
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

#import "Pantomime/CWCharset.h"

#import "CWConstants.h"
#import "Pantomime/CWISO8859_1.h"
#import "Pantomime/CWISO8859_2.h"
#import "Pantomime/CWISO8859_3.h"
#import "Pantomime/CWISO8859_4.h"
#import "Pantomime/CWISO8859_5.h"
#import "Pantomime/CWISO8859_6.h"
#import "Pantomime/CWISO8859_7.h"
#import "Pantomime/CWISO8859_8.h"
#import "Pantomime/CWISO8859_9.h"
#import "Pantomime/CWISO8859_10.h"
#import "Pantomime/CWISO8859_11.h"
#import "Pantomime/CWISO8859_13.h"
#import "Pantomime/CWISO8859_14.h"
#import "Pantomime/CWISO8859_15.h"
#import "Pantomime/CWKOI8_R.h"
#import "Pantomime/CWKOI8_U.h"
#import "Pantomime/CWWINDOWS_1250.h"
#import "Pantomime/CWWINDOWS_1251.h"
#import "Pantomime/CWWINDOWS_1252.h"
#import "Pantomime/CWWINDOWS_1253.h"
#import "Pantomime/CWWINDOWS_1254.h"

#import <Foundation/NSBundle.h>
#import <Foundation/NSDictionary.h>

static NSMutableDictionary *charset_instance_cache = nil;

//
//
//
@implementation CWCharset

+ (void) initialize
{
  if (!charset_instance_cache)
    {
      charset_instance_cache = [[NSMutableDictionary alloc] init];
    }
} 


//
//
//
- (id) initWithCodeCharTable: (const struct charset_code *) c
		      length: (int) n
{
  self = [super init];
  
  _codes = c;
  _num_codes = n; 
  _identity_map = 0x20;
  
  if (n > 0 && _codes[0].code == 0x20)
    {
      int i = 1;
      for (_identity_map=0x20;
	   i < _num_codes && _codes[i].code == _identity_map + 1 && _codes[i].value == _identity_map + 1;
	   _identity_map++,i++) ;
    }

  return self;
}


//
//!  what should this return for eg. \t and \n?
//
- (int) codeForCharacter: (unichar) theCharacter
{
  int i;

  if (theCharacter <= _identity_map)
    {
      return theCharacter;
    }
  
  for (i = 0; i < _num_codes; i++)
    {
      if (_codes[i].value == theCharacter)
	{
	  return _codes[i].code;
	}
    }
  
  return -1;
}


//
//
//
- (BOOL) characterIsInCharset: (unichar) theCharacter
{
  if (theCharacter <= _identity_map)
    {
      return YES;
    }

  if ([self codeForCharacter: theCharacter] != -1)
    {
      return YES;
    }
  
  return NO;
}


//
// Returns the name of the Charset. Like:
// "iso-8859-1"
// 
- (NSString *) name
{
  [self subclassResponsibility: _cmd];
  return nil;
}

//
// This method is used to obtain a charset from the name
// of this charset. It caches this charset for future
// usage when it's found.
//
+ (CWCharset *) charsetForName: (NSString *) theName
{
  CWCharset *theCharset;

  theCharset = [charset_instance_cache objectForKey: [theName lowercaseString]];

  if (!theCharset)
    {
      CWCharset *aCharset;
      
      if ([[theName lowercaseString] isEqualToString: @"iso-8859-2"])
	{
	  aCharset = (CWCharset *)[[CWISO8859_2 alloc] init];
	}
      else if ([[theName lowercaseString] isEqualToString: @"iso-8859-3"])
	{
	  aCharset = (CWCharset *)[[CWISO8859_3 alloc] init];
	}
      else if ([[theName lowercaseString] isEqualToString: @"iso-8859-4"])
	{
	  aCharset = (CWCharset *)[[CWISO8859_4 alloc] init];
	}
      else if ([[theName lowercaseString] isEqualToString: @"iso-8859-5"])
	{
	  aCharset = (CWCharset *)[[CWISO8859_5 alloc] init];
	}
      else if ([[theName lowercaseString] isEqualToString: @"iso-8859-6"])
	{
	  aCharset = (CWCharset *)[[CWISO8859_6 alloc] init];
	}
      else if ([[theName lowercaseString] isEqualToString: @"iso-8859-7"])
	{
	  aCharset = (CWCharset *)[[CWISO8859_7 alloc] init];
	}
      else if ([[theName lowercaseString] isEqualToString: @"iso-8859-8"])
	{
	  aCharset = (CWCharset *)[[CWISO8859_8 alloc] init];
	}
      else if ([[theName lowercaseString] isEqualToString: @"iso-8859-9"])
	{
	  aCharset = (CWCharset *)[[CWISO8859_9 alloc] init];
	}
      else if ([[theName lowercaseString] isEqualToString: @"iso-8859-10"])
	{
	  aCharset = (CWCharset *)[[CWISO8859_10 alloc] init];
 	}
      else if ([[theName lowercaseString] isEqualToString: @"iso-8859-11"])
	{
	  aCharset = (CWCharset *)[[CWISO8859_11 alloc] init];
	}
      else if ([[theName lowercaseString] isEqualToString: @"iso-8859-13"])
	{
	  aCharset = (CWCharset *)[[CWISO8859_13 alloc] init];
	}
      else if ([[theName lowercaseString] isEqualToString: @"iso-8859-14"])
	{
	  aCharset = (CWCharset *)[[CWISO8859_14 alloc] init];
	}
      else if ([[theName lowercaseString] isEqualToString: @"iso-8859-15"])
	{
	  aCharset = (CWCharset *)[[CWISO8859_15 alloc] init];
	}
      else if ([[theName lowercaseString] isEqualToString: @"koi8-r"])
	{
	  aCharset = (CWCharset *)[[CWKOI8_R alloc] init];
	}
      else if ([[theName lowercaseString] isEqualToString: @"koi8-u"])
	{
	  aCharset = (CWCharset *)[[CWKOI8_U alloc] init];
	}
      else if ([[theName lowercaseString] isEqualToString: @"windows-1250"])
	{
	  aCharset = (CWCharset *)[[CWWINDOWS_1250 alloc] init];
	}
      else if ([[theName lowercaseString] isEqualToString: @"windows-1251"])
	{
	  aCharset = (CWCharset *)[[CWWINDOWS_1251 alloc] init];
	}
      else if ([[theName lowercaseString] isEqualToString: @"windows-1252"])
	{
	  aCharset = (CWCharset *)[[CWWINDOWS_1252 alloc] init];
	}
      else if ([[theName lowercaseString] isEqualToString: @"windows-1253"])
	{
	  aCharset = (CWCharset *)[[CWWINDOWS_1253 alloc] init];
	}
      else if ([[theName lowercaseString] isEqualToString: @"windows-1254"])
	{
	  aCharset = (CWCharset *)[[CWWINDOWS_1254 alloc] init];
	}
      else
	{
	  aCharset = (CWCharset *)[[CWISO8859_1 alloc] init];
	}
      
      [charset_instance_cache setObject: aCharset
			      forKey: [theName lowercaseString]];
      RELEASE(aCharset);

      return aCharset;
    }

  return theCharset;
}

@end
