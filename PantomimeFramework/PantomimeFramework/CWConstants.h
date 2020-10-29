/*
**  CWConstants.h
**
**  Copyright (c) 2001-2007
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

#ifndef _Pantomime_H_CWConstants
#define _Pantomime_H_CWConstants

#import <Foundation/Foundation.h>

@class NSString;

//
// The current version of Pantomime.
//
#define PANTOMIME_VERSION @"1.2.0"

#if __APPLE__
#include <TargetConditionals.h>
#define MACOSX
#endif

#ifdef MACOSX

typedef NS_ENUM(NSInteger, RunLoopEventType) {
    ET_RDESC,
    ET_WDESC,
    ET_EDESC,
};

#endif

typedef NS_ENUM(NSInteger, ConnectionTransport) {
    ConnectionTransportPlain,
    ConnectionTransportTLS,
    ConnectionTransportStartTLS,
};

//
// Useful macros that we must define ourself on OS X.
//
#ifdef MACOSX 
#define RETAIN(object) object
#define RETAIN_VOID(object)
#define RELEASE(object)
#define AUTORELEASE(object) object
#define AUTORELEASE_VOID(object)
#define TEST_RELEASE(object)    ({ if (object) object = nil; })
#define ASSIGN(object,value)    ({\
id __value = (id)(value); \
id __object = (id)(object); \
if (__value != __object) \
  { \
    object = __value; \
  } \
})
#define DESTROY(object) ({ \
  if (object) \
    { \
      object = nil; \
    } \
})

#if !defined(NSLocalizedString)
#define NSLocalizedString(key, comment) \
  [[NSBundle mainBundle] localizedStringForKey:(key) value:@"" table:nil]
#endif
#define _(X) NSLocalizedString (X, @"")
#endif

//
// Only for older Mac versions
//
#if defined(__APPLE__) && (MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4)
#ifndef NSUInteger
#define NSUInteger unsigned int
#endif
#ifndef NSInteger
#define NSInteger int
#endif
#endif

//
// We must define NSObject: -subclassResponsibility: on OS X.
//
#ifdef MACOSX
#include <PantomimeFramework/CWMacOSXGlue.h>
#endif

//
// Some macros, to minimize the code.
//
#define PERFORM_SELECTOR_1(del, sel, name) ({ \
\
BOOL zBOOL; \
\
zBOOL = NO; \
\
if (del && [del respondsToSelector: sel]) \
{ \
  [del performSelector: sel \
       withObject: [NSNotification notificationWithName: name \
			    	   object: self]]; \
  zBOOL = YES; \
} \
\
zBOOL; \
})

/**
 Sends a message to the delegate, with a notification as parameter.

 @param del The delegate to send the message to.
 @param sel The selector to invoke on the delegate.
 @param name The name of the notification.
 @param obj The keypair (obj, value) will be the content of the notification info dictionary.
 @param key The keypair (obj, value) will be the content of the notification info dictionary.
 @return Nothing returned.
 */
#define PERFORM_SELECTOR_2(del, sel, name, obj, key) \
if (del && [del respondsToSelector: sel]) \
{ \
  [del performSelector: sel \
       withObject: [NSNotification notificationWithName: name \
                   object: self \
                   userInfo: [NSDictionary dictionaryWithObject: obj forKey: key]]]; \
}

#define PERFORM_SELECTOR_3(del, sel, name, info) \
if (del && [del respondsToSelector: sel]) \
{ \
  [del performSelector: sel \
       withObject: [NSNotification notificationWithName: name \
				   object: self \
				   userInfo: info]]; \
}

#define AUTHENTICATION_COMPLETED(del, s) \
PERFORM_SELECTOR_2(del, @selector(authenticationCompleted:), PantomimeAuthenticationCompleted, ((id)s?(id)s:(id)@""), @"Mechanism");


#define AUTHENTICATION_FAILED(del, s) \
PERFORM_SELECTOR_2(del, @selector(authenticationFailed:), PantomimeAuthenticationFailed, ((id)s?(id)s:(id)@""), @"Mechanism");

