/*
**  CWService.h
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

#ifndef _Pantomime_H_CWService
#define _Pantomime_H_CWService

#import "Pantomime/CWConnection.h"

#import "Pantomime/CWConstants.h"
#import "Pantomime/CWLogger.h"
#import "Pantomime/NSData+Extensions.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSTimer.h>

#ifdef MACOSX
#import <Foundation/NSMapTable.h>
#import <CoreFoundation/CoreFoundation.h>
#endif

@class CWService;
@class CWThreadSafeArray;
@class CWThreadSafeData;

/*!
  @const PantomimeAuthenticationCompleted
*/
extern NSString * _Nonnull PantomimeAuthenticationCompleted;

/*!
  @const PantomimeAuthenticationFailed
*/
extern NSString * _Nonnull PantomimeAuthenticationFailed;

/*!
  @const PantomimeConnectionEstablished
*/
extern NSString * _Nonnull PantomimeConnectionEstablished;

/*!
  @const PantomimeConnectionLost
*/
extern NSString * _Nonnull PantomimeConnectionLost;

/*!
  @const PantomimeConnectionTerminated
*/
extern NSString * _Nonnull PantomimeConnectionTerminated;

/*!
  @const PantomimeConnectionTimedOut
*/
extern NSString * _Nonnull PantomimeConnectionTimedOut;

/*!
  @const PantomimeRequestCancelled
*/
extern NSString * _Nonnull PantomimeRequestCancelled;

/*!
  @const PantomimeServiceInitialized
*/
extern NSString * _Nonnull PantomimeServiceInitialized;

/*!
  @const PantomimeServiceReconnected
*/
extern NSString * _Nonnull PantomimeServiceReconnected;

/*!
  @const PantomimeProtocolException
  @description This exception can be raised if a major
               protocol handling error occured in one
	       of the CWService subclasses. This would
	       mean that Pantomime has a bug.
*/
extern NSString * _Nonnull PantomimeProtocolException;

/*!
  @category NSObject (CWServiceClient)
  @discussion This informal protocol defines methods that can implemented in
              CWService's delegate (CWIMAPStore, CWPOP3Store or CWSMTP instance) 
	      to control the behavior of the class or to obtain status information.
	      You can release/autorelease a CWService instance in -connectionTimedOut:,
	      -connectionLost: or -connectionTerminated (or the respective
	      notification handlers). You may NOT do it elsewhere.
*/
@protocol CWServiceClient

@required

/*!
 @method connectionLost:
 @discussion Invoked when the connection to the peer has been
 lost without the "user's" intervention.
 A PantomimeConnectionLost notification is also posted.
 @param theNotification The notification holding the information.
 */
- (void) connectionLost: (NSNotification * _Nullable) theNotification;

/*!
 @method connectionTimedOut:
 @discussion Invoked when connecting to a peer on a non-blocking
 fashion but the associated timeout has expired. It is also
 invoked when we try to read bytes from the peer or when
 trying send bytes to it. The method <i>isConnected</i> can
 be invoked in order if we got this timeout when trying to
 connect (the value will be set to "NO") or when we are
 connected but can't read or write anymore.
 A PantomimeConnectionTimedOut notification is also posted.
 @param theNotification The notification holding the information.
 */
- (void) connectionTimedOut: (NSNotification * _Nullable) theNotification;

/*!
 @method badResponse:
 @discussion This is called when a response could not be parsed.
 A PantomimeBadResponse notification is also posted.
 @param theNotification The notification holding the information.
 */
- (void) badResponse: (NSNotification * _Nullable) theNotification;

@optional

/*!
  @method authenticationCompleted:
  @discussion This method is automatically called on the delegate
              when the authentication has sucessfully completed
	      on the underlying Service's instance.
	      A PantomimeAuthenticationCompleted notification is also posted.
	      The authentication mechanism that was used can be obtained
	      from the notification's userInfo using the "Mechanism" key.
  @param theNotification The notification holding the information.
*/
- (void) authenticationCompleted: (NSNotification * _Nullable) theNotification;

/*!
  @method authenticationFailed:
  @discussion This method is automatically called on the delegate
              when the authentication has failed on the underlying Service's instance.
	      A PantomimeAuthenticationCompleted notification is also posted.
	      The authentication mechanism that was used can be obtained
	      from the notification's userInfo using the "Mechanism" key.
  @param theNotification The notification holding the information.
*/
- (void) authenticationFailed: (NSNotification * _Nullable) theNotification;

/*!
  @method connectionEstablished:
  @discussion Invoked once the connection has been established with the peer.
              A PantomimeConnectionEstablished notification is also posted.
  @param theNotification The notification holding the information.
*/
- (void) connectionEstablished: (NSNotification * _Nullable) theNotification;

/*!
  @method connectionTerminated:
  @discussion Invoked when the connection has been cleanly terminated
              with the peer.
	      A PantomimeConnectionTerminated notification is also posted.
  @param theNotification The notification holding the information.
*/
- (void) connectionTerminated: (NSNotification * _Nullable) theNotification;

