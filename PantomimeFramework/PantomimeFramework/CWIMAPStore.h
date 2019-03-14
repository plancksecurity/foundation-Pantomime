/*
**  CWIMAPStore.h
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

#ifndef _Pantomime_H_CWIMAPStore
#define _Pantomime_H_CWIMAPStore

#import <PantomimeFramework/CWConstants.h>
#import <PantomimeFramework/CWService.h>
#import <PantomimeFramework/CWStore.h>

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

/*!
  @typedef IMAPCommand
  @abstract Supported IMAP commands.
  @discussion This enum lists the supported IMAP commands available in Pantomime's IMAP client code.
  @constant IMAP_APPEND The IMAP APPEND command - see 6.3.11. APPEND Command of RFC 3501.
  @constant IMAP_AUTHENTICATE_CRAM_MD5 CRAM-MD5 authentication.
  @constant IMAP_AUTHENTICATE_LOGIN LOGIN authentication
  @constant IMAP_AUTHORIZATION Special command so that we know we are in the authorization state.
  @constant IMAP_CAPABILITY The IMAP CAPABILITY command - see 6.1.1. CAPABILITY Command of RFC 3501.
  @constant IMAP_CLOSE The IMAP CLOSE command - see 6.4.2. CLOSE Command of RFC 3501.
  @constant IMAP_CREATE The IMAP CREATE command - see 6.3.3. CREATE Command of RFC 3501.
  @constant IMAP_DELETE The IMAP DELETE command - see 6.3.4. DELETE Command of RFC 3501.
  @constant IMAP_EXAMINE The IMAP EXAMINE command - see 6.3.2. EXAMINE Command of RFC 3501.
  @constant IMAP_EXPUNGE The IMAP EXPUNGE command - see 6.4.3. EXPUNGE Command of RFC 3501.
  @constant IMAP_LIST The IMAP LIST command - see 6.3.8. LIST Command of RFC 3501.
  @constant IMAP_LOGIN The IMAP LOGIN command - see 6.2.3. LOGIN Command of RFC 3501.
  @constant IMAP_LOGOUT The IMAP LOGOUT command - see 6.1.3. LOGOUT Command of RFC 3501.
  @constant IMAP_LSUB The IMAP LSUB command - see 6.3.9. LSUB Command of RFC 3501.
  @constant IMAP_NOOP The IMAP NOOP command - see 6.1.2. NOOP Command of RFC 3501.
  @constant IMAP_RENAME The IMAP RENAME command - see 6.3.5. RENAME Command of RFC 3501.
  @constant IMAP_SELECT The IMAP SELECT command - see 6.3.1. SELECT Command of RFC 3501.
  @constant IMAP_STARTTLS The STARTTLS IMAP command - see RFC2595.
  @constant IMAP_STATUS The IMAP STATUS command - see 6.3.10. STATUS Command of RFC 3501.
  @constant IMAP_SUBSCRIBE The IMAP SUBSCRIBE command - see 6.3.6. SUBSCRIBE Command of RFC 3501.
  @constant IMAP_UID_COPY The IMAP COPY command - see 6.4.7. COPY Command of RFC 3501.
  @constant IMAP_UID_FETCH_BODY_TEXT The IMAP FETCH command - see 6.4.5. FETCH Command of RFC 3501.
  @constant IMAP_UID_FETCH_HEADER_FIELDS The IMAP FETCH command - see 6.4.5. FETCH Command of RFC 3501.
  @constant IMAP_UID_FETCH_HEADER_FIELDS_NOT The IMAP FETCH command - see 6.4.5. FETCH Command of RFC 3501.
  @constant IMAP_UID_FETCH_RFC822 The IMAP FETCH command - see 6.4.5. FETCH Command of RFC 3501.
  @constant IMAP_UID_SEARCH The IMAP SEARCH command - see 6.4.4. SEARCH Command of RFC 3501.
                            Used to update the IMAP Folder cache.
  @constant IMAP_UID_SEARCH_ALL The IMAP SEARCH command - see 6.4.4. SEARCH Command of RFC 3501.
  @constant IMAP_UID_SEARCH_ANSWERED Special command used to update the IMAP Folder cache.
  @constant IMAP_UID_SEARCH_FLAGGED Special command used to update the IMAP Folder cache.
  @constant IMAP_UID_SEARCH_UNSEEN Special command used to update the IMAP Folder cache.
  @constant IMAP_UID_STORE The IMAP STORE command - see 6.4.6. STORE Command of RFC 3501.
  @constant IMAP_UNSUBSCRIBE The IMAP UNSUBSCRIBE command - see 6.3.7. UNSUBSCRIBE Command of RFC 3501.
  @constant IMAP_EMPTY_QUEUE Special command to empty the command queue.
*/
typedef enum {
    IMAP_APPEND = 0x1,
    IMAP_AUTHENTICATE_CRAM_MD5, //2
    IMAP_AUTHENTICATE_LOGIN,    //AUTH=LOGIN //3
    IMAP_AUTHENTICATE_XOAUTH2,  //AUTH=XOAUTH2 //4
    IMAP_AUTHORIZATION, //5
    IMAP_CAPABILITY, //6
    IMAP_CLOSE, //7
    IMAP_CREATE, //8
    IMAP_DELETE, //9
    IMAP_EXAMINE, //10
    IMAP_EXPUNGE, //11
    IMAP_LIST, //12
    IMAP_LOGIN, //AUTH=PLAIN //13
    IMAP_LOGOUT, //14
    IMAP_LSUB, //15
    IMAP_NOOP, //16
    IMAP_RENAME, //17
    IMAP_SELECT, //18
    IMAP_STARTTLS, //19
    IMAP_STATUS, //20
    IMAP_SUBSCRIBE, //21
    IMAP_UID_COPY, //22
    IMAP_UID_MOVE, //23
    IMAP_UID_FETCH_BODY_TEXT, //24
    IMAP_UID_FETCH_HEADER_FIELDS, //25
    IMAP_UID_FETCH_FLAGS, //26
    IMAP_UID_FETCH_HEADER_FIELDS_NOT, //27
    IMAP_UID_FETCH_RFC822, //28
    IMAP_UID_FETCH_UIDS, //29
    IMAP_UID_SEARCH, //30
    IMAP_UID_SEARCH_ALL, //31
    IMAP_UID_SEARCH_ANSWERED, //32
    IMAP_UID_SEARCH_FLAGGED, //33
    IMAP_UID_SEARCH_UNSEEN, //34
    IMAP_UID_STORE, //35
    IMAP_UNSUBSCRIBE, //36
    IMAP_EMPTY_QUEUE, //37
    IMAP_IDLE, //38
} IMAPCommand;