/*!
  @typedef PantomimeEncoding
  @abstract Supported encodings.
  @discussion This enum lists the supported Content-Transfer-Encoding
              values. See RFC 2045 - 6. Content-Transfer-Encoding Header Field
	      (all all sub-sections) for a detailed description of the
	      possible values.
  @constant PantomimeEncodingNone No encoding.
  @constant PantomimeEncoding7bit No encoding, same value as PantomimeEncodingNone.
  @constant PantomimeEncodingQuotedPrintable The quoted-printable encoding.
  @constant PantomimeEncodingBase64 The base64 encoding.
  @constant PantomimeEncoding8bit Identity encoding.
  @constant PantomimeEncodingBinary Identity encoding.
*/
typedef enum
{
  PantomimeEncodingNone = 0,
  PantomimeEncoding7bit = 0,
  PantomimeEncodingQuotedPrintable = 1,
  PantomimeEncodingBase64 = 2,
  PantomimeEncoding8bit = 3,
  PantomimeEncodingBinary = 4
} PantomimeEncoding;


/*!
  @typedef PantomimeFolderFormat
  @abstract The supported folder formats.
  @discussion Pantomime supports various local folder formats. Currently,
              the mbox and maildir formats are supported. Also, a custom
	      format is defined to represent folder which holds folders
	      (ie., not messages).
  @constant PantomimeFormatMbox The mbox format.
  @constant PantomimeFormatMaildir The maildir format.
  @constant PantomimeFormatMailSpoolFile The mail spool file, in mbox format but without cache synchronization.
  @constant PantomimeFormatFolder Custom format.
*/
typedef enum {
  PantomimeFormatMbox = 0,
  PantomimeFormatMaildir = 1,
  PantomimeFormatMailSpoolFile = 2,
  PantomimeFormatFolder = 3
} PantomimeFolderFormat;


/*!
  @typedef PantomimeMessageFormat
  @abstract The format of a message.
  @discussion Pantomime supports two formats when encoding
              plain/text parts. The formats are described in RFC 2646.
  @constant PantomimeFormatUnknown Unknown format.
  @constant PantomimeFormatFlowed The "format=flowed" is used.
*/
typedef enum
{
  PantomimeFormatUnknown = 0,
  PantomimeFormatFlowed = 1
} PantomimeMessageFormat;


/*!
  @typedef PantomimeFlag
  @abstract Valid message flags.
  @discussion This enum lists valid message flags. Flags can be combined
              using a bitwise OR.
  @constant PantomimeFlagAnswered The message has been answered.
  @constant PantomimeFlagDraft The message is an unsent, draft message.
  @constant PantomimeFlagFlagged The message is flagged.
  @constant PantomimeFlagRecent The message has been recently received.
  @constant PantomimeFlagSeen The message has been read.
  @constant PantomimeFlagDeleted The message is marked as deleted.
*/
typedef NS_ENUM(NSUInteger, PantomimeFlag)
{
  PantomimeFlagAnswered = 1,
  PantomimeFlagDraft = 2,
  PantomimeFlagFlagged = 4,
  PantomimeFlagRecent = 8,
  PantomimeFlagSeen = 16,
  PantomimeFlagDeleted = 32
};


/*!
  @typedef PantomimeFolderType
  @abstract Flags/name attributes for mailboxes/folders.
  @discussion This enum lists the potential mailbox / folder
              flags which some IMAP servers can enforce.
	      Those flags have few meaning for POP3 and
	      Local mailboxes. Flags can be combined using
	      a bitwise OR.
  @constant PantomimeHoldsFolders The folder holds folders.
  @constant PantomimeHoldsMessages The folder holds messages.
  @constant PantomimeNoInferiors The folder has no sub-folders.
  @constant PantomimeNoSelect The folder can't be opened.
  @constant PantomimeMarked The folder is marked as "interesting".
  @constant PantomimeUnmarked The folder does not contain any new
                              messages since the last time it has been open.
*/
typedef enum
{
  PantomimeHoldsFolders = 1,
  PantomimeHoldsMessages = 2,
  PantomimeNoInferiors = 4,
  PantomimeNoSelect = 8,
  PantomimeMarked = 16,
  PantomimeUnmarked = 32
} PantomimeFolderAttribute;

