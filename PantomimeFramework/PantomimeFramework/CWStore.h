/*
**  CWStore.h
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

#ifndef _Pantomime_H_CWStore
#define _Pantomime_H_CWStore

#import <Foundation/NSEnumerator.h>
#import <Foundation/NSString.h>

#import <PantomimeFramework/CWConstants.h>

/*!
  @const PantomimeFolderCreateCompleted
*/
extern NSString * _Nonnull PantomimeFolderCreateCompleted;

/*!
  @const PantomimeFolderCreateFailed
*/
extern NSString * _Nonnull PantomimeFolderCreateFailed;

/*!
  @const PantomimeFolderDeleteCompleted
*/
extern NSString * _Nonnull PantomimeFolderDeleteCompleted;

/*!
  @const PantomimeFolderDeleteFailed
*/
extern NSString * _Nonnull PantomimeFolderDeleteFailed;

/*!
  @const PantomimeFolderRenameCompleted
*/
extern NSString * _Nonnull PantomimeFolderRenameCompleted;

/*!
  @const PantomimeFolderRenameFailed
*/
extern NSString * _Nonnull PantomimeFolderRenameFailed;

@class CWFolder;
@class CWURLName;

/*!
  @protocol CWStore
  @discussion This protocol defines a basic set of methods that classes implementing
              the protocol must implement in order to offer all the required
	      functionalities of a message store. CWIMAPStore, CWLocalStore and CWPOP3Store
	      are classes that currently implement this protocol.
*/
@protocol CWStore

/*!
  @method defaultFolder
  @discussion This method is used to obtain the default folder
              of the receiver. For example, CWPOP3Store will always
	      return the "INBOX" folder as no other folder is
	      accessible in POP3.
  @result A CWFolder subclass instance.
*/
- (id _Nonnull) defaultFolder;


/**
 This method is used to obtain a CWFolder instance
 with the specifed name.
 Note: This method also selects the folder if, and only if, the folder has not been
 selected already. As aconsequence the folders EXISTS count might be outdated.
 If you have to rely on a valid EXISTS count set updateExistsCount to YES.
 @param theName The name of the folder to obtain.
 @param updateExistsCount if true, a valid exists count is guaranteed.
 @return A CWFolder subclass instance.
 */
- (id _Nullable) folderForName: (NSString * _Nullable) theName
             updateExistsCount: (BOOL)updateExistsCount;

/*!
  @method folderForURL:
  @discussion This method is used to obtain a Folder instance
              with the specifed URL. <i>theURL</i> must be in form which
	      is understood by the CWURLName class.
  @param theURL The URL, as a NSString instance.
  @result A CWFolder subclass instance.
*/
- (id _Nullable) folderForURL: (NSString * _Nullable) theURL;

/*!
  @method subscribedFolderEnumerator
  @discussion This method is used to get the list of subscribed
              folders on the receiver. The name of the folders
	      are returned, not actual CWFolder subclass instances.
	      This generally returns a subset of the list
	      returned by -folderEnumerator.
  @result The list of folder names.
*/
- (NSEnumerator * _Nullable) subscribedFolderEnumerator;

/*!
  @method openFoldersEnumerator
  @discussion This method is used to obtain all the CWFolder subclass
              instance which are in the open state in the receiver.
  @result The list of open folders.
*/
- (NSEnumerator * _Nullable) openFoldersEnumerator;

/*!
  @method removeFolderFromOpenFolders:
  @discussion This method is used to remove the specified folder
              from the list of open folders in the receiver.
	      Normally, you should never invoke this method directly.
  @param theFolder The CWFolder subclass instance to remove from the
                   list of open folders.
*/
- (void) removeFolderFromOpenFolders: (CWFolder * _Nullable) theFolder;

/*!
  @method folderForNameIsOpen:
  @discussion This method is used to verify if the folder
              with the specified name is in an open state
	      in the receiver.
  @result YES if it is in an open state, NO otherwise.
*/
- (BOOL) folderForNameIsOpen: (NSString * _Nullable) theName;

/*!
  @method folderTypeForFolderName:
  @discussion This method is used to obtain the folder type
              of the specified folder name. The returned value
	      is part of the folderTypeForFolderName enum.
  @param theName The name of the folder.
  @result The type of the folder.
*/
- (PantomimeFolderAttribute) folderTypeForFolderName: (NSString * _Nullable) theName;

/*!
  @method folderSeparator
  @discussion This method is used to obtain the folder separator
              of the receiver. The separator hierarchically
	      separates folders. Returned values are generatlly
	      either '/' or '.'.
  @result The folder separator, 0 if none was set. For example,
          in CWIMAPStore, this method will return NULL if -folderEnumerator
	  or -subscribedFolderEnumerator was not invoked before
	  calling this method.
*/
- (unsigned char) folderSeparator;

/*!
  @method close
  @discussion This method is used to close the receiver.
              Classes implementing the CWStore protocol will
	      also release all resources, like open folders,
	      CWConnection instances, etc.
*/
- (void) close;

/*!
  @method createFolderWithName:type:contents:
  @discussion This method is used to create a new folder
              with the specified name, type and contents.
	      On success, it posts the PantomimeFolderCreateCompleted notification
	      and calls -folderCreateCompleted: on the delegate.
	      On failure, it posts the PantomimeFolderCreateFailed notification
	      and calls -folderCreateFailed: on the delegate.
  @param theName The name of the folder to create. It must be a full path.
  @param theType The folder type. Accepted values are part of the PantomimeFolderFormat enum.
  @param theContents The initial content of the folder. It must be in mbox format.
*/
- (void) createFolderWithName: (NSString * _Nullable) theName
                         type: (PantomimeFolderFormat) theType
                     contents: (NSData * _Nullable) theContents;

/*!
  @method deleteFolderWithName:
  @discussion This method is used to delete the folder
              specified by <i>theName</i>. On success, it posts the
	      PantomimeFolderDeleteCompleted notification. On error, it posts
	      the PantomimeFolderDeleteFailed notification.
  @param theName The name of the folder to delete.
*/
- (void) deleteFolderWithName: (NSString * _Nullable) theName;

/*!
  @method renameFolderWithName:toName:
  @discussion This method is used to rename a folder. On success, this method
              posts a PantomimeFolderRenameCompleted notification. On error,
	      it posts a PantomimeFolderRenameFailed notification.
  @param theName The name of the folder to rename.
  @param theNewName The name of the folder to rename it to.
*/
- (void) renameFolderWithName: (NSString * _Nullable) theName
                       toName: (NSString * _Nullable) theNewName;
@end

#endif // _Pantomime_H_CWStore
