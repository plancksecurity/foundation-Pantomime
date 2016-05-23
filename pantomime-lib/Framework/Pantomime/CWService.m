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

#import "Pantomime/CWConstants.h"
#import "Pantomime/NSData+Extensions.h"
#import "Pantomime/CWLogging.h"

#import <Foundation/NSBundle.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSPathUtilities.h>

#import <stdlib.h>
#import <string.h>

#import "CWTCPConnection.h"

//
// It's important that the read buffer be bigger than the PMTU. Since almost all networks
// permit 1500-byte packets and few permit more, the PMTU will generally be around 1500.
// 2k is fine, 4k accomodates FDDI (and HIPPI?) networks too.
//
#define NET_BUF_SIZE 4096 

//
// We set the size increment of blocks we will write. Under Mac OS X, we use 1024 bytes
// in order to avoid a strange bug in SSL_write. This prevents us from no longer beeing
// notified after a couple of writes that we can actually write data!
//
#define WRITE_BLOCK_SIZE 1024


//
// Default timeout used when waiting for something to complete.
//
#define DEFAULT_TIMEOUT 60

@interface CWService ()

@property (nonatomic) ConnectionTransport connectionTransport;
@property (nonatomic, nullable, strong) id<CWLogging> logger;

@end

//
//
//
@implementation CWService

//
//
//
- (id) init
{
  self = [super init];

  _supportedMechanisms = [[NSMutableArray alloc] init];
  _responsesFromServer = [[NSMutableArray alloc] init];
  _capabilities = [[NSMutableArray alloc] init];
  _queue = [[NSMutableArray alloc] init];
  _username = nil;
  _password = nil;


  _rbuf = [[NSMutableData alloc] init];
  _wbuf = [[NSMutableData alloc] init];

  _runLoopModes = [[NSMutableArray alloc] initWithObjects: NSDefaultRunLoopMode, nil];
  _connectionTimeout = _readTimeout = _writeTimeout = DEFAULT_TIMEOUT;
  _counter = _lastCommand = 0;

  _connection_state.previous_queue = [[NSMutableArray alloc] init];
  _connection_state.reconnecting = _connection_state.opening_mailbox = NO;

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
    self.connectionTransport = transport;

    return self;
}

//
//
//
- (void) dealloc
{
  //NSLog(@"Service: -dealloc");
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

  //[super dealloc];
}

//
// access / mutation methods
//
- (void) setDelegate: (id _Nullable) theDelegate
{
  _delegate = theDelegate;
}

- (id) delegate
{
  return _delegate;
}


//
//
//
- (NSString *) name
{
  return _name;
}

- (void) setName: (NSString *) theName
{
  ASSIGN(_name, theName);
}


//
//
//
- (unsigned int) port
{
  return _port;
}

- (void) setPort: (unsigned int) thePort
{
  _port = thePort;
}


//
//
//
- (id<CWConnection>) connection
{
  return _connection;
}


//
//
//
- (NSArray *) supportedMechanisms
{
  return [NSArray arrayWithArray: _supportedMechanisms];
}


//
//
//
- (NSString *) username
{
  return _username;
}

- (void) setUsername: (NSString *) theUsername
{
  ASSIGN(_username, theUsername);
}


//
//
//
- (BOOL) isConnected
{
  return _connected;
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
  // If we were in the process of establishing
  // a connection, let's stop our internal timer.
  [_timer invalidate];
  DESTROY(_timer);

  [_connection close];
  DESTROY(_connection);
  [_queue removeAllObjects];

  POST_NOTIFICATION(PantomimeRequestCancelled, self, nil);
  PERFORM_SELECTOR_1(_delegate, @selector(requestCancelled:), PantomimeRequestCancelled);
}


//
//
//
- (void) close
{
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
      [_connection close];

      POST_NOTIFICATION(PantomimeConnectionTerminated, self, nil);
      PERFORM_SELECTOR_1(_delegate, @selector(connectionTerminated:), PantomimeConnectionTerminated);
    }
}

// 
// If the connection or binding succeeds, zero  is  returned.
// On  error, -1 is returned, and errno is set appropriately
//
- (int) connect
{
    _connection = [[CWTCPConnection alloc] initWithName: _name
                                                 port: _port
                                            transport: self.connectionTransport
                                           background: NO];

    _connection.logger = self.logger;

    if (!_connection)
    {
        return -1;
    }

    _connection.delegate = self;
    [_connection connect];

    return 0;
}


//
//
//
- (void) connectInBackgroundAndNotify
{
    _connection = [[CWTCPConnection alloc] initWithName: _name
                                                 port: _port
                                            transport: self.connectionTransport
                                           background: YES];

    _connection.logger = self.logger;

    if (!_connection)
    {
        POST_NOTIFICATION(PantomimeConnectionTimedOut, self, nil);
        PERFORM_SELECTOR_1(_delegate, @selector(connectionTimedOut:),  PantomimeConnectionTimedOut);
        return;
    }

    _connection.delegate = self;
    [_connection connect];
}

- (void)connectionEstablished
{
    _connected = YES;
    POST_NOTIFICATION(PantomimeConnectionEstablished, self, nil);
    PERFORM_SELECTOR_1(_delegate, @selector(connectionEstablished:),
                       PantomimeConnectionEstablished);
}

//
//
//
- (void) noop
{
  [self subclassResponsibility: _cmd];
}


