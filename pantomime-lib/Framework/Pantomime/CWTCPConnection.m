
///
//  CWTCPConnection.m
//  Pantomime
//
//  Created by Dirk Zimmermann on 12/04/16.
//  Copyright © 2016 p≡p Security S.A. All rights reserved.
//

#import <netinet/tcp.h>
#import <netinet/in.h>

#import "CWTCPConnection.h"

#import "Pantomime/CWLogger.h"

NS_ASSUME_NONNULL_BEGIN

@interface CWTCPConnection ()

@property (nonatomic, strong) NSError *streamError;

@end

@implementation CWTCPConnection

- (instancetype)initWithName:(NSString *)theName port:(unsigned int)thePort
         transport:(ConnectionTransport)transport background:(BOOL)theBOOL
{
    if (self = [super init]) {
    }
    return self;
}

- (void)dealloc
{
}

- (void)startTLS
{
}

- (NSString *)bufferToString:(unsigned char *)buf length:(NSInteger)length
{
    static NSInteger maxLength = 200;
    if (length) {
        NSData *data = [NSData dataWithBytes:buf length:MIN(length, maxLength)];
        NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (length >= maxLength) {
            return [string stringByAppendingString:@"..."];
        }
        return string;
    } else {
        return @"";
    }
}

#pragma mark - CWConnection

- (BOOL)isConnected
{
    return NO;
}

- (void)close
{
}

- (NSInteger)read:(unsigned char *)buf length:(NSInteger)len
{
    return 0;
}

- (NSInteger) write:(unsigned char *)buf length:(NSInteger)len
{
    return 0;
}

- (void)connect
{
}

- (BOOL)canWrite
{
    return NO;
}

#pragma mark - Util

/**
 Makes sure there is still a non-nil delegate and returns it, if not,
 warns about it, and shuts the connection down.

 There's no point in going on without a live delegate.

 @return The set CWConnectionDelegate, or nil if not set or if it went out of scope.
 */
- (id<CWConnectionDelegate>)forceDelegate
{
    if (self.delegate == nil) {
        WARN("CWTCPConnection: No delegate. Will close");
        return nil;
    }
    return self.delegate;
}

@end

NS_ASSUME_NONNULL_END
