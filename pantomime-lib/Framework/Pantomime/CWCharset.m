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

static NSDictionary *charset_instance_cache = nil;
static NSString *default_charset = @"iso-8859-1";

//
//
//
@implementation CWCharset

+ (void) initialize
{
  if (!charset_instance_cache)
    {
        charset_instance_cache = [NSDictionary
                                  dictionaryWithObjectsAndKeys:[CWISO8859_2 new], @"iso-8859-2",
                                  [CWISO8859_3 new], @"iso-8859-3",
                                  [CWISO8859_4 new], @"iso-8859-4",
                                  [CWISO8859_5 new], @"iso-8859-5",
                                  [CWISO8859_6 new], @"iso-8859-6",
                                  [CWISO8859_7 new], @"iso-8859-7",
                                  [CWISO8859_8 new], @"iso-8859-8",
                                  [CWISO8859_9 new], @"iso-8859-9",
                                  [CWISO8859_10 new], @"iso-8859-10",
                                  [CWISO8859_11 new], @"iso-8859-11",
                                  [CWISO8859_13 new], @"iso-8859-13",
                                  [CWISO8859_14 new], @"iso-8859-14",
                                  [CWISO8859_15 new], @"iso-8859-15",
                                  [CWKOI8_R new], @"koi8-r",
                                  [CWKOI8_U new], @"koi8-u",
                                  [CWWINDOWS_1250 new], @"windows-1250",
                                  [CWWINDOWS_1251 new], @"windows-1251",
                                  [CWWINDOWS_1252 new], @"windows-1252",
                                  [CWWINDOWS_1253 new], @"windows-1253",
                                  [CWWINDOWS_1254 new], @"windows-1254",
                                  [CWISO8859_1 new], default_charset,
                                  nil];
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
    CWCharset *theCharset = [charset_instance_cache objectForKey: [theName lowercaseString]];
    if (theCharset == nil) {
        theCharset = [charset_instance_cache objectForKey:default_charset];
    }
    return theCharset;
}

@end
