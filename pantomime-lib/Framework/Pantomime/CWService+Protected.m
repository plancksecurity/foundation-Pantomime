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
    @synchronized(self) {
        if (!_writeQueue) {
            _writeQueue = dispatch_queue_create("CWService - _writeQueue", DISPATCH_QUEUE_SERIAL);
        }
        return _writeQueue;
    }
}

/** Lazy initialized */
- (dispatch_queue_t _Nullable)serviceQueue;
{
    @synchronized(self) {
        if (!_serviceQueue) {
            _serviceQueue = dispatch_queue_create("CWService - _serviceQueue",
                                                  DISPATCH_QUEUE_SERIAL);
        }
        return _serviceQueue;
    }
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
    @synchronized(self) {
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

        //DDLogInfo("count = %d, len = %d", count, len);

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
//
//
- (void) write: (NSData *) theData
{
    [self writeInternalData:theData];
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
- (void)receivedEvent:(void * _Nullable)theData
                 type:(RunLoopEventType)theType
                extra:(void * _Nullable)theExtra
              forMode:(NSString * _Nullable)theMode;
{
    switch (theType) {
        case ET_RDESC:
            [self updateRead];
            break;
        case ET_WDESC:
            [self updateWrite];
            break;
        case ET_EDESC:
            //DDLogInfo("GOT ET_EDESC! %d  current fd = %d", theData, [_connection fd]);
            if (_connected) {
                if (theExtra) {
                    PERFORM_SELECTOR_2(_delegate,
                                       @selector(connectionLost:),
                                       PantomimeConnectionLost,
                                       (__bridge id _Nonnull) theExtra,
                                       PantomimeErrorExtra);
                } else {
                    PERFORM_SELECTOR_1(_delegate,
                                       @selector(connectionLost:),
                                       PantomimeConnectionLost);
                }
                [self close];
            } else {
                PERFORM_SELECTOR_1(_delegate, @selector(connectionTimedOut:),
                                   PantomimeConnectionTimedOut);
            }
            break;
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
    PERFORM_SELECTOR_1(_delegate, @selector(connectionEstablished:),
                       PantomimeConnectionEstablished);
}

@end
