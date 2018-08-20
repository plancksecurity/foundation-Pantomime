/*
**  CWFolder.h
**
**  Copyright (c) 2001-2006
**                2013 Free Software Foundation
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

#ifndef _Pantomime_H_CWFolder
#define _Pantomime_H_CWFolder

#import <Foundation/NSArray.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

#import "Pantomime/CWConstants.h"

@class CWFlags;
@class CWMessage;

/*!
  @const PantomimeFolderAppendCompleted
*/
extern NSString * _Nonnull const PantomimeFolderAppendCompleted;

/*!
  @const PantomimeFolderAppendFailed
*/
extern NSString * _Nonnull const PantomimeFolderAppendFailed;

/*!
  @const PantomimeFolderCloseCompleted
*/
extern NSString * _Nonnull const PantomimeFolderCloseCompleted;

/*!
  @const PantomimeFolderCloseFailed
*/
extern NSString * _Nonnull const PantomimeFolderCloseFailed;

/*!
  @const PantomimeFolderExpungeCompleted
*/
extern NSString * _Nonnull const PantomimeFolderExpungeCompleted;

/*!
  @const PantomimeFolderExpungeFailed
*/
extern NSString * _Nonnull const PantomimeFolderExpungeFailed;

/*!
  @const PantomimeFolderListCompleted
*/
extern NSString * _Nonnull const PantomimeFolderListCompleted;

/*!
  @const PantomimeFolderListFailed
*/
extern NSString * _Nonnull const PantomimeFolderListFailed;

/*!
  @const PantomimeFolderListSubscribedCompleted
*/
extern NSString * _Nonnull const PantomimeFolderListSubscribedCompleted;

/*!
  @const PantomimeFolderListSubscribedFailed
*/
extern NSString * _Nonnull const PantomimeFolderListSubscribedFailed;

/*!
  @const PantomimeFolderOpenCompleted
*/
extern NSString * _Nonnull const PantomimeFolderOpenCompleted;

/*!
  @const PantomimeFolderOpenFailed
*/
extern NSString * _Nonnull const PantomimeFolderOpenFailed;

/*!
  @const PantomimeFolderFetchCompleted
*/
extern NSString * _Nonnull const PantomimeFolderFetchCompleted;

/*!
 @const PantomimeFolderSyncCompleted
 */
extern NSString * _Nonnull const PantomimeFolderSyncCompleted;

/*!
 @const PantomimeFolderSyncFailed
 */
extern NSString * _Nonnull const PantomimeFolderSyncFailed;

/*!
  @const PantomimeFolderFetchFailed
*/
extern NSString * _Nonnull const PantomimeFolderFetchFailed;

/*!
  @const PantomimeFolderSearchCompleted
*/
extern NSString * _Nonnull const PantomimeFolderSearchCompleted;

/*!
  @const PantomimeFolderSearchFailed
*/
extern NSString * _Nonnull const PantomimeFolderSearchFailed;

/*!
 @const PantomimeFolderNameParsed
 @discussion Notification name for when a folder has been parsed in response to a LIST.
 */
extern NSString * _Nonnull const PantomimeFolderNameParsed;

/*!
 @const PantomimeFolderInfo
 @discussion Name for the key into the dictionary sent to the delegate for
 receiving folders in response to LIST commands.
 */
extern NSString * _Nonnull const PantomimeFolderInfo;

/*!
 @const PantomimeFolderNameKey
 @discussion Key name for folder name in a user info dictionary for
   PantomimeFolderNameParsed notifications.
 */
extern NSString * _Nonnull const PantomimeFolderNameKey;

/*!
 @const PantomimeFolderFlagsKey
 @discussion Key name for folder flags in a user info dictionary for
   PantomimeFolderNameParsed notifications.
 */
extern NSString * _Nonnull const PantomimeFolderFlagsKey;

/*!
 @const PantomimeFolderSeparatorKey
 @discussion Key name for folder separator in a user info dictionary for
 PantomimeFolderNameParsed notifications.
 */
extern NSString * _Nonnull const PantomimeFolderSeparatorKey;

/*!
  @category NSObject (PantomimeFolderDelegate)
  @discussion This informal protocol defines methods that can implemented in
              CWFolder's delegate to control the behavior of the class 
	      or to obtain status information.
*/
@protocol PantomimeFolderDelegate

@optional