/*!
  @const PantomimeFolderSubscribeCompleted
*/
extern NSString * _Nonnull const PantomimeFolderSubscribeCompleted;

/*!
  @const PantomimeFolderSubscribeFailed
*/
extern NSString * _Nonnull const PantomimeFolderSubscribeFailed;

/*!
  @const PantomimeFolderUnsubscribeCompleted
*/
extern NSString * _Nonnull const PantomimeFolderUnsubscribeCompleted;

/*!
  @const PantomimeFolderUnsubscribeFailed
*/
extern NSString * _Nonnull const PantomimeFolderUnsubscribeFailed;

/*!
 @discussion Used for NO responses (see _parseNO).
 @const PantomimeActionFailed
 */
extern NSString * _Nonnull const PantomimeActionFailed;

/*!
 @discussion Used for bad responses (see _parseBad).
 @const PantomimeBadResponse
 */
extern NSString * _Nonnull const PantomimeBadResponse;

/*!
 @discussion Used as a key for the user info dict where you find the bad response
 that triggered _parseBad.
 @const PantomimeBadResponseInfoKey
 */
extern NSString * _Nonnull const PantomimeBadResponseInfoKey;

/*!
 @discussion The key under which the user info dict is stored for actionFailed:.
 @const PantomimeErrorInfo
 */