/*!
 @typedef PantomimeSpecialUseMailboxType
 @abstract Special-Use attributes for mailboxes/folders. RFC 6154.
 @discussion This enum lists the potential Special-Uses of mailbox / folder.
 Even it is not defined in RFC 6154, common sense suggests a folder can have no or one special-use, thus the 
 flags can not be combined using a bitwise OR.
 
 @constant PantomimeSpecialUseMailboxNormal This mailbox has no special-use

 @constant PantomimeSpecialUseMailboxAll This mailbox presents all messages in the user's message store.
 Implementations MAY omit some messages, such as, perhaps, those in \Trash and \Junk.
 When this special use is supported, it is almost certain to represent a virtual mailbox.

 @constant PantomimeSpecialUseMailboxArchive This mailbox is used to archive messages.  
 The meaning of an "archival" mailbox is server-dependent; typically, it will be used to get messages out 
 of the inbox, or otherwise keep them out of the user's way, while still making them accessible.

 @constant PantomimeSpecialUseMailboxDrafts This mailbox is used to hold draft messages
 Typically messages that are being composed but have not yet been sent.  In some server implementations, 
 this might be a virtual mailbox, containing messages from other mailboxes that are marked with the "\Draft" 
 message flag.  Alternatively, this might just be advice that a client put drafts here.

 @constant PantomimeSpecialUseMailboxFlagged This mailbox presents all messages marked in some way as
 "important".  When this special use is supported, it is likely
 to represent a virtual mailbox collecting messages (from other
 mailboxes) that are marked with the "\Flagged" message flag.

 @constant PantomimeSpecialUseMailboxJunk This mailbox is where messages deemed to be junk mail are held.
 Some server implementations might put messages here automatically.  
 Alternatively, this might just be advice to a client-side spam filter.

 @constant PantomimeSpecialUseMailboxSent This mailbox is used to hold copies of messages that have been
 sent.  Some server implementations might put messages here
 automatically.  Alternatively, this might just be advice that a
 client save sent messages here.

 @constant PantomimeSpecialUseMailboxTrash This mailbox is used to hold messages that have been deleted or
 marked for deletion.  
 In some server implementations, this might be a virtual mailbox, containing messages from other mailboxes.
 */
typedef enum
{
    PantomimeSpecialUseMailboxNormal = 0,
    PantomimeSpecialUseMailboxAll,
    PantomimeSpecialUseMailboxArchive,
    PantomimeSpecialUseMailboxDrafts,
    PantomimeSpecialUseMailboxFlagged,
    PantomimeSpecialUseMailboxJunk,
    PantomimeSpecialUseMailboxSent,
    PantomimeSpecialUseMailboxTrash
} PantomimeSpecialUseMailboxType;

/*!
  @typedef PantomimeSearchMask
  @abstract Mask for Folder: -search: mask: options:
  @discussion This enum lists the possible values of the
              search mask. Values can be combined using
	      a bitwise OR.
  @constant PantomimeFrom Search in the "From:" header value.
  @constant PantomimeTo Search in the "To:" header value.
  @constant PantomimeSubject Search in the "Subject:" header value.
  @constant PantomimeContent Search in the message content.
*/
typedef enum
{
  PantomimeFrom = 1,
  PantomimeTo = 2,
  PantomimeSubject = 4,
  PantomimeContent = 8
} PantomimeSearchMask;


/*!
  @typedef PantomimSearchOption
  @abstract Options for Folder: -search: mask: options:
  @discussion This enum lists the possible options when
              performing a search.
  @constant PantomimeCaseInsensitiveSearch Don't consider the case when performing a search operation.
  @constant PantomimeRegularExpression The search criteria represents a regular expression.
*/
typedef enum
{
  PantomimeCaseInsensitiveSearch = 1,
  PantomimeRegularExpression = 2
} PantomimeSearchOption;


/*!
  @typedef PantomimeFolderMode
  @abstract Valid modes for folder.
  @discussion This enum lists the valid mode to be used when
              opening a folder.
  @constant PantomimeUnknownMode Unknown mode.
  @constant PantomimeReadOnlyMode The folder will be open in read-only.
  @constant PantomimeReadWriteMode The folder will be open in read-write.
*/
typedef enum
{
  PantomimeUnknownMode = 1,
  PantomimeReadOnlyMode = 2,
  PantomimeReadWriteMode = 3
} PantomimeFolderMode;

