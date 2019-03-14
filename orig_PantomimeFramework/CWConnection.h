/*
**  CWConnection.h
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

#ifndef _Pantomime_H_CWConnection
#define _Pantomime_H_CWConnection

#import <Foundation/NSData.h>
#import <Foundation/NSString.h>

#import <PantomimeFramework/CWConstants.h>

@protocol CWConnectionDelegate

- (void)connectionEstablished;

- (void)receivedEvent:(void *)theData
                 type:(RunLoopEventType)theType
                extra:(void *)theExtra
              forMode:(NSString *)theMode;

@end

/*!
  @protocol CWConnection
  @discussion This protocol defines a basic set of methods that classes
              should implement. CWTCPConnection implements the protocol
	      to offer TCP connections support. An UDP implementation
	      will likely be added in a near future (for DNS requests).
*/
@protocol CWConnection

@property (nonatomic, nullable, weak, readwrite) id<CWConnectionDelegate> delegate;
@property (nonatomic, readonly) NSError * _Nullable streamError;

/*!
  @method initWithName: port: background:
  @discussion This method is use to initialize a new connection
              instance at the specified port. It can connect
	      in background if needed and use the default timeout
	      (60 seconds) when connecting.
  @param theName The host name to connect to.
  @param thePort The port to connect to.
  @param transport The connection transport to use.
  @param theBOOL YES if we want to connect in background (non-blocking
                 way), NO if we want this call to be blocking until
		 we successfully connected to the host.
  @result An instance implementing the CWConnection protocol, nil
	  if an error occurred, like DNS resolution.
*/
- (id _Nonnull) initWithName: (NSString * _Nonnull) theName
                        port: (unsigned int) thePort
                   transport:(ConnectionTransport)transport
                  background: (BOOL) theBOOL;

- (void)startTLS;

/*!
  @method isConnected
  @discussion This method is used to verify if the socket is
              in a connected state.
  @result YES if the socket is in a connected state, NO otherwise.
*/
- (BOOL) isConnected;

/*!
  @method close
  @discussion This method is used to close the connection to the host.
*/
- (void) close;

/*!
  @method read: length:
  @discussion This method is used to read <i>len</i> bytes from the
              socket and store them in <i>buf</i>
  @param buf The buffer in which read bytes will be stored in.
  @param len The number of bytes we want to try to read.
  @result The number of bytes successfully read.
*/
- (NSInteger) read: (unsigned char * _Nonnull) buf
      length: (NSInteger) len;

/*!
  @method write: length:
  @discussion This method is used to write <i>len</i> bytes from
              <i>buf</i> to the socket.
  @param buf The bytes that we want to write to the socket.
  @param len The number of bytes we want to try to write.
  @result The number of bytes successfully written.
*/
- (NSInteger) write: (unsigned char * _Nonnull) buf
       length: (NSInteger) len;

- (void)connect;

- (BOOL)canWrite;

@end

#endif // _Pantomime_H_CWConnection