/*!
  @method folderAppendCompleted:
  @discussion This method is automatically invoked on the store's
              delegate in order to indicate that the last
	      message append operation was sucessful.
	      A PantomimeFolderAppendCompleted notification is
	      also posted.
  @param theNotification The notification holding the information.
*/
- (void) folderAppendCompleted: (NSNotification * _Nullable) theNotification;

/*!
  @method folderAppendFailed:
  @discussion This method is automatically invoked on the store's
              delegate in order to indicate that the last
	      message append operation failed.
	      A PantomimeFolderAppendCompleted notification is
	      also posted.
  @param theNotification The notification holding the information.
*/
- (void) folderAppendFailed: (NSNotification * _Nullable) theNotification;

/*!
  @method folderCloseCompleted
  @discussion This method is automatically invoked on the store's
              delegate in order to indicate that the close
	      operation completed.
  @param theNotification The notification holding the information.
 */
- (void) folderCloseCompleted: (NSNotification * _Nullable) theNotification;

/*!
  @method folderCloseFailed
  @discussion This method is automatically invoked on the store's
              delegate in order to indicate that the close
	      operation failed.
  @param theNotification The notification holding the information.
 */
- (void) folderCloseFailed: (NSNotification * _Nullable) theNotification;

/*!
  @method folderExpungeCompleted
  @discussion This method is automatically invoked on the store's
              delegate in order to indicate that the expunge
	      operation completed.
  @param theNotification The notification holding the information.
 */
- (void) folderExpungeCompleted: (NSNotification * _Nullable) theNotification;

/*!
  @method folderExpungeFailed
  @discussion This method is automatically invoked on the store's
              delegate in order to indicate that the expunge
	      operation failed.
  @param theNotification The notification holding the information.
 */
- (void) folderExpungeFailed: (NSNotification * _Nullable) theNotification;

/*!
  @method folderListCompleted
  @discussion This method is automatically invoked on the store's
              delegate in order to indicate that the mailbox listing
	      operation completed.
  @param theNotification The notification holding the information.
 */
- (void) folderListCompleted: (NSNotification * _Nullable) theNotification;

/*!
  @method folderListFailed
  @discussion This method is automatically invoked on the store's
              delegate in order to indicate that the mailbox listing
	      operation failed.
  @param theNotification The notification holding the information.
 */
- (void) folderListFailed: (NSNotification * _Nullable) theNotification;

/*!
  @method folderListSubscribedCompleted
  @discussion This method is automatically invoked on the store's
              delegate in order to indicate that the listing operation
	      of subscribed mailboxes completed.
  @param theNotification The notification holding the information.
 */
- (void) folderListSubscribedCompleted: (NSNotification * _Nullable) theNotification;

/*!
  @method folderListSuscribedFailed
  @discussion This method is automatically invoked on the store's
              delegate in order to indicate that the listing operation
	      of subscribed mailboxes failed.
  @param theNotification The notification holding the information.
 */
- (void) folderListSubscribedFailed: (NSNotification * _Nullable) theNotification;

/*!
  @method folderOpenCompleted
  @discussion This method is automatically invoked on the store's
              delegate in order to indicate that the open
	      operation completed.
  @param theNotification The notification holding the information.
 */
- (void) folderOpenCompleted: (NSNotification * _Nullable) theNotification;

/*!
  @method folderOpenFailed
  @discussion This method is automatically invoked on the store's
              delegate in order to indicate that the open
	      operation failed.
  @param theNotification The notification holding the information.
 */
- (void) folderOpenFailed: (NSNotification * _Nullable) theNotification;

/*!
  @method folderFetchCompleted
  @discussion This method is automatically invoked on the store's
              delegate in order to indicate that the fetch
	      operation completed.
  @param theNotification The notification holding the information.
 */
- (void) folderFetchCompleted: (NSNotification * _Nullable) theNotification;

/*!
 @method folderSyncCompleted
 @discussion This method is automatically invoked on the store's
 delegate in order to indicate that the flags sync
 operation completed.
 @param theNotification The notification holding the information.
 */
- (void) folderSyncCompleted: (NSNotification * _Nullable) theNotification;

/*!
 @method folderSyncFailed
 @discussion This method is automatically invoked on the store's
 delegate in order to indicate that the flags sync
 operation failed.
 @param theNotification The notification holding the information.
 */
