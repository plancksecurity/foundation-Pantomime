/*
**  CWFolder.m
**
**  Copyright (c) 2001-2007
**                2013 Free Software Foundation
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

#import "CWFolder.h"

#import <Foundation/Foundation.h>

#import "CWConstants.h"
#import "Pantomime/CWContainer.h"
#import "CWFlags.h"
#import <PantomimeFramework/CWMessage.h>
#import "Pantomime/NSString+Extensions.h"

#if __APPLE__
#include "TargetConditionals.h"
#endif

@interface CWFolder ()

@property (nonatomic) NSMutableArray *allMessages;

@end

//
//
//
@implementation CWFolder 

- (id) initWithName: (NSString *) theName
{
  self = [super init];

  _properties = [[NSMutableDictionary alloc] init];
  _allVisibleMessages = nil;
  
  _allMessages = [[NSMutableArray alloc] init];
  
  _cacheManager = nil;
  _mode = PantomimeUnknownMode;

  [self setName: theName];
  [self setShowDeleted: NO];
  [self setShowRead: YES];

  return self;
}


//
//
//
- (void) dealloc
{
  //LogInfo("Folder: -dealloc");
  RELEASE(_properties);
  RELEASE(_name);

  //
  // To be safe, we set the value of the _folder ivar of all CWMessage
  // instances to nil value in case something is retaining them.
  //
  [_allMessages makeObjectsPerformSelector: @selector(setFolder:) withObject: nil];
  RELEASE(_allMessages);

  TEST_RELEASE(_allVisibleMessages);
  TEST_RELEASE(_cacheManager);

  //[super dealloc];
}


//
//!  NSCopying protocol
//
- (id) copyWithZone: (NSZone *) zone
{
  return RETAIN(self);
}


//
//
//
- (NSString *) name
{
  return _name;
}


//
//
//
- (void) setName: (NSString *) theName
{
  ASSIGN(_name, theName);
}


//
//
//
- (void) appendMessage: (CWMessage *) theMessage
{
  if (theMessage)
    {
      [_allMessages addObject: theMessage];
      
      if (_allVisibleMessages)
	{
	  [_allVisibleMessages addObject: theMessage];
	}
    }
}


//
//
//
- (void) appendMessageFromRawSource: (NSData *) theData
                              flags: (CWFlags *) theFlags
{
  [self subclassResponsibility: _cmd];
}


//
//
//
- (NSArray *) allMessages
{ 
  if (_allVisibleMessages == nil)
    {
      NSUInteger i, count;

      count = [_allMessages count];
      _allVisibleMessages = [[NSMutableArray alloc] initWithCapacity: count];

      // quick
      if (_show_deleted && _show_read)
	{
	  [_allVisibleMessages addObjectsFromArray: _allMessages];
	  return _allVisibleMessages;
	}

      for (i = 0; i < count; i++)
	{
	  CWMessage *aMessage;
	  
	  aMessage = [_allMessages objectAtIndex: i];
      
	  // We show or hide deleted messages
	  if (_show_deleted)
	    {
	      [_allVisibleMessages addObject: aMessage];
	    }
	  else
	    {
	      if ([[aMessage flags] contain: PantomimeFlagDeleted])
		{
		  // Do nothing
		  continue;
		}
	      else
		{
		  [_allVisibleMessages addObject: aMessage];
		}
	    }

	  // We show or hide read messages
	  if (_show_read)
	    {
	      if (![_allVisibleMessages containsObject: aMessage])
		{
		  [_allVisibleMessages addObject: aMessage];
		}
	    }
	  else
	    {
	      if ([[aMessage flags] contain: PantomimeFlagSeen])
		{
		  if (![[aMessage flags] contain: PantomimeFlagDeleted])
		    {
		      [_allVisibleMessages removeObject: aMessage];
		    }
		}
	      else if (![_allVisibleMessages containsObject: aMessage])
		{
		  [_allVisibleMessages addObject: aMessage];
		}
	    }
	}
    }

  return _allVisibleMessages;
}


//
//
//
- (void) setMessages: (NSArray *) theMessages
{
  if (theMessages)
    {
      RELEASE(allMessages);
      _allMessages = [[NSMutableArray alloc] initWithArray: theMessages];
    }
  else
    {
      DESTROY(_allMessages);
    }

  DESTROY(_allVisibleMessages);
}


//
//
//
- (CWMessage *) messageAtIndex: (NSUInteger) theIndex
{
  if (theIndex >= [self count])
    {
      return nil;
    }
  
  return [[self allMessages] objectAtIndex: theIndex];
}


//
//
//
- (NSUInteger) count
{
  return [[self allMessages] count];
}


//
//
//
- (void) close
{
  [self subclassResponsibility: _cmd];
  return;
}


//
//
//
- (void) expunge
{
  [self subclassResponsibility: _cmd];
}


//
//
//
- (id) store
{
  return _store;
}


//
// No need to retain the store here since our store object
// retains our folder object.
//
- (void) setStore: (id) theStore
{
  _store = theStore;
}


//
//
//
- (void) removeMessage: (CWMessage *) theMessage
{
  if (theMessage)
    {
      [_allMessages removeObject: theMessage];
      
      if (_allVisibleMessages)
	{
	  [_allVisibleMessages removeObject: theMessage];
	}
    }
}


//
//
//
- (BOOL) showDeleted
{
  return _show_deleted;
}


//
//
//
- (void) setShowDeleted: (BOOL) theBOOL
{
  if (theBOOL != _show_deleted)
    {
      _show_deleted = theBOOL;
      DESTROY(_allVisibleMessages);
    }
}


//
//
//
- (BOOL) showRead
{
  return _show_read;
}


//
//
//
- (void) setShowRead: (BOOL) theBOOL
{
  if (theBOOL != _show_read)
    {
      _show_read = theBOOL;
      DESTROY(_allVisibleMessages);
    }
}


//
//
//
- (NSUInteger) numberOfDeletedMessages
{
  NSUInteger c, i, count;
  
  c = [self count];
  count = 0;

  for (i = 0; i < c; i++)
    {
      if ([[(CWMessage *) [_allMessages objectAtIndex: i] flags] contain: PantomimeFlagDeleted])
	{
	  count++;
	}
    }

  return count;
}


//
//
//
- (NSUInteger) numberOfUnreadMessages
{
  NSUInteger i, c, count;
  
  c = [self count];
  count = 0;
  
  for (i = 0; i < c; i++)
    {
      if (![[(CWMessage *) [_allMessages objectAtIndex: i] flags] contain: PantomimeFlagSeen])
	{
	  count++;
	}
    }

  return count;
}


//
//
//
- (long) size;
{
  long size;
  NSUInteger c, i;

  c = [self count];
  size = 0;
  
  for (i = 0; i < c; i++)
    {
      size += [(CWMessage *)[_allMessages objectAtIndex: i] size];
    }

  return size;
  
}


//
//
//
- (void) updateCache
{
  DESTROY(_allVisibleMessages);
}

//
//
//
- (void) search: (NSString *) theString
	   mask: (PantomimeSearchMask) theMask
	options: (PantomimeSearchOption) theOptions
{
  [self subclassResponsibility: _cmd];
}


//
//
//
- (id) cacheManager
{
  return _cacheManager;
}

- (void) setCacheManager: (id) theCacheManager
{
  ASSIGN(_cacheManager, theCacheManager);
}


//
//
//
- (PantomimeFolderMode) mode
{
  return _mode;
}


//
//
//
- (void) setMode: (PantomimeFolderMode) theMode
{
  _mode = theMode;
}


//
//
//
- (void) setFlags: (CWFlags *) theFlags
         messages: (NSArray *) theMessages
{
  NSUInteger c, i;

  c = [theMessages count];
  for (i = 0; i < c; i++)
    {
      [(CWMessage *) [theMessages objectAtIndex: i] setFlags: theFlags];
    }
}


//
//
//
- (id) propertyForKey: (id) theKey
{
  return [_properties objectForKey: theKey];
}


//
//
//
- (void) setProperty: (id) theProperty
	      forKey: (id) theKey
{
  if (theProperty)
    {
      [_properties setObject: theProperty  forKey: theKey];
    }
  else
    {
      [_properties removeObjectForKey: theKey];
    }
}

@end
