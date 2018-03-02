//
//  CWService+Protected.h
//  Pantomime
//
//  Created by Andreas Buff on 05.09.17.
//  Copyright © 2017 pEp Security S.A. All rights reserved.
//

#import "CWService.h"

NS_ASSUME_NONNULL_BEGIN

@interface CWService ()
{
@protected
    __block CWThreadSafeArray *_supportedMechanisms;
    __block CWThreadSafeArray *_responsesFromServer;
    __block CWThreadSafeArray *_capabilities;
    __block CWThreadSafeArray *_runLoopModes;
    __block CWThreadSafeArray *_queue;
    __block CWThreadSafeData *_wbuf;
    __block CWThreadSafeData *_rbuf;
    __block NSString *_mechanism;
    __block NSString *_username;
    __block NSString *_password;
    __block NSString *_name;
    NSData *_crlf;
    NSStringEncoding _defaultCStringEncoding;
    
#ifdef MACOSX
    CFRunLoopSourceRef _runLoopSource;
    CFSocketContext *_context;
    CFSocketRef _socket;
#endif
    __block ConnectionTransport _connectionTransport;
    /** Used to serialize writes to the connection. As we serialize only public methods, pantomime and
     methods called form a client might write at the same time.*/
    dispatch_queue_t _writeQueue;
    /** Used to serialize the processing of received data.*/
    dispatch_queue_t _readQueue;
    /** Used to serialize public methods. They might be called from different threads concurrently. */
    dispatch_queue_t _serviceQueue;
    __block unsigned int _connectionTimeout;
    __block unsigned int _readTimeout;
    __block unsigned int _writeTimeout;
    __block unsigned int _lastCommand;
    __block unsigned int _port;
    __block BOOL _connected;
    __block id __weak _Nullable __block _delegate;

    __block id<CWConnection> _connection;
    __block int _counter;
    __block CWConnectionState *_connection_state;
}

@end

/**
 Protected methods of CWService.
 This header must not be accessable to clients.
 */
@interface CWService (Protected) <CWConnectionDelegate>

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

- (dispatch_queue_t _Nullable)writeQueue;

- (dispatch_queue_t _Nullable)readQueue;

- (dispatch_queue_t _Nullable)serviceQueue;

/*!
 @method connection
 @discussion This method is used to retrieve the associated connection
 object for the service (usually a CWTCPConnection instance).
 @result The associated connectio object.
 */
- (id<CWConnection> _Nonnull) connection;

/*!
 @method updateWrite
 @discussion This method is invoked automatically when bytes are available
 to be written. You should never have to invoke this method directly.
 */
- (void) updateWrite;

/*!
 @method username
 @discussion This method is used to get the username (if any) that will be
 used to authenticate to the service.
 @result The username.
 */
- (NSString * _Nullable) username;

/*!
 @method setUsername:
 @discussion This method is used to set the username that will be used
 to authenticate to the service.
 @param theUsername The username for authentication.
 */
- (void) setUsername: (NSString * _Nonnull) theUsername;

/*!
 @method isConnected
 @discussion This method is used to verify if the receiver
 is connected to the server.
 @result YES if connected, NO otherwise.
 */
- (BOOL) isConnected;

/*!
 @method connect
 @discussion This method is used to connect the receiver to the server.
 It will block until the connection was succefully established
 (or until it fails).
 @result 0 on success, -1 on error.
 */
- (int) connect;

/**
 Buffers the given data to be streamed to a connected server later on.
 Also triggers the current connection to actually write the now bufferd data to the stream.

 You should never have to invoke this method directly.

 @param The bytes to buffer
 */
- (void) writeData: (NSData *_Nonnull) theData;

/**
 Buffers the given data in the given order to be streamed to a connected server later on.
 Also triggers the current connection to atually write the, now bufferd, data to the stream.

 You should never have to invoke this method directly.

 @param The bytes to buffer
 */
- (void) bulkWriteData: (NSArray<NSData*> *_Nonnull) bulkData;

/*!
 @method addRunLoopMode:
 @discussion This method is used to add an additional mode that the run-loop
 will use to listen for network events for reading and writing.
 Note that this method does nothing on OS X since only the
 kCFRunLoopCommonModes mode is used.
 @param The additional mode. NSDefaultRunLoopMode is always present so there
 is no need to add it.
 */
- (void) addRunLoopMode: (NSString * _Nonnull) theMode;

/*!
 @method connectionTimeout
 @discussion This method is used to get the timeout used when
 connecting to the host.
 @result The connecton timeout.
 */
- (unsigned int) connectionTimeout;

/*!
 @method setConnectionTimeout:
 @discussion This method is used to set the timeout used when
 connecting to the host.
 @param theConnectionTimeout The timeout to use.
 */
- (void) setConnectionTimeout: (unsigned int) theConnectionTimeout;

/*!
 @method readTimeout
 @discussion This method is used to get the timeout used when
 reading bytes from the socket.
 @result The read timeout.
 */
- (unsigned int) readTimeout;

/*!
 @method setReadTimeout
 @discussion This method is used to set the timeout used when
 reading bytes from the socket.
 @param The timeout to use.
 */
- (void) setReadTimeout: (unsigned int) theReadTimeout;

/*!
 @method writeTimeout
 @discussion This method is used to get the timeout used when
 writing bytes from the socket.
 @result The write timeout.
 */
- (unsigned int) writeTimeout;

/*!
 @method setWriteTimeout
 @discussion This method is used to set the timeout used when
 writing bytes from the socket.
 @param The timeout to use.
 */
- (void) setWriteTimeout: (unsigned int) theWriteTimeout;

/*!
 @method lastCommand
 @discussion This method is used to get the last command that
 has been sent by CWService subclasses to the
 remote server. To know which commands can be
 sent, see the documentation of the associated
 subclasses.
 @result The last command sent, 0 otherwise.
 */
- (unsigned int) lastCommand;

/**
 Sets all internal dispatch_queues used for serialization to nil.
 */
- (void)nullifyQueues;

NS_ASSUME_NONNULL_END

@end