- (void) folderSyncFailed: (NSNotification * _Nullable) theNotification;

/*!
  @method folderFetchFailed
  @discussion This method is automatically invoked on the store's
              delegate in order to indicate that the fetch
	      operation failed.
  @param theNotification The notification holding the information.
 */
- (void) folderFetchFailed: (NSNotification * _Nullable) theNotification;

/*!
  @method folderSearchCompleted
  @discussion This method is automatically invoked on the store's
              delegate in order to indicate that the search
	      operation completed.
  @param theNotification The notification holding the information.
 */
- (void) folderSearchCompleted: (NSNotification * _Nullable) theNotification;

/*!
  @method folderSearchFailed
  @discussion This method is automatically invoked on the store's
              delegate in order to indicate that the search
	      operation failed.
  @param theNotification The notification holding the information.
 */
- (void) folderSearchFailed: (NSNotification * _Nullable) theNotification;

/*!
 @discussion Called when there has been a folder name parsed
   typically in response to a LIST command).
 @param theNotification The notification holding some information.
 */
- (void) folderNameParsed: (NSNotification * _Nullable) theNotification;

@end

/*!
  @class CWFolder
  @abstract A CWFolder object holds CWMessage instances.
  @discussion This abstract class is used to represent a folder which holds messages.
              A folder is a synonym for mailbox. Normally, you should never create
              an instance of CWFolder directly but rather use the subclasses which
	      are CWIMAPFolder, CWLocalFolder and CWPOP3Folder. Futhermore, the corresponding
	      CWStore classes will instanciate the CWFolder subclasses for you.
*/
@interface CWFolder : NSObject 
{

@protected
    NSMutableDictionary *_properties;
    NSString *_name;

    __weak id _cacheManager;
    __weak id _store;

    NSMutableArray *_allVisibleMessages;
    NSMutableArray *_allContainers;
   
    BOOL _show_deleted;
    BOOL _show_read;

    PantomimeFolderMode _mode;
}

/*!
  @method initWithName:
  @discussion This method initialize a folder with the
              specified name. The name can contain folder
	      separators in order to create subfolders.
	      The separator can be obtained from a
	      class that implements the CWStore protocol.
  @param theName The full path of the folder.
  @result The folder, nil in case of an error.
*/
- (id _Nonnull) initWithName: (NSString * _Nonnull) theName;

/*!
  @method name
  @discussion This method returns the name of the folder.
  @result The full name of the folder.
*/
- (NSString * _Nonnull) name;

/*!
  @method setName:
  @discussion Sets the name of a folder.
  @param theName The name of the folder.
*/
- (void) setName: (NSString * _Nonnull) theName;

/*!
  @method appendMessage:
  @discussion This method is used to add a message to
              a CWFolder instance. This method will NOT add
	      the message to the underlying store. You MUST
	      use -appendMessageFromRawSource: flags: if you
	      want the message to be saved to the underlying
	      store. Generally, you should not use this
	      method directly. If the folder was threaded,
	      this method will NOT thread the appended message.
  @param theMessage The message to append to the folder.
*/
- (void) appendMessage: (CWMessage * _Nonnull) theMessage;


/*!
  @method appendMessageFromRawSource:flags:
  @discussion This method is used to append a message
              from its raw source representation (RFC2822 compliant)
	      to the underlying store. This method will raise an
	      exception if it's invoked on an instance of CWFolder or
	      CWPOP3Folder instead of an instance of CWIMAPFolder and CWLocalFolder.
	      If the folder was threaded, this method will NOT thread the appended message.
	      Methods will be invoked on the delegate and notifications
	      will be posted. See the PantomimeFolderDelegate informal
	      protocol for more details.
  @param theData The raw representation of the message to append.
  @param theFlags The flags of the message, nil if no flags need to be kept.
*/
- (void) appendMessageFromRawSource: (NSData * _Nonnull) theData
                              flags: (CWFlags * _Nullable) theFlags;

/*!
  @method allMessages
  @discussion This method is used to obtain all visible messages
              in the CWFolder instance. It hides messages marked
	      as Deleted if -setShowDeleted: was invoked with
	      NO as the parameter and the the same for messages
	      marked as read (see -setShowRead:). Note that the
	      messages MIGHT NOT been all completely initialized.
  @result An array of all visible messages.
*/
- (NSArray * _Nonnull) allMessages;

