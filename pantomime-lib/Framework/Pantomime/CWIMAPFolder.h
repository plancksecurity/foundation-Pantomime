/*
 **  CWIMAPFolder.h
 **
 **  Copyright (c) 2001-2006
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

#ifndef _Pantomime_H_CWIMAPFolder
#define _Pantomime_H_CWIMAPFolder

#import "Pantomime/CWFolder.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSData.h>
#import <Foundation/NSString.h>

#import "Pantomime/CWConstants.h"

/*!
 @const PantomimeMessagesCopyCompleted
 @discussion This notification is posted when CWIMAPFolder: -copyMessages:
 toFolder: has successfully completed. -messagesCopyCompleted:
 is also called on the delegate, if any.
 */
extern NSString * _Nonnull PantomimeMessagesCopyCompleted;

/*!
 @const PantomimeMessagesCopyFailed
 @discussion This notification is posted when CWIMAPFolder: -copyMessages:
 toFolder: has failed to complete. -messagesCopyFailed:
 is also called on the delegate, if any.
 */
extern NSString * _Nonnull PantomimeMessagesCopyFailed;

/*!
 @const PantomimeMessageStoreCompleted
 @discussion This notification is posted when CWIMAPFolder: -setFlags:
 messages: has successfully completed. -messageStoreCompleted:
 is also called on the delegate, if any.
 */
extern NSString * _Nonnull PantomimeMessageStoreCompleted;

/*!
 @const PantomimeMessageStoreFailed
 @discussion This notification is posted when CWIMAPFolder: -setFlags:
 messages: has failed to completed. -messageStoreFailed:
 is also called on the delegate, if any.
 */
extern NSString * _Nonnull PantomimeMessageStoreFailed;

@class CWIMAPMessage;

/*!
 @class CWIMAPFolder
 @discussion This class, which extends the CWFolder class, is used to
 implement IMAP-specific features such as server-side
 operations for copying messages between mailboxes.
 */
@interface CWIMAPFolder : CWFolder
{
@private
    NSUInteger _uid_validity;
    BOOL _selected;
}

/** The UIDNEXT value, as indicated by the server */
@property NSUInteger nextUID;

/** The result from an EXISTS response */
@property NSUInteger existsCount;

/*!
 @method initWithName: mode:
 @discussion This method is used to initialize the receiver
 with <i>theName</i> using <i>theMode</i>. Normally,
 you should not invoke this method directly.
 You must rather use one of CWIMAPStore's folderForName: ...
 method.
 @param theName The name of the folder.
 @param theMode The mode to use. Accepted values are part of the
 PantomimeFolderMode enum.
 @result An CWIMAPFolder instance, nil on error.
 */
- (id _Nullable) initWithName: (NSString * _Nonnull) theName
                         mode: (PantomimeFolderMode) theMode;

/*!
 @method appendMessageFromRawSource:flags:internalDate
 @discussion This method is used to append a message from its raw source
 representation (RFC2822 compliant) to the underlying store. It differs from
 -appendMessageFromRawSource:flags: in that this method supplies the
 given date to the server to use as the INTERNALDATE. Not supplying this
 date will cause some servers and clients to report the date of the message
 as the current date and time, rather than that specified in the Received
 header.
 @param theData The raw representation of the message to append.
 @param theFlags The flags of the message, nil if no flags need to be kept.
 @param theDate The INTERNALDATE of the message, or nil to use the current date.
 */
- (void) appendMessageFromRawSource: (NSData * _Nonnull) theData
                              flags:(CWFlags * _Nullable) theFlags
                       internalDate: (NSDate * _Nullable) theDate;

/*!
 @method copyMessages: toFolder:
 @discussion This method copies the messages in <i>theMessages</i> array from
 the receiver to the destination folder's name, <i>theFolder</i>.
 On success, this method posts a PantomimeMessagesCopyCompleted notification
 (and calls -messagesCopyCompleted: on the delegate, if any). On failure,
 it posts a PantomimeMessagesCopyFailed notification (and calls
 -messagesCopyFailed: on the delegate, if any). This method is
 fully asynchronous.
 @param theMessages The messages to copy.
 @param theFolder The name of the target folder. The name must include
 hierarchy separators if the target folder is a subfolder.
 */
