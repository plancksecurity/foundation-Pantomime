
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

static NSURLSession *s_session;

@interface CWTCPConnection ()

@property (nonatomic) NSError *streamError;
@property (nonatomic) NSURLSessionStreamTask *task;

@end

@implementation CWTCPConnection

- (instancetype)initWithName:(NSString *)theName port:(unsigned int)thePort
         transport:(ConnectionTransport)transport background:(BOOL)theBOOL
{
    if (self = [super init]) {
        _task = [[self session] streamTaskWithHostName:theName port:thePort];
    }
    return self;
}

- (void)dealloc
{
}

#pragma mark - CWConnection

- (void)startTLS
{
}

- (BOOL) isConnected
{
    return NO;
}

- (void) close
{
}

- (NSInteger)read:(unsigned char * _Nonnull)buf length:(NSInteger)len
{
    return 0;
}

- (NSInteger)write:(unsigned char * _Nonnull)buf length:(NSInteger)len
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

- (NSURLSession *)session
{
    if (s_session == nil) {
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration
                                                    defaultSessionConfiguration];
        s_session = [NSURLSession sessionWithConfiguration:configuration];
    }
    return s_session;
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

/// Makes sure there is still a non-nil delegate and returns it, if not,
/// warns about it.
///
/// There's no point in going on without a live delegate.
///
/// @return The set CWConnectionDelegate, or nil if not set or if it went out of scope.
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