/*!
  @method setMessages:
  @discussion This method is used to replace all messages in the
               CWFolder instance by the ones specified in the array.
	       Normally, you shouldn't use this method directly.
  @param theMessages The array of messages.
*/
- (void) setMessages: (NSArray * _Nonnull) theMessages;

/*!
  @method messageAtIndex:
  @discussion This method is used to obtain the message at the
              specified index (which is zero-based). If the index
	      is out of bounds, nil is returned.
  @param theIndex The index of the message.
  @result The message at the specified index, nil otherwise.
*/
- (CWMessage * _Nullable) messageAtIndex: (NSUInteger) theIndex;

/*!
  @method count
  @discussion This method is used to obtain the number of messages
              present in the folder. Hidden messages will NOT
	      be part of the value returned. So, for example, if
	      a folder has 10 messages, 2 of them have the
	      PantomimeFlagDeleted flag set and -setShowDeleted: NO was
	      invoked on the folder, this method will return
	      8 as the messages count.
  @result The number of messages in the folder.
*/
- (NSUInteger) count;

/*!
  @method close
  @discussion This method is used to close the folder. 
              The subclasses of CWFolder MUST this method.
*/
- (void) close;

/*!
  @method expunge:
  @discussion This method is used to permanently remove
              messages marked as deleted in the folder.
*/
- (void) expunge;

/*!
  @method store
  @discussion This method returns the associated store
              to this folder. This will generally be an instance
	      of CWIMAPStore, CWLocalStore or CWPOP3Store.
  @result The associated store.
*/
- (id _Nonnull) store;

/*!
  @method setStore:
  @discussion This method is used to set the associated store
              to this folder. The store will NOT be retained
	      since it is the store which holds and retains
              the CWFolder instances.
  @param theStore The associated store.
*/
- (void) setStore: (id _Nonnull) theStore;

/*!
  @method removeMessage:
  @discussion  This method removes permenantly a message from 
               the folder. It is used when transferring message 
	       between folders in order to update the view or 
	       when expunge deletes messages from a view. If the
	       folder is threaded, this method will rethread the
	       folder before returning.
  @param theMessage The CWMessage instance to remove from the folder.
*/
- (void) removeMessage: (CWMessage * _Nonnull) theMessage;

/*!
  @method showDeleted
  @discussion This method returns YES if messages marked as deleted
              are shown in this folder, NO otherwise.
  @result A BOOL corresponding to the value.
*/
- (BOOL) showDeleted;

/*!
  @method setShowDeleted:
  @discussion This method is used to specify if we want to show or
              hide messages marked as deleted in this folder.
  @param theBOOL YES if we want to hide messages marked as deleted,
                 NO otherwise.
*/
- (void) setShowDeleted: (BOOL) theBOOL;

/*!
  @method showRead
  @discussion This method returns YES if messages marked as read
              are shown in this folder, NO otherwise.
  @result A BOOL corresponding to the value.
*/
- (BOOL) showRead;

/*!
  @method setShowRead:
  @discussion This method is used to specify if we want to show or
              hide messages marked as read in this folder.
  @param theBOOL YES if we want to hide messages marked as read,
                 NO otherwise.
*/
- (void) setShowRead: (BOOL) theBOOL;

/*!
  @method numberOfDeletedMessages
  @discussion This method returns the number of messages in this
              folder that have the PantomimeFlagDeleted flag set.
  @result The number of message marked has deleted, 0 if none.
*/
- (NSUInteger) numberOfDeletedMessages;

/*!
  @method numberOfUnreadMessages
  @discussion This method returns the number of messages in this
              folder that do not have the PantomimeFlagSeen flag set.
  @result The number of unread messages, 0 if none.
*/
- (NSUInteger) numberOfUnreadMessages;

/*!
  @method size
  @discussion This method returns the size of the folder. That is,
               it returns the sum of the size of all visible messages in
	       the folder.
  @result The size of the folder.
*/
- (long) size;

/*!
  @method updateCache
  @discussion This method is used to update our cache (_allVisibleMessages).
              Applications can call this method if they set the PantomimeFlagDeleted flags to
              messages inside this folder. If not called, the cache won't be updated
              the messages having the flag PantomimeFlagDeleted will still be visible.
*/
- (void) updateCache;

