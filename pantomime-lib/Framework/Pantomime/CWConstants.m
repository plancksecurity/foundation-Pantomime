/*
**  CWConstants.m
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

#import <Foundation/NSString.h>

NSString * _Nonnull const PantomimeFolderNameToIgnore = @"4f2aced6-841e-11e7-bb31-be2e44b06b34-4f2ad174-4f2ad660-8c922935-d7cf-4d64-b581-98d2c3e8f231-b566909b-1f15-44a5-a2e3-53b4c5f3f58c";
NSString * _Nonnull const PantomimeIMAPDefaultDescriptors = @"(UID FLAGS RFC822.SIZE BODY[HEADER])";
NSString * _Nonnull const PantomimeIMAPFullBody = @"(UID BODY[TEXT])";

// CWDNSManager notifications
NSString* PantomimeDNSResolutionCompleted = @"PantomimeDNSResolutionCompleted";
NSString* PantomimeDNSResolutionFailed = @"PantomimeDNSResolutionFailed";

// CWFolder notifications
NSString* PantomimeFolderAppendCompleted = @"PantomimeFolderAppendCompleted";
NSString* PantomimeFolderAppendFailed = @"PantomimeFolderAppendFailed";
NSString* PantomimeFolderCloseCompleted = @"PantomimeFolderCloseCompleted";
NSString* PantomimeFolderCloseFailed = @"PantomimeFolderAppendFailed";
NSString* PantomimeFolderExpungeCompleted = @"PantomimeFolderExpungeCompleted";
NSString* PantomimeFolderExpungeFailed = @"PantomimeFolderExpungeFailed";
NSString* PantomimeFolderListCompleted = @"PantomimeFolderListCompleted";
NSString* PantomimeFolderListFailed = @"PantomimeFolderListFailed";
NSString* PantomimeFolderListSubscribedCompleted = @"PantomimeFolderListSubscribedCompleted";
NSString* PantomimeFolderListSubscribedFailed = @"PantomimeFolderListSubscribedFailed";
NSString* PantomimeFolderOpenCompleted = @"PantomimeFolderOpenCompleted";
NSString* PantomimeFolderOpenFailed = @"PantomimeFolderOpenFailed";
NSString* PantomimeFolderSyncCompleted = @"PantomimeFolderSyncCompleted";
NSString* PantomimeFolderSyncFailed = @"PantomimeFolderSyncFailed";
NSString* PantomimeFolderFetchCompleted = @"PantomimeFolderFetchCompleted";
NSString* PantomimeFolderFetchFailed = @"PantomimeFolderFetchFailed";
NSString* PantomimeFolderSearchCompleted = @"PantomimeFolderSearchCompleted";
NSString* PantomimeFolderSearchFailed = @"PantomimeFolderSearchFailed";
NSString* PantomimeFolderNameParsed = @"PantomimeFolderNameParsed";

NSString * PantomimeFolderInfo = @"PantomimeFolderInfo";
NSString * PantomimeFolderNameKey = @"PantomimeFolderNameKey";
NSString * PantomimeFolderFlagsKey = @"PantomimeFolderFlagsKey";
NSString * PantomimeFolderSeparatorKey = @"PantomimeFolderSeparatorKey";
NSString * PantomimeFolderSpecialUseKey = @"PantomimeFolderSpecialUseKey";

// CWIMAPFolder notifications
NSString* PantomimeMessageUidMoveCompleted = @"PantomimeMessageUidMoveCompleted";
NSString* PantomimeMessageUidMoveFailed = @"PantomimeMessageUidMoveFailed";
NSString* PantomimeMessagesCopyCompleted = @"PantomimeMessagesCopyCompleted";
NSString* PantomimeMessagesCopyFailed = @"PantomimeMessagesCopyFailed";
NSString* PantomimeMessageStoreCompleted = @"PantomimeMessageStoreCompleted";
NSString* PantomimeMessageStoreFailed = @"PantomimeMessageStoreFailed";

// CWIMAPStore notifications
NSString *PantomimeFolderStatusCompleted = @"PantomimeFolderStatusCompleted";
NSString *PantomimeFolderStatusFailed = @"PantomimeFolderStatusFailed";
NSString *PantomimeFolderSubscribeCompleted = @"PantomimeFolderSubscribeCompleted";
NSString *PantomimeFolderSubscribeFailed = @"PantomimeFolderSubscribeFailed";
NSString *PantomimeFolderUnsubscribeCompleted = @"PantomimeFolderUnsubscribeCompleted";
NSString *PantomimeFolderUnsubscribeFailed = @"PantomimeFolderUnsubscribeFailed";
NSString *PantomimeActionFailed = @"PantomimeActionFailed";
NSString *PantomimeBadResponseInfoKey = @"PantomimeBadResponseInfoKey";
NSString *PantomimeErrorInfo = @"PantomimeErrorInfo";
NSString *PantomimeBadResponse = @"PantomimeBadResponse";
NSString *PantomimeIdleEntered = @"PantomimeIdleEntered";
NSString *PantomimeIdleNewMessages = @"PantomimeIdleNewMessages";
NSString *PantomimeIdleFinished = @"PantomimeIdleFinished";

// CWMessage notifications
NSString* PantomimeMessageChanged = @"PantomimeMessageChanged";
NSString* PantomimeMessageExpunged = @"PantomimeMessageExpunged";
NSString* PantomimeMessageFetchCompleted = @"PantomimeMessageFetchCompleted";
NSString* PantomimeMessageFetchFailed = @"PantomimeMessageFetchFailed";
NSString* PantomimeMessagePrefetchCompleted = @"PantomimeMessagePrefetchCompleted";
NSString* PantomimeMessagePrefetchFailed = @"PantomimeMessagePrefetchFailed";

// CWService notifications
NSString* PantomimeProtocolException = @"PantomimeProtocolException";
NSString* PantomimeAuthenticationCompleted = @"PantomimeAuthenticationCompleted";
NSString* PantomimeAuthenticationFailed = @"PantomimeAuthenticationFailed";
NSString* PantomimeConnectionEstablished = @"PantomimeConnectionEstablished";
NSString* PantomimeConnectionLost = @"PantomimeConnectionLost";
NSString* PantomimeConnectionTerminated = @"PantomimeConnectionTerminated";
NSString* PantomimeConnectionTimedOut = @"PantomimeConnectionTimedOut";
NSString* PantomimeRequestCancelled = @"PantomimeRequestCancelled";
NSString* PantomimeServiceInitialized = @"PantomimeServiceInitialized";
NSString* PantomimeServiceReconnected = @"PantomimeServiceReconnected";
NSString *PantomimeErrorExtra = @"PantomimeErrorExtra";

// CWSMTP notifications
NSString* PantomimeRecipientIdentificationCompleted = @"PantomimeRecipientIdentificationCompleted";
NSString* PantomimeRecipientIdentificationFailed = @"PantomimeRecipientIdentificationFailed";
NSString* PantomimeTransactionInitiationCompleted = @"PantomimeTransactionInitiationCompleted";
NSString* PantomimeTransactionInitiationFailed = @"PantomimeTransactionInitiationFailed";
NSString* PantomimeTransactionResetCompleted = @"PantomimeTransactionResetCompleted";
NSString* PantomimeTransactionResetFailed = @"PantomimeTransactionResetFailed";

// CWStore notifications
NSString* PantomimeFolderCreateCompleted = @"PantomimeFolderCreateCompleted";
NSString* PantomimeFolderCreateFailed = @"PantomimeFolderCreateFailed";
NSString* PantomimeFolderDeleteCompleted = @"PantomimeFolderDeleteCompleted";
NSString* PantomimeFolderDeleteFailed = @"PantomimeFolderDeleteFailed";
NSString* PantomimeFolderRenameCompleted = @"PantomimeFolderRenameCompleted";
NSString* PantomimeFolderRenameFailed = @"PantomimeFolderRenameFailed";

// CWTransport notifications
NSString* PantomimeMessageNotSent = @"PantomimeMessageNotSent";
NSString* PantomimeMessageSent = @"PantomimeMessageSent";

NSString *PantomimeMessagesKey = @"PantomimeMessagesKey";
NSString *PantomimeFlagsKey = @"PantomimeFlagsKey";