/*!
  @method service: receivedData:
  @discussion Invoked when bytes have been received by the underlying
              CWService's connection. No notification is posted.
  @param theService The CWService instance that generated network activity.
  @param theData The received bytes.
*/
- (void) service: (CWService * _Nonnull) theService  receivedData: (NSData * _Nonnull) theData;

/*!
  @method service: sentData:
  @discussion Invoked when bytes have been sent using the underlying
              CWService's connection. No notification is posted.
  @param theService The CWService instance that generated network activity.
  @param theData The sent bytes.
*/
- (void) service: (CWService * _Nonnull) theService  sentData: (NSData * _Nonnull) theData;

/*!
  @method requestCancelled:
  @discussion This method is automatically called after
              a request has been cancelled. The connection
	      was automatically closed PRIOR to calling this delegate method.
	      A PantomimeRequestCancelled notification is also posted.
  @param theNotification The notification holding the information.
*/
- (void) requestCancelled: (NSNotification * _Nullable) theNotification;

/*!
  @method serviceInitialized:
  @discussion This method is automatically invoked on the delegate
              when the Service is fully initialized. This method
	      is invoked after -connectionEstablished: is called.
	      A PantomimeServiceInitialized notification is also posted.
  @param theNotification The notification holding the information.
*/
- (void) serviceInitialized: (NSNotification * _Nullable) theNotification;

/*!
  @method serviceReconnected:
  @discussion When a service lost its connection, -connectionWasLost: is
              called. Usually, -reconnect is called to re-establish the
	      connection with the remote host. Once it has completed,
	      -serviceReconnected: is invoked on the delegate.
              A PantomimeServiceReconnected notification is also posted.
  @param theNotification The notification holding the information.
*/
- (void) serviceReconnected: (NSNotification * _Nullable) theNotification;

- (void) commandSent: (NSNotification * _Nullable) theNotification;

- (void) folderRenameFailed: (NSNotification * _Nullable) theNotification;

- (void) messageChanged: (NSNotification * _Nullable) theNotification;

- (void) messageExpunged: (NSNotification * _Nullable) theNotification;

- (void) messagePrefetchCompleted: (NSNotification * _Nullable) theNotification;

- (void) messageFetchCompleted: (NSNotification * _Nullable) theNotification;

- (void) folderCreateFailed: (NSNotification * _Nullable) theNotification;

- (void) folderDeleteFailed: (NSNotification * _Nullable) theNotification;

- (void) folderSubscribeFailed: (NSNotification * _Nullable) theNotification;

- (void) messagesCopyFailed: (NSNotification * _Nullable) theNotification;

- (void) folderStatusFailed: (NSNotification * _Nullable) theNotification;

- (void) messageStoreFailed: (NSNotification * _Nullable) theNotification;

- (void) folderUnsubscribeFailed: (NSNotification * _Nullable) theNotification;

- (void) commandCompleted: (NSNotification * _Nullable) theNotification;

- (void) folderCreateCompleted: (NSNotification * _Nullable) theNotification;

- (void) folderDeleteCompleted: (NSNotification * _Nullable) theNotification;

- (void) folderRenameCompleted: (NSNotification * _Nullable) theNotification;

- (void) folderSubscribeCompleted: (NSNotification * _Nullable) theNotification;

- (void) messagesCopyCompleted: (NSNotification * _Nullable) theNotification;

- (void) messageStoreCompleted: (NSNotification * _Nullable) theNotification;

- (void) folderUnsubscribeCompleted: (NSNotification * _Nullable) theNotification;

- (void) folderStatusCompleted: (NSNotification * _Nullable) theNotification;

/*!
 @method actionFailed:
 @discussion This is called when a NO response is received.
 A PantomimeActionFailed notification is also posted.
 @param theNotification The notification holding the information.
 */
- (void) actionFailed: (NSNotification * _Nullable) theNotification;

/*!
 @method idleEntered:
 @discussion Called when IDLE (as requested by the client) has been entered,
 that is the server has sent the continuation request and is now waiting for "DONE".
 A PantomimeIdleEntered notification is also posted.
 @param theNotification The notification holding the information, which in this case will be nil.
 */
- (void) idleEntered: (NSNotification * _Nullable) theNotification;

/*!
 @method idleNewMessages:
 @discussion Called when during IDLE the server signals at least 1 new message via EXISTS.
 A PantomimeIdleNewMessages notification is also posted.
 @param theNotification The notification holding the information, which in this case will be nil.
 */
- (void) idleNewMessages: (NSNotification * _Nullable) theNotification;

/*!
 @method idleFinished:
 @discussion Called when during IDLE the client exits the model by doing the DONE continuation,
 and subsequently the server responds with OK.
 A PantomimeIdleFinished notification is also posted.
 @param theNotification The notification holding the information, which in this case will be nil.
 */
- (void) idleFinished: (NSNotification * _Nullable) theNotification;

@end

