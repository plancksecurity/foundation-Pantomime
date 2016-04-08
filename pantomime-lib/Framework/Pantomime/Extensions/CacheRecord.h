//
//  CacheRecord.h
//  Pantomime
//
//  Created by Dirk Zimmermann on 08/04/16.
//  Copyright © 2016 pEp Security S.A. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CacheRecord : NSObject

@property (nonatomic) unsigned int date;
@property (nonatomic) unsigned int flags;
@property (nonatomic) unsigned int position;   // For mbox based cache files
@property (nonatomic) unsigned int size;
@property (nonatomic) unsigned int imap_uid;   // For IMAP
@property (nonatomic) char *filename;          // For maildir base cache files
@property (nonatomic, strong) NSString *pop3_uid;      // For POP3
@property (nonatomic, strong) NSData *from;
@property (nonatomic, strong) NSData *in_reply_to;
@property (nonatomic, strong) NSData *message_id;
@property (nonatomic, strong) NSData *references;
@property (nonatomic, strong) NSData *subject;
@property (nonatomic, strong) NSData *to;
@property (nonatomic, strong) NSData *cc;

@end