extern NSString * _Nonnull const PantomimeErrorInfo;

/*!
  @const PantomimeFolderStatusCompleted
*/
extern NSString * _Nonnull const PantomimeFolderStatusCompleted;

/*!
  @const PantomimeFolderStatusFailed
*/
extern NSString * _Nonnull const PantomimeFolderStatusFailed;

/*!
 @const PantomimeBadResponseInfoKey
 @discussion Key name for an IMAP response that could not be parsed, for the
 PantomimeActionFailed notifications.
 */
extern NSString * _Nonnull const PantomimeBadResponseInfoKey;

/*!
 @const PantomimeIdleEntered
 */
extern NSString * _Nonnull const PantomimeIdleEntered;

/*!
 @const PantomimeIdleNewMessages
 */
extern NSString * _Nonnull const PantomimeIdleNewMessages;

/*!
 @const PantomimeIdleFinished
 */
extern NSString * _Nonnull const PantomimeIdleFinished;

@class CWFlags;
@class CWIMAPCacheManager;
@class CWIMAPFolder;
@class CWIMAPMessage;
@class CWIMAPQueueObject;
@class CWTCPConnection;

/*!
  @class CWIMAPStore
  @abstract Pantomime IMAP client code.
  @discussion This class, which extends the CWService class and implements
              the CWStore protocol, is Pantomime's IMAP client code.
              All calls from client site are guarantied to be serialized.
*/ 
@interface CWIMAPStore : CWService  <CWStore>

@property (nonatomic, nullable) __block id<CWFolderBuilding> folderBuilder;

/**
 Maximum count of messages to fetch.
 */
@property (nonatomic) NSUInteger maxFetchCount;

/*!
 @method sendCommand:info:string: ...
 @discussion This method is used to send commands to the IMAP server.
 Normally, you should not call this method directly.
 @param theCommand The IMAP command to send.
 @param theInfo The addition info to pass.
 @param string The parameter string
 */
- (void) sendCommand: (IMAPCommand) theCommand  info: (NSDictionary * _Nullable) theInfo
              string:(NSString * _Nonnull)theString;

- (void)exitIDLE;

#pragma mark - CWStore

//
// When this method is invoked for the first time, it sends a LIST
// command to the IMAP server and cache the results for subsequent
// queries. The IMAPStore notifies the delegate once it has parsed
// all server's responses.
//
- (NSEnumerator *_Nullable) folderEnumerator;

@end

@interface CWMessageUpdate : NSObject

@property (nonatomic) BOOL flags;
@property (nonatomic) BOOL rfc822;
@property (nonatomic) BOOL rfc822Size;
@property (nonatomic) BOOL bodyHeader;
@property (nonatomic) BOOL bodyText;
@property (nonatomic) BOOL uid;
@property (nonatomic) BOOL msn;

/*!
 @method newComplete
 @return An instance for updating everything.
 */
+ (instancetype _Nonnull)newComplete;

/**
 Indicates nothing has been updated but the message number.
 We might fetch the UID only to update the MSN of a message.
 
 @return YES if nothing or only the UID changed, NO otherwize
 */
- (BOOL)isMsnOnly;

/**
 Indicates nothing has been updated but the flags.
 We might fetch the UID only to update the MSN of a message.
 
 @return YES if only flags or flags and UID changed, NO otherwize
 */
- (BOOL)isFlagsOnly;

/**
 Indicates nothing has been updated.

 @return YES if nothing but UID and/or MSN changed, NO otherwize
 */
- (BOOL)isNoChange;

@end

#endif // _Pantomime_H_IMAPStore