- (void) copyMessages: (NSArray * _Nonnull) theMessages
             toFolder: (NSString * _Nonnull) theFolder;

/*!
 @method prefetch
 @discussion This method is used to cache part of the message headers
 from the IMAP server. On completion, it posts the PantomimeFolderPrefetchCompleted
 notification (and calls -folderPrefetchCompleted: on the delegate, if any).
 This method is fully asynchronous.
 */
- (void) prefetch;

/*!
 @discussion Syncs the flags of existing mails (until the given lastUID),
 thereby finding out flag changes and deleted messages.
 */
- (void)syncExistingFirstUID:(NSUInteger)firstUID lastUID:(NSUInteger)lastUID;

/*!
 @method UIDValidity
 @discussion This method is used to obtain the UID validity of an IMAP folder.
 Refer to "2.3.1.1. Unique Identifier (UID) Message Attribute" of
 RFC 3501 for a detailed description of this parameter.
 @result The UID validity of the folder.
 */
- (NSUInteger) UIDValidity;

/*!
 @method setUIDValidity:
 @discussion This method is used to set the UID validity of the receiver.
 If the receiver has a cache (instance of CWIMAPCacheManager) and
 the UID validity of its cache differs from <i>theUIDValidity</i>,
 all cache entries are invalidated.
 @param theUIDValidity The UID validity value.
 */
- (void) setUIDValidity: (NSUInteger) theUIDValidity;

/*!
 @method selected
 @discussion This method is used to verify if the folder is in
 a selected state.
 @result YES if it is in a selected state, NO otherwise.
 */
- (BOOL) selected;

/*!
 @method setSelected:
 @discussion This method is used to specify if the folder is in
 a selected state or not. You should never call
 this method directly. Instead, call IMAPStore:
 -folderForName: select:.
 @param theBOOL YES if it is in a selected state, NO otherwise.
 */
- (void) setSelected: (BOOL) theBOOL;

/*!
 @result The highest MSN known locally.
 */
- (NSUInteger) lastMSN;

/*!
 @result The lowest UID of all the messages contained (locally) in that folder.
 */
- (NSUInteger) firstUID;

/*!
 @discussion This can be more efficiently implemented than `[lastMessage UID]`
 @result The highest UID of all the messages contained (locally) in that folder.
 */
- (NSUInteger) lastUID;

/**
 @return The message (or nil) with the given UID.
 */
- (CWIMAPMessage * _Nullable)messageByUID:(NSUInteger)uid;

/*!
 @abstract Associates the given UID with the message sequence number.
 */
- (void)matchUID:(NSUInteger)uid withMSN:(NSUInteger)msn;

/*!
 @abstract Retrieves the UID for the given MSN, if it exists.
 @result: 0 if the UID cannot be determined.
 */
- (NSUInteger)uidForMSN:(NSUInteger)msn;

/*!
 @abstract Retrieves the MSN for the given UID, if it exists.
 @result: 0 if the MSN cannot be determined.
 */
- (NSUInteger)msnForUID:(NSUInteger)uid;

/*!
 @abstract Does the given UID still exist? I.e., was it referenced in the last sync?
 */
- (BOOL)existsUID:(NSUInteger)uid;

/*!
 @abstract The set of all UIDs that were mentioned in the last sync.
 @result: An `NSSet` of all the UIDs that were mentioned in the last sync.
 */
- (NSSet * _Nonnull)existingUIDs;

/*!
 @abstract Resets the state of the gathered UID -> MSN matches
 */
- (void)resetMatchedUIDs;

/*!
 @abstract: Try to expunge the given message, if the UID can be found out.
 */
- (void)expungeMSN:(NSUInteger)msn;

@end

#endif // _Pantomime_H_CWIMAPFolder