/*!
  @method allContainers
  @discussion This method returns the list of root containers when using
              message threading.
  @result Root containers if using message threading, nil otherwise.
*/
- (NSArray * _Nullable) allContainers;

/*!
  @method thread
  @discussion This method implements Jamie Zawinski's message threading algorithm.
              The full algorithm is available here: http://www.jwz.org/doc/threading.html
	      After calling this method, -allContainers can be called to obtain the
	      root set of CWContainer instances.
*/
- (void) thread;

/*!
  @method unthread
  @discussion This method is used to release all resources taken by the
              message threading code. After calling this method,
	      -allContainers will return nil.
*/
- (void) unthread;

/*!
  @method search: mask: options:
  @discussion This method is used to search this folder using a criteria,
              mask and options. This method will post a PantomimeFolderSearchCompleted
	      (or invoked -folderSearchCompleted: on the delegate) once it has
	      completed its execution (or post PantomimeFolderSearchFailed or invoke
	      -folderSearchFailed on the delegate if it failed). This method will
	      do absolutely nothing on CWPOP3Folder instances as search operations
	      are not supported in POP3.
  @param theString The string to search for. This can be a regex for LocalFolder instances.
  @param theMask The mask to use. The values can be either one of the
                 PantomimeSearchMask enum. This parameter is ignored for IMAPFolder instances.
  @param theOptions The search options. Can be either PantomimeRegularExpression
                    or PantomimeCaseInsensitiveSearch. This parameter is ignored for
		    CWIMAPFolder instances.
*/
- (void) search: (NSString * _Nonnull) theString
           mask: (PantomimeSearchMask) theMask
        options: (PantomimeSearchOption) theOptions;

/*!
  @method cacheManager
  @discussion This method returns the associated cache manager for this folder.
	      For a CWIMAPFolder, a CWIMAPCacheManager instance will be returned.
              For a CWLocalFolder, a CWLocalFolderCacheManager instance will be returned.
	      For a CWPOP3Folder, a CWPOP3CacheManager instance will be returned.
  @result The associated cache manager instance, nil otherwise.
*/
- (id _Nullable) cacheManager;

/*!
  @method setCacheManager:
  @discussion This method is used to set the respective cache manager instance
              for this folder. Instance of CWIMAPCacheManager, CWLocalFolderCacheManager
	      or CWPOP3CacheManager will generally be used.
  @param theCacheManager The cache manager instance for this folder.
*/
- (void) setCacheManager: (id _Nonnull) theCacheManager;

/*!
  @method mode
  @discussion This method is used to get the mode of the folders. The returned
              values can be either PantomimeUnknownMode, PantomimeReadOnlyMode
	      or PantomimeReadWriteMode. Calling this method on an instance
	      of Folder (ie., not a subclass) will raise an exception.
  @result The mode of the folder.
*/
- (PantomimeFolderMode) mode;

/*!
  @method setMode:
  @discussion This method is used to adjust the mode on the specified folder.
              If has no impact on how the mailbox was open. For example,
	      if a mailbox was open as read-only, the mailbox will not
	      be re-opened as read-write after this method call.
  @param theMode The new mode.
*/
- (void) setMode: (PantomimeFolderMode) theMode;

/*!
  @method setFlags: messages:
  @discussion This method is used to set the same flags to a set of messages.
              This can be useful, especially when dealing with CWIMAPFolder
	      instances in order to NOT send many IMAP commands to the server
	      but rather send just one.
  @param theFlags The flags to set to all messages.
  @param theMessages The array of messages to which flags will be applied.
*/
- (void) setFlags: (CWFlags * _Nonnull) theFlags
         messages: (NSArray * _Nonnull) theMessages;

/*!
  @method propertyForKey:
  @discussion This method is used to get an extra property for the
              specified key.
  @result The property for the specified key, nil if key isn't found.
*/
- (id _Nullable) propertyForKey: (id _Nonnull) theKey;

/*!
  @method setProperty: forKey:
  @discussion This method is used to set an extra property for the
              specified key on this folder. If nil is passed for
	      theProperty parameter, the value will actually be
	      REMOVED for theKey.
  @param theProperty The value of the property.
  @param theKey The key of the property.
*/
- (void) setProperty: (id _Nonnull) theProperty
              forKey: (id _Nonnull) theKey;
@end

#endif // _Pantomime_H_CWFolder
