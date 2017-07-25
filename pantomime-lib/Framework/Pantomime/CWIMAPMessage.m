/*
 **  CWIMAPMessage.m
 **
 **  Copyright (c) 2001-2007
 **                2014
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

#import "Pantomime/CWIMAPMessage.h"

#import "Pantomime/CWConstants.h"
#import "Pantomime/CWFlags.h"
#import "Pantomime/CWIMAPFolder.h"
#import "Pantomime/CWIMAPStore.h"

#import <Foundation/NSException.h>
#import <Foundation/NSValue.h>

//
//
//
@implementation CWIMAPMessage

- (id) init
{
    self = [super init];
    _headers_were_prefetched = NO;
    _UID = 0;
    return self;
}


//
// NSCoding protocol
//
- (void) encodeWithCoder: (NSCoder *) theCoder
{
    // Must also encode Message's superclass
    [super encodeWithCoder: theCoder];
    [theCoder encodeObject: [NSNumber numberWithInteger: _UID]];
}


//
//
//
- (id) initWithCoder: (NSCoder *) theCoder
{
    // Must also decode Message's superclass
    self = [super initWithCoder: theCoder];
    _UID = (NSUInteger)[[theCoder decodeObject] unsignedIntValue];
    return self;
}


//
//
//
- (NSUInteger) UID
{
    return _UID;
}

- (void) setUID: (NSUInteger) theUID
{
    _UID = theUID;
}


//
// This method is called to initialize the message if it wasn't.
// If we set it to NO and we HAD a content, we release the content.
//
- (void) setInitialized: (BOOL) theBOOL
{
    [super setInitialized: theBOOL];

    if (!theBOOL)
    {
        DESTROY(_content);
        return;
    }
    else if (![(CWIMAPFolder *)[self folder] selected])
    {
        [super setInitialized: NO];
        [NSException raise: PantomimeProtocolException
                    format: @"Unable to fetch message content from unselected mailbox."];
        return;
    }

    _headers_were_prefetched = YES;
    [super setInitialized: YES];
}

//
//
//
- (NSData *) rawSource
{
    if (![(CWIMAPFolder *)[self folder] selected])
    {
        [NSException raise: PantomimeProtocolException
                    format: @"Unable to fetch message data from unselected mailbox."];
        return _rawSource;
    }

    if (!_rawSource)
    {
        [(CWIMAPStore *)[[self folder] store] sendCommand: IMAP_UID_FETCH_RFC822  info: nil  arguments: @"UID FETCH %u:%u RFC822", _UID, _UID];
    }

    return _rawSource;
}


//
//
//
- (void) setFlags: (CWFlags *) theFlags
{
    [[self folder] setFlags: theFlags
                   messages: [NSArray arrayWithObject: self]];
}

@end
