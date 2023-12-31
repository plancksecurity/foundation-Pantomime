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

/**
 Protected methods of CWIMAPStore.
 This header must not be accessable to clients.
 */
@interface CWIMAPStore ()

{
@private
    __block NSMutableDictionary *_folders;
    __block NSMutableDictionary *_openFolders;
    __block NSMutableDictionary *_folderStatus;
    __block NSMutableArray *_subscribedFolders;

    __block CWIMAPFolder *_selectedFolder;

    __block unsigned char _folderSeparator;
    __block int _tag;

    __block CWIMAPQueueObject *_currentQueueObject;
    
}

@end

@interface CWIMAPStore (Protected)


- (CWIMAPQueueObject * _Nullable)currentQueueObject;

- (void)setCurrentQueueObject:(CWIMAPQueueObject * _Nullable)currentQueueObject;

/*!
  @method nextTag
  @discussion This method is used to obtain the next IMAP tag
              that will be sent to the IMAP server. Normally
	      you shouldn't call this method directly.
  @result The tag as a NSData instance.
*/
- (NSData * _Nullable) nextTag;

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

/*!
 @method sendCommandInternal:info:string: ...
 @discussion This method is used to send commands to the IMAP server.
 Normally, you should not call this method directly.
 @param theCommand The IMAP command to send.
 @param theInfo The addition info to pass.
 @param string The parameter string
 */
- (void) sendCommandInternal: (IMAPCommand) theCommand  info: (NSDictionary * _Nullable) theInfo
                      string:(NSString * _Nonnull)theString;

/**
 This method is used to get the folder with the specified name and mode.
 Note: This method also selects the folder if, and only if, the folder is not
 selected already to avoid network. As aconsequence the folders EXISTS count might be outdated.
 If you have to rely on a valid EXISTS count set updateExistsCount to YES.
 @param name The name of the folder to obtain.
 @param mode The mode to use. The value is one of the PantomimeFolderMode enum.
 @param updateExistsCount if true, a valid exists count is guaranteed.
 @return A CWIMAPFolder instance.
 */
- (CWIMAPFolder *)folderForNameInternal:(NSString *)name
                                   mode:(PantomimeFolderMode)mode
                      updateExistsCount:(BOOL)updateExistsCount;

- (void)signalFolderSyncError;

- (void)signalFolderFetchCompleted;

@end


//
//
//
@interface CWIMAPQueueObject : NSObject

@property (strong, nonatomic, nullable) NSMutableDictionary *info;
@property (strong, nonatomic, nullable) NSString *arguments;
@property (strong, nonatomic, nullable) NSData *tag;
@property (nonatomic) int literal;
@property (nonatomic) IMAPCommand command;

- (id) initWithCommand: (IMAPCommand) theCommand
             arguments: (NSString *) theArguments
                   tag: (NSData *) theTag
                  info: (NSDictionary *) theInfo;
@end

NS_ASSUME_NONNULL_END
