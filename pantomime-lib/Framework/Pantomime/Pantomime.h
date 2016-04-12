/*
**  Pantomime.h
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

#ifndef _Pantomime_H_Pantomime
#define _Pantomime_H_Pantomime

#import <Foundation/Foundation.h>

#import "Pantomime/CWCacheManager.h>
#import "Pantomime/CWCharset.h>
#import "Pantomime/CWConstants.h>
#import "Pantomime/CWContainer.h>
#import "Pantomime/CWRegEx.h>
#import "Pantomime/CWDNSManager.h>
#import "Pantomime/CWFlags.h>
#import "Pantomime/CWFolder.h>
#import "Pantomime/CWFolderInformation.h>
#import "Pantomime/CWIMAPCacheManager.h>
#import "Pantomime/CWIMAPFolder.h>
#import "Pantomime/CWIMAPMessage.h>
#import "Pantomime/CWIMAPStore.h>
#import "Pantomime/CWInternetAddress.h>
#import "Pantomime/CWISO8859_1.h>
#import "Pantomime/CWISO8859_10.h>
#import "Pantomime/CWISO8859_11.h>
#import "Pantomime/CWISO8859_13.h>
#import "Pantomime/CWISO8859_14.h>
#import "Pantomime/CWISO8859_15.h>
#import "Pantomime/CWISO8859_2.h>
#import "Pantomime/CWISO8859_3.h>
#import "Pantomime/CWISO8859_4.h>
#import "Pantomime/CWISO8859_5.h>
#import "Pantomime/CWISO8859_6.h>
#import "Pantomime/CWISO8859_7.h>
#import "Pantomime/CWISO8859_8.h>
#import "Pantomime/CWISO8859_9.h>
#import "Pantomime/CWKOI8_R.h>
#import "Pantomime/CWKOI8_U.h>
#import "Pantomime/CWLocalCacheManager.h>
#import "Pantomime/CWLocalFolder.h>
#import "Pantomime/CWLocalFolder+maildir.h>
#import "Pantomime/CWLocalFolder+mbox.h>
#import "Pantomime/CWLocalMessage.h>
#import "Pantomime/CWLocalStore.h>
#ifdef MACOSX
#import "Pantomime/CWMacOSXGlue.h>
#endif
#import "Pantomime/CWMD5.h>
#import "Pantomime/CWMessage.h>
#import "Pantomime/CWMIMEMultipart.h>
#import "Pantomime/CWMIMEUtility.h>
#import "Pantomime/NSData+Extensions.h>
#import "Pantomime/NSFileManager+Extensions.h>
#import "Pantomime/NSString+Extensions.h>
#import "Pantomime/CWParser.h>
#import "Pantomime/CWPart.h>
#import "Pantomime/CWPOP3CacheManager.h>
#import "Pantomime/CWPOP3CacheObject.h>
#import "Pantomime/CWPOP3Folder.h>
#import "Pantomime/CWPOP3Message.h>
#import "Pantomime/CWPOP3Store.h>
#import "Pantomime/CWSendmail.h>
#import "Pantomime/CWService.h>
#import "Pantomime/CWSMTP.h>
#import "Pantomime/CWStore.h>
#import "Pantomime/CWTCPConnection.h>
#import "Pantomime/CWTransport.h>
#import "Pantomime/CWUUFile.h>
#import "Pantomime/CWVirtualFolder.h>
#import "Pantomime/CWWINDOWS_1250.h>
#import "Pantomime/CWWINDOWS_1251.h>
#import "Pantomime/CWWINDOWS_1252.h>
#import "Pantomime/CWWINDOWS_1253.h>
#import "Pantomime/CWWINDOWS_1254.h>

#endif // _Pantomime_H_Pantomime
