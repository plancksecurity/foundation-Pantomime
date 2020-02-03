
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

/// The size (in bytes) of the read buffer.
static NSUInteger s_defaultReadBufferSize = 1024;

/// The default waiting time (in seconds) for reading or writing data.
static NSTimeInterval s_defaultTimeout = 30;

@interface CWTCPConnection ()

@property (atomic, strong, nullable) NSInputStream *readStream;
@property (atomic, strong, nullable) NSOutputStream *writeStream;
@property (nonatomic) NSError *streamError;

@property (nonatomic) NSURLSessionStreamTask *task;
@property (nonatomic) ConnectionTransport transport;

@end

@implementation CWTCPConnection

- (instancetype)initWithName:(NSString *)theName port:(unsigned int)thePort
         transport:(ConnectionTransport)transport background:(BOOL)theBOOL
{
    if (self = [super init]) {
        _readTimeout = s_defaultTimeout;
        _writeTimeout = s_defaultTimeout;
        _readBufferSize = s_defaultReadBufferSize;
        _transport = transport;
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
    [self.task startSecureConnection];
}

- (BOOL)isConnected
{
    switch (self.task.state) {
        case NSURLSessionTaskStateRunning:
            return YES;
        case NSURLSessionTaskStateSuspended:
        case NSURLSessionTaskStateCanceling:
        case NSURLSessionTaskStateCompleted:
            return NO;
    }
}

- (void)close
{
    [self.task closeRead];
    [self.task closeWrite];
    [self.task cancel];
}

- (NSInteger)read:(unsigned char * _Nonnull)buf length:(NSInteger)len
{
    [self.task readDataOfMinLength:1
                         maxLength:len
                           timeout:self.readTimeout
                 completionHandler:^(NSData *data, BOOL atEOF, NSError *error) {
        if (error) {
            // We abuse ET_EDESC for error indication.
            [self.forceDelegate receivedEvent:nil type:ET_EDESC extra:nil forMode:nil];
        } else {

        }

    }];
    return 0;
}

- (NSInteger)write:(unsigned char * _Nonnull)buf length:(NSInteger)len
{
    return 0;
}

- (void)connect
{
    [_task resume];
    if (self.transport == ConnectionTransportTLS) {
        [self.task startSecureConnection];
    }
}

- (BOOL)canWrite
{
    return NO;
}

#pragma mark - Stream Handling

- (void)setupStream:(NSStream *)stream
{
    stream.delegate = self;
    [stream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [stream open];
}

#pragma mark - Util

- (NSURLSession *)session
{
    if (s_session == nil) {
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration
                                                    defaultSessionConfiguration];
        s_session = [NSURLSession sessionWithConfiguration:configuration
                                                  delegate:self
                                             delegateQueue:nil];
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

@implementation CWTCPConnection (NSStreamDelegate)

@end

@implementation CWTCPConnection (NSURLSessionDelegate)

@end

NS_ASSUME_NONNULL_END
