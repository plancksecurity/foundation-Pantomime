//
//  CWService+Protected.h
//  Pantomime
//
//  Created by Andreas Buff on 05.09.17.
//  Copyright © 2017 pEp Security S.A. All rights reserved.
//

#import "CWService.h"

NS_ASSUME_NONNULL_BEGIN

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

/** Lazy initialized */
- (dispatch_queue_t _Nullable)writeQueue;

- (void)setWriteQueue: (dispatch_queue_t _Nullable)writeQueue;

/** Lazy initialized */
- (dispatch_queue_t _Nullable)serviceQueue;

- (void)setServiceQueue: (dispatch_queue_t _Nullable)serviceQueue;

/*!
 @method name
 @discussion This method is used to obtain the server name.
 @result The server name.
 */
- (NSString * _Nonnull) name;

/*!
 @method setName:
 @discussion This method is used to set the server name to which
 we will eventually connect to.
 @param theName The name of the server.
 */
- (void) setName: (NSString * _Nonnull) theName;

/*!
 @method setPort:
 @discussion This method is used to set the server port to which
 we will eventually connect to.
 @param theName The port of the server.
 */
- (void) setPort: (unsigned int) thePort;

/*!
 @method connection
 @discussion This method is used to retrieve the associated connection
 object for the service (usually a CWTCPConnection instance).
 @result The associated connectio object.
 */
- (id<CWConnection> _Nonnull) connection;

/*!
 @method reconnect
 @discussion Pending.
 @result Pending.
 */
- (int) reconnect;

/*!
 @method updateRead
 @discussion This method is invoked automatically when bytes are available
 to be read. You should never have to invoke this method directly.
 */
- (void) updateRead;

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

/*!
 @method noop
 @discussion This method is used to generate some traffic on a server
 so the connection doesn't idle and gets terminated by
 the server. Subclasses of CWService need to implement this method.
 */
- (void) noop;

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
