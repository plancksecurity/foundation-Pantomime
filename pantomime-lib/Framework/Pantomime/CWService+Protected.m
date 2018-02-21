//
//  CWService+Protected.m
//  Pantomime
//
//  Created by Andreas Buff on 05.09.17.
//  Copyright © 2017 pEp Security S.A. All rights reserved.
//

#import "CWService+Protected.h"
#import "CWService.h"

#import "CWThreadSafeData.h"
#import "CWTCPConnection.h"

@implementation CWService (Protected)

/** Lazy initialized */
- (dispatch_queue_t _Nullable)writeQueue;
{
    if (!_writeQueue) {
        _writeQueue = dispatch_queue_create("CWService - _writeQueue", DISPATCH_QUEUE_SERIAL);
    }

    return _writeQueue;
}

/** Lazy initialized */
- (dispatch_queue_t _Nullable)readQueue;
{
    if (!_readQueue) {
        _readQueue = dispatch_queue_create("CWService - _readQueue", DISPATCH_QUEUE_SERIAL);
    }

    return _readQueue;
}


/** Lazy initialized */
- (dispatch_queue_t _Nullable)serviceQueue;
{
    if (!_serviceQueue) {
        _serviceQueue = dispatch_queue_create("CWService - _serviceQueue", DISPATCH_QUEUE_SERIAL);
    }

    return _serviceQueue;
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
- (void) updateWrite
{
    if ([_wbuf length] == 0)
    {
        return;
    }
    unsigned char *bytes;
    NSInteger count, len;

    bytes = (unsigned char*)[_wbuf copyOfBytes];
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

    //INFO(NSStringFromClass([self class]), @"count = %d, len = %d", count, len);

    // If we have been able to write everything...
    if (count == len)
    {
        [_wbuf reset];
    }
    else
    {
        [_wbuf truncateLeadingBytes:count];
    }
}


//
//
//
- (NSString *) username
{
    return _username;
}


//
//
//
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
// If the connection or binding succeeds, zero  is  returned.
// On  error, -1 is returned, and errno is set appropriately
//
- (int) connect
{
    _connection = [[CWTCPConnection alloc] initWithName: _name
                                                   port: _port
                                              transport: _connectionTransport
                                             background: NO];

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
- (void) write: (NSData *) theData
{
    NSThread *backgroundThread = ((CWTCPConnection *) _connection).backgroundThread;
    if ([NSThread currentThread] != backgroundThread) {
        [self performSelector:@selector(writeInternalData:) onThread:backgroundThread
                   withObject:theData waitUntilDone:YES];
    } else {
        [self writeInternalData:theData];
    }
}


//
//
//
- (void) writeData: (NSData *_Nonnull) theData;
{
    [self bulkWriteData:@[theData]];
}


//
//
//
- (void) bulkWriteData: (NSArray<NSData*> *_Nonnull) bulkData;
{
    dispatch_sync(self.writeQueue, ^{
        for (NSData *data in bulkData) {
            [self write:data];
        }
    });
}


//
//
//
- (void) writeInternalData: (NSData *) theData
{
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


//
//
//
- (void) setConnectionTimeout: (unsigned int) theConnectionTimeout
{
    _connectionTimeout = (theConnectionTimeout > 0 ? theConnectionTimeout : DEFAULT_TIMEOUT);
}


//
//
//
- (unsigned int) readTimeout
{
    return _readTimeout;
}


//
//
//
- (void) setReadTimeout: (unsigned int) theReadTimeout
{
    _readTimeout = (theReadTimeout > 0 ? theReadTimeout: DEFAULT_TIMEOUT);
}


//
//
//
- (unsigned int) writeTimeout
{
    return _writeTimeout;
}


//
//
//
- (void) setWriteTimeout: (unsigned int) theWriteTimeout
{
    _writeTimeout = (theWriteTimeout > 0 ? theWriteTimeout : DEFAULT_TIMEOUT);
}


//
//
//
- (unsigned int) lastCommand
{
    return _lastCommand;
}


//
//
//
- (void)nullifyQueues
{
    _writeQueue = nil;
    _serviceQueue = nil;
}

#pragma mark - CWConnectionDelegate

/**
 //  RunLoopEvents protocol's implementations.
 //
 //  @discussion This method is automatically invoked when the receiver can
 //              either read or write bytes to its underlying CWConnection
 //	      instance. Never call this method directly.
 //  @param theData The file descriptor.
 //  @param theType The type of event that occured.
 //  @param theExtra Additional information.
 //  @param theMode The runloop modes.
 //*/
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
            //INFO(NSStringFromClass([self class]), @"GOT ET_EDESC! %d  current fd = %d", theData, [_connection fd]);
            if (_connected) {
                POST_NOTIFICATION(PantomimeConnectionLost, self, nil);
                PERFORM_SELECTOR_1(_delegate, @selector(connectionLost:),  PantomimeConnectionLost);
                [self close];
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
- (void)connectionEstablished
{
    _connected = YES;
    POST_NOTIFICATION(PantomimeConnectionEstablished, self, nil);
    PERFORM_SELECTOR_1(_delegate, @selector(connectionEstablished:),
                       PantomimeConnectionEstablished);
}

@end
