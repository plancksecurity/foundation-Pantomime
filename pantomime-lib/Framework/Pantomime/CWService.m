/*
**  CWService.m
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

#import "Pantomime/CWService.h"
#import "CWService+Protected.h"

#import "Pantomime/CWConstants.h"
#import "Pantomime/NSData+Extensions.h"
#import "Pantomime/CWLogger.h"

#import <Foundation/NSBundle.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSPathUtilities.h>

#import <stdlib.h>
#import <string.h>

#import "CWTCPConnection.h"
#import "CWThreadSafeArray.h"
#import "CWThreadSaveData.h"

@interface CWService ()
@property (nonatomic, nullable, strong) id<CWLogging> logger;
@end

//
//
//
@implementation CWService

//
//
//
+ (BOOL)accessInstanceVariablesDirectly
{
    return NO;
}


//
//
//
- (id) init
{
  self = [super init];

    if (self) {
        _supportedMechanisms = [[CWThreadSafeArray alloc] init];
        _responsesFromServer = [[CWThreadSafeArray alloc] init];
        _capabilities = [[CWThreadSafeArray alloc] init];
        _queue = [[CWThreadSafeArray alloc] init];
        _username = nil;
        _password = nil;

        _rbuf = [CWThreadSaveData new];
        _wbuf = [CWThreadSaveData new];

        _runLoopModes = [[CWThreadSafeArray alloc] initWithArray:@[NSDefaultRunLoopMode]];
        _connectionTimeout = _readTimeout = _writeTimeout = DEFAULT_TIMEOUT;
        _counter = _lastCommand = 0;

        _connection_state.previous_queue = [[NSMutableArray alloc] init];
        _connection_state.reconnecting = _connection_state.opening_mailbox = NO;
    }

  return self;
}


//
//
//
- (id) initWithName: (NSString *) theName
               port: (unsigned int) thePort
          transport: (ConnectionTransport) transport
{
    self = [self init];

    [self setName: theName];
    [self setPort: thePort];
    _connectionTransport = transport;

    return self;
}

//
//
//
- (void) dealloc
{
  //INFO(NSStringFromClass([self class]), @"Service: -dealloc");
  [self setDelegate: nil];

  RELEASE(_supportedMechanisms);
  RELEASE(_responsesFromServer);
  RELEASE(_capabilities);

  RELEASE(_queue);

  RELEASE(_rbuf);
  RELEASE(_wbuf);

  TEST_RELEASE(_mechanism);
  TEST_RELEASE(_username);
  TEST_RELEASE(_password);
  RELEASE(_name);
  
  TEST_RELEASE(_connection);
  RELEASE(_runLoopModes);

  RELEASE(_connection_state.previous_queue);
}


//
// access / mutation methods
//
- (void) setDelegate: (id _Nullable) theDelegate
{
    @synchronized (self) {
        if (_delegate != theDelegate) {
            _delegate = theDelegate;
        }
    }
}

- (id) delegate
{
    @synchronized (self) {
        return _delegate;
    }
}


//
//
//
- (unsigned int) port
{
    @synchronized (self) {
        return _port;
    }
}


//
//
//
- (NSArray *) supportedMechanisms
{
    @synchronized (self) {
        return [_supportedMechanisms array];
    }
}


//
// Other methods
//
- (void) authenticate: (NSString *) theUsername
             password: (NSString *) thePassword
            mechanism: (NSString *) theMechanism
{
  [self subclassResponsibility: _cmd];
}


//
//
//
- (void) cancelRequest
{
    dispatch_sync(self.serviceQueue, ^{
        [self nullifyQueues];
        [_connection close];
        DESTROY(_connection);
        [_queue removeAllObjects];

        POST_NOTIFICATION(PantomimeRequestCancelled, self, nil);
        PERFORM_SELECTOR_1(_delegate, @selector(requestCancelled:), PantomimeRequestCancelled);
    });
}


//
//
//
- (void) close
{
    dispatch_sync(self.serviceQueue, ^{
        [self nullifyQueues];
        //
        // If we are reconnecting, no matter what, we close and release our current connection immediately.
        // We do that since we'll create a new on in -connect/-connectInBackgroundAndNotify. No need
        // to return immediately since _connected will be set to NO in _removeWatchers.
        //
        if (_connection_state.reconnecting)
        {
            [_connection close];
            DESTROY(_connection);
        }

        if (_connected)
        {
            _connected = NO;
            [_connection close];

            POST_NOTIFICATION(PantomimeConnectionTerminated, self, nil);
            PERFORM_SELECTOR_1(_delegate, @selector(connectionTerminated:), PantomimeConnectionTerminated);
        } else {
            INFO(NSStringFromClass(self.class), @"CWService.close: Double invocation");
        }
        
        [_connection setDelegate:nil];
        _connection = nil;
    });
}


//
//
//
- (void) connectInBackgroundAndNotify
{
    dispatch_sync(self.serviceQueue, ^{
        _connection = [[CWTCPConnection alloc] initWithName: _name
                                                       port: _port
                                                  transport: _connectionTransport
                                                 background: YES];

        if (!_connection)
        {
            POST_NOTIFICATION(PantomimeConnectionTimedOut, self, nil);
            PERFORM_SELECTOR_1(_delegate, @selector(connectionTimedOut:),  PantomimeConnectionTimedOut);
            return;
        }

        _connection.delegate = self;
        [_connection connect];
    });
}


//
//
//
- (NSDate *) timedOutEvent: (void *) theData
		      type: (RunLoopEventType) theType
		   forMode: (NSString *) theMode
{
  //INFO(NSStringFromClass([self class]), @"timed out event!");
  return nil;
}


//
//
//
- (void) startTLS
{
    [self subclassResponsibility: _cmd];
}


//
//
//
- (NSSet *) capabilities
{
    @synchronized (self) {
        return [[NSSet alloc] initWithArray:[_capabilities array]];
    }
}

@end