/*!
  @typedef PantomimeForwardMode
  @abstract Valid modes when forwarding a message.
  @discussion This enum lists the valid mode to be
              used when forwarding a message.
  @constant PantomimeAttachmentForwardMode The message will be attached.
  @constant PantomimeInlineForwardMode The text parts of the message will be
                                       extracted and included inline in the
				       forwarded response.
*/
typedef enum
{
  PantomimeAttachmentForwardMode = 1,
  PantomimeInlineForwardMode = 2
} PantomimeForwardMode;


/*!
  @typedef PantomimeContentDisposition
  @abstract Valid modes when setting a Content-Disposition.
  @discussion This enum lists the valid Content-Disposition
              as stated in the RFC2183 standard.
  @constant PantomimeAttachmentDisposition The part is separated from the mail body.
  @constant PantomimeInlineDisposition The part is part of the mail body.
*/
typedef enum
{
  PantomimeAttachmentDisposition = 1,
  PantomimeInlineDisposition = 2
} PantomimeContentDisposition;

/*!
  @typedef PantomimeReplyMode
  @abstract Valid modes when replying to a message.
  @discussion This enum lists the valid modes to be
              used when replying to a message. Those
	      modes are to be used with CWMessage: -reply:
	      PantomimeSimpleReplyMode and PantomimeNormalReplyMode
	      can NOT be combined but can be individually combined
	      with PantomimeReplyAllMode.
  @constant PantomimeSimpleReplyMode Reply to the sender, without a message content
  @constant PantomimeNormalReplyMode Reply to the sender, with a properly build message content.
  @constant PantomimeReplyAllMode Reply to all recipients.
*/
typedef enum
{
  PantomimeSimpleReplyMode = 1,
  PantomimeNormalReplyMode = 2,
  PantomimeReplyAllMode = 4
} PantomimeReplyMode;


/*!
  @typedef PantomimeRecipientType
  @abstract Valid recipient types.
  @discussion This enum lists the valid kind of recipients
              a message can have.
  @constant PantomimeToRecipient Recipient which will appear in the "To:" header value.
  @constant PantomimeCcRecipient Recipient which will appear in the "Cc:" header value.
  @constant PantomimeBccRecipient Recipient which will obtain a black carbon copy of the message.
  @constant PantomimeResentToRecipient Recipient which will appear in the "Resent-To:" header value.
  @constant PantomimeResentCcRecipient Recipient which will appear in the "Resent-Cc:" header value.
  @constant PantomimeResentBccRecipient Recipient which will obtain a black carbon copy of the message
                                        being redirected.
*/
typedef NS_ENUM(NSInteger, PantomimeRecipientType)
{
  PantomimeToRecipient = 1,
  PantomimeCcRecipient = 2,
  PantomimeBccRecipient = 3,
  PantomimeResentToRecipient = 4,
  PantomimeResentCcRecipient = 5,
  PantomimeResentBccRecipient = 6
};

/**
 Foldername to ignore. Used as a workaround to close a mailbox (aka. folder) without calling CLOSE.
 @see RFC4549-4.2.5
 */
extern NSString * _Nonnull const PantomimeFolderNameToIgnore;

/**
 The list of IMAP descriptors the IMAP sync needs.
 */
extern NSString * _Nonnull const PantomimeIMAPDefaultDescriptors;

/**
 IMAP Descriptor for fetching whole body.
 */
extern NSString * _Nonnull const PantomimeIMAPFullBody;

/**
 Dictionary key for the messages (for UID STORE commands).
 */
extern NSString * _Nonnull const PantomimeMessagesKey;

/**
 Dictionary key for the flags (for UID STORE commands).
 */
extern NSString * _Nonnull const PantomimeFlagsKey;

/**
 Dictionary key for special-use attributes.
 */
extern NSString * _Nonnull const PantomimeFolderSpecialUseKey;

/// Dictionary key for an extra error object.
extern NSString * _Nonnull const PantomimeErrorExtra;

#endif // _Pantomime_H_CWConstants
