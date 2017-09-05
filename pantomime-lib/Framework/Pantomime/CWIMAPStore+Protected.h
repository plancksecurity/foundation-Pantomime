//
//  CWIMAPStore+Protected.h
//  Pantomime
//
//  Created by Andreas Buff on 05.09.17.
//  Copyright © 2017 pEp Security S.A. All rights reserved.
//

#import "CWIMAPStore.h"
#import "CWService+Protected.h"

NS_ASSUME_NONNULL_BEGIN

@interface CWIMAPStore (Protected)

/*!
 @method folderForName:select:
 @discussion This method is used to obtain the folder with
 the specified name. If <i>aBOOL</i> is YES,
 the folder will be selected. Otherwise, a non-selected
 folder will be returned which is used to proceed with
 an append operation. Note that when <i>aBOOL</i> is
 equal to NO, the returned folder is NOT part of the
 list of opened folders.
 @param theName The name of the folder to obtain.
 @param aBOOL YES to select the folder, NO otherwise.
 @result A CWIMAPFolder instance.
 */
- (CWIMAPFolder * _Nullable) folderForName: (NSString * _Nullable) theName
                                    select: (BOOL) aBOOL;

- (CWIMAPFolder *)folderWithName:(NSString *)name;

//BUFF: hide?
/*!
  @method nextTag
  @discussion This method is used to obtain the next IMAP tag
              that will be sent to the IMAP server. Normally
	      you shouldn't call this method directly.
  @result The tag as a NSData instance.
*/
- (NSData * _Nullable) nextTag;


//BUFF: hide?
/*!
  @method lastTag
  @discussion This method is used to obtain the last IMAP tag
              sent to the IMAP server.
  @result The tag as a NSData instance.
*/
- (NSData * _Nullable) lastTag;

/*!
 @method subscribeToFolderWithName:
 @discussion This method is used to subscribe to the specified folder.
 The method will post a PantomimeFolderSubscribeCompleted notification
 (and call -folderSubscribeCompleted: on the delegate, if any) if
 it succeeded. If not, it will post a PantomimeFolderSubscribeFailed
 notification (and call -folderSubscribeFailed: on the delegate, if any)
 @param theName The name of the folder to subscribe to.
 */
- (void) subscribeToFolderWithName: (NSString * _Nullable) theName;

/*!
 @method unsubscribeToFolderWithName:
 @discussion This method is used to unsubscribe to the specified folder.
 The method will post a PantomimeFolderUnsubscribeCompleted notification
 (and call -folderUnsubscribeCompleted: on the delegate, if any) if
 it succeeded. If not, it will post a PantomimeFolderUnsubscribeFailed
 notification (and call -folderUnsubscribeFailed: on the delegate, if any)
 @param theName The name of the folder to subscribe to.
 */
- (void) unsubscribeToFolderWithName: (NSString * _Nullable) theName;

/*!
 @method folderStatus:
 @discussion This method is used to obtain the status of the specified
 folder names in <i>theArray</i>. It is fully asynchronous.
 The first time it is invoked, it'll perform its work asynchronously
 and post a PantomimeFolderStatusCompleted notification (and call
 -folderStatusCompleted on the delegate, if any) if succeeded. If not,
 it will post a PantomimeFolderStatusFailed notification (and call
 -folderStatusFailed: on the delegate, if any). Further calls
 of this method on the same set of folders will immediately return
 the status information.
 @param theArray The array of folder names.
 @result A NSDictionary instance for which the keys are the folder names (NSString instance)
 and the values are CWFolderInformation instance if the information was
 loaded, nil otherwise.
 */
- (NSDictionary * _Nullable) folderStatus: (NSArray * _Nullable) theArray;

/*!
 @method sendCommand:info:arguments: ...
 @discussion This method is used to send commands to the IMAP server.
 Normally, you should not call this method directly.
 @param theCommand The IMAP command to send.
 @param theInfo The addition info to pass.
 @param theFormat The format defining the variable arguments list.
 */
- (void) sendCommand: (IMAPCommand) theCommand  info: (NSDictionary * _Nullable) theInfo  arguments: (NSString *) theFormat, ...;

- (void)signalFolderSyncError;

@end

NS_ASSUME_NONNULL_END