//
//
//
- (void) updateRead
{
  unsigned char buf[NET_BUF_SIZE];
  NSInteger count;
  
  while ((count = [_connection read: buf  length: NET_BUF_SIZE]) > 0)
    {
      NSData *aData;

      aData = [[NSData alloc] initWithBytes: buf  length: count];

      if (_delegate && [_delegate respondsToSelector: @selector(service:receivedData:)])
	{
	  [_delegate performSelector: @selector(service:receivedData:)
		     withObject: self
		     withObject: aData];  
	}

      [_rbuf appendData: aData];
      RELEASE(aData);
    }

  if (count == 0)
  {
      //
      // We check to see if we got disconnected.
      //
      if (_connection.streamError)
      {
          [_connection close];
          POST_NOTIFICATION(PantomimeConnectionLost, self, nil);
          PERFORM_SELECTOR_1(_delegate, @selector(connectionLost:),  PantomimeConnectionLost);
      }
  }
  else
  {
      // We reset our connection timeout counter. This could happen when we are performing operations
      // that return a large amount of data. The queue might be non-empty but network I/O could be
      // going on at the same time. This could also be problematic for lenghty IMAP search or
      // mailbox preload.
      _counter = 0;
  }
}
 
 
//
//
//
- (void) updateWrite
{
  if ([_wbuf length] > 0)
    {
      unsigned char *bytes;
      NSInteger count, len;

      bytes = [_wbuf mutableBytes];
      len = [_wbuf length];

#ifdef MACOSX
      count = [_connection write: bytes  length: len > WRITE_BLOCK_SIZE ? WRITE_BLOCK_SIZE : len];
#else
      count = [_connection write: bytes  length: len];
#endif
      // If nothing was written or if an error occured, we return.
      if (count <= 0)
	{
	  return;
	}
      // Otherwise, we inform our delegate that we wrote some data...
      else if (_delegate && [_delegate respondsToSelector: @selector(service:sentData:)])
	{
	  [_delegate performSelector: @selector(service:sentData:)
		     withObject: self
		     withObject: [_wbuf subdataToIndex: (int) count]];
	}
      
      //NSLog(@"count = %d, len = %d", count, len);

      // If we have been able to write everything...
      if (count == len)
	{
	  [_wbuf setLength: 0];
	}
      else
	{
	  memmove(bytes, bytes+count, len-count);
	  [_wbuf setLength: len-count];
	}
    }
}


/**
 This can potentially be called from arbitrary threads, so acces has to be
 synchronized.
 */
- (void) writeData: (NSData *) theData
{
    dispatch_block_t block = ^{
        if (theData && [theData length])
        {
            [_wbuf appendData: theData];

            //
            // Let's not try to enable the write callback if we are not connected
            // There's no reason to try to enable the write callback if we
            // are not connected.
            //
            if (!_connected)
            {
                return;
            }

            // If possible, we write immediately
            if ([_connection canWrite]) {
                [self updateWrite];
            }
        }
    };
    if ([NSThread currentThread] != [NSThread mainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            block();
        });
    } else {
        block();
    }
}


//
// RunLoopEvents protocol's implementations.
//
- (void) receivedEvent: (void *) theData
                  type: (RunLoopEventType) theType
                 extra: (void *) theExtra
               forMode: (NSString *) theMode
{
  AUTORELEASE_VOID(RETAIN(self));    // Don't be deallocated while handling event
  switch (theType)
    {
#ifdef __MINGW32__
    case ET_HANDLE:
    case ET_TRIGGER:
      [self updateRead];
      [self updateWrite];
      break;
#else
    case ET_RDESC:
      [self updateRead];
      break;

    case ET_WDESC:
      [self updateWrite];
      break;

    case ET_EDESC:
      //NSLog(@"GOT ET_EDESC! %d  current fd = %d", theData, [_connection fd]);
            if (_connected) {
                POST_NOTIFICATION(PantomimeConnectionLost, self, nil);
                PERFORM_SELECTOR_1(_delegate, @selector(connectionLost:),  PantomimeConnectionLost);
            } else {
                POST_NOTIFICATION(PantomimeConnectionTimedOut, self, nil);
                PERFORM_SELECTOR_1(_delegate, @selector(connectionTimedOut:),
                                   PantomimeConnectionTimedOut);
            }
      break;
#endif

    default:
      break;
    }
}


//
//
//
- (int) reconnect
{
  [self subclassResponsibility: _cmd];
  return 0;
}


//
//
//
- (NSDate *) timedOutEvent: (void *) theData
		      type: (RunLoopEventType) theType
		   forMode: (NSString *) theMode
{
  //NSLog(@"timed out event!");
  return nil;
}


//
//
//
- (void) addRunLoopMode: (NSString *) theMode
{
#ifndef MACOSX
  if (theMode && ![_runLoopModes containsObject: theMode])
    {
      [_runLoopModes addObject: theMode];
    }
#endif
}


//
//
//
- (unsigned int) connectionTimeout
{
  return _connectionTimeout;
}

- (void) setConnectionTimeout: (unsigned int) theConnectionTimeout
{
  _connectionTimeout = (theConnectionTimeout > 0 ? theConnectionTimeout : DEFAULT_TIMEOUT);
}

- (unsigned int) readTimeout
{
  return _readTimeout;
}

- (void) setReadTimeout: (unsigned int) theReadTimeout
{
  _readTimeout = (theReadTimeout > 0 ? theReadTimeout: DEFAULT_TIMEOUT);
}

- (unsigned int) writeTimeout
{
  return _writeTimeout;
}

- (void) setWriteTimeout: (unsigned int) theWriteTimeout
{
  _writeTimeout = (theWriteTimeout > 0 ? theWriteTimeout : DEFAULT_TIMEOUT);
}

- (void) startTLS
{
  [self subclassResponsibility: _cmd];
}

- (unsigned int) lastCommand
{
  return _lastCommand;
}

- (NSArray *) capabilities
{
  return _capabilities;
}

@end