@interface CWConnectionState : NSObject

@property (nonatomic, strong) NSMutableArray * _Nullable previous_queue;
@property (nonatomic) BOOL reconnecting;
@property (nonatomic) BOOL opening_mailbox;

@end

#ifdef MACOSX

/*!
  @class CWService
  @discussion This abstract class defines the basic behavior and implementation
              of all Pantomime internet services such as SMTP, POP3 and IMAP.
	      You should never instantiate this class directly. You rather
	      need to instantiate the CWSMTP, CWPOP3Store or CWIMAPStore classes,
	      which fully implement the abstract methods found in this class.
*/
@interface CWService : NSObject
#else
@interface CWService : NSObject <RunLoopEvents>
#endif
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

/*!
  @method initWithName: port:
  @discussion This is the designated initializer for the CWService class.
              Once called, it'll open a connection to the server specified
	      by <i>theName</i> using the specified port (<i>thePort</i>).
  @param theName The FQDN of the server.
  @param thePort The server port to which we will connect.
  @param transport How to connect to the server (e.g., use TLS)
  @result An instance of a Service class, nil on error.
*/
- (id _Nonnull) initWithName: (NSString * _Nonnull) theName
                        port: (unsigned int) thePort
                   transport: (ConnectionTransport) transport;

/*!
  @method setDelegate:
  @discussion This method is used to set the CWService's delegate.
              The delegate will not be retained. The CWService class
	      (and its subclasses) will invoke methods on the delegate
	      based on actions performed.
  @param theDelegate The delegate, which implements various callback methods.
*/
- (void) setDelegate: (id _Nullable) theDelegate;

/*!
  @method delegate
  @discussion This method is used to get the delegate of the CWService's instance.
  @result The delegate, nil if none was previously set.
*/
- (id _Nullable) delegate;

/*!
  @method port
  @discussion This method is used to obtain the server port.
  @result The server port.
*/
- (unsigned int) port;

/*!
  @method supportedMechanisms
  @discussion This method is used to return the supported SASL
              authentication mecanisms by the receiver.
  @result An array of NSString instances which indicates
          what SASL mechanisms are supported.
*/
- (NSArray *  _Nonnull) supportedMechanisms;

/*!
  @method authenticate: password: mechanism:
  @discussion This method is used to authentifcate the receiver
              to the server. This method posts a PantomimeAuthenticationCompleted
	      (or calls the -authenticationCompleted: method on the delegate, if any)
	      if the authentication is sucessful. If not, it posts the
	      PantomimeAuthenticationFailed notification (or calls the
	      -authenticationFailed: method on the delegate, if any). This method
	      is fully asynchronous.
  @param theUsername The username to use, overwriting -username: if any.
  @param thePassword The password to use.
  @param theMechanism The authentication mechanism to use.
*/
- (void) authenticate: (NSString * _Nonnull) theUsername
             password: (NSString * _Nullable) thePassword
            mechanism: (NSString * _Nonnull) theMechanism;

/*!
  @method cancelRequest
  @discussion This method will cancel any pending requests or communications
              with the server and close the connection. It'll post a
	      PantomimeRequestCancelled once it has fully cancelled everything.
	      This method is fully asynchronous.
*/
- (void) cancelRequest;

/*!
  @method close
  @discussion This method is used to close the connection to the server.
              If the receiver is not in a connected state, it does nothing.
	      If it is, it posts a PantomimeConnectionTerminated notification
	      once it has completed and invokes -connectionTerminated: on the
	      delegate, if any.
*/
- (void) close;

/*!
 @method noop
 @discussion This method is used to generate some traffic on a server
 so the connection doesn't idle and gets terminated by
 the server. Subclasses of CWService need to implement this method.
 */
- (void) noop;

/*!
 @method reconnect
 @discussion Pending.
 @result Pending.
 */
- (int) reconnect;

/*!
  @method connectInBackgroundAndNotify
  @discussion This method is used  connect the receiver to the server.
              The call to this method is non-blocking. This method will
	      post a PantomimeConnectionEstablished notification once
	      the connection has been establish (and call -connectionEstablished:
	      on the delegate, if any). Otherwise, it will post a PantomimeConnectionTimedOut
	      notification (and call -connectionTimedOut: on the delegate, if any).
*/
- (void) connectInBackgroundAndNotify;

/*!
  @method startTLS
  @discussion This method is used to activate TLS over
              a non-secure connection. This method can
          be called in the -serviceInitialized:
          delegate method. The latter will be invoked
          again once TLS has been activated successfully.
*/
- (void) startTLS;

/*!
  @method capabilities
  @discussion This method is used to obtain the capabilities of the
              associated service.
  @result The capabilities, as a set of NSString instances.
*/
- (NSSet<NSString *> * _Nonnull) capabilities;

/*!
 @method updateRead
 @discussion This method is invoked automatically when bytes are available
 to be read. You should never have to invoke this method directly.
 */
- (void) updateRead;

@end

#endif // _Pantomime_H_CWService
