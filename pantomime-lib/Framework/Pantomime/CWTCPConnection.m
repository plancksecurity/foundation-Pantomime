
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

@property (nonatomic) ConnectionTransport transport;

@property (atomic, strong, nullable) NSInputStream *readStream;
@property (atomic, strong, nullable) NSOutputStream *writeStream;
@property (nonatomic) NSError *streamError;

@property (nullable, strong) NSThread *backgroundThread;

@property (nonatomic) NSURLSessionStreamTask *task;

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
    [self closeAndRemoveStream:self.readStream];
    [self closeAndRemoveStream:self.writeStream];
    [self cancelBackgroundThread];

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

- (void)closeAndRemoveStream:(NSStream *)stream
{
    if (stream) {
        [stream close];
        [stream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        if (stream == self.readStream) {
            self.readStream = nil;
        } else if (stream == self.writeStream) {
            self.writeStream = nil;
        }
    }
}

#pragma mark - Run Loop

- (void)connectInBackgroundAndStartRunLoopReadStream:(NSInputStream * _Nonnull)readStream
                                         writeStream:(NSOutputStream * _Nonnull)writeStream
{
    self.readStream = readStream;
    self.writeStream = writeStream;
    [self setupStream:self.readStream];
    [self setupStream:self.writeStream];

    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    while (1) {
        if ( [NSThread currentThread].isCancelled ) {
            break;
        }
        @autoreleasepool {
            [runLoop runMode:NSDefaultRunLoopMode beforeDate: [NSDate distantFuture]];
        }
    }
    self.backgroundThread = nil;
}

- (void)cancelNoop {}

- (void)cancelBackgroundThread
{
    if (self.backgroundThread) {
        [self.backgroundThread cancel];
        [self performSelector:@selector(cancelNoop)
                     onThread:self.backgroundThread withObject:nil
                waitUntilDone:NO];
    }
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

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    switch (eventCode) {
        case NSStreamEventNone:
            //INFO("NSStreamEventNone");
            break;
        case NSStreamEventOpenCompleted:
            //INFO("NSStreamEventOpenCompleted");
            [self.forceDelegate connectionEstablished]; // TODO
            break;
        case NSStreamEventHasBytesAvailable:
            //INFO("NSStreamEventHasBytesAvailable");
            [self.forceDelegate receivedEvent:nil type:ET_RDESC extra:nil forMode:nil];
            break;
        case NSStreamEventHasSpaceAvailable:
            //INFO("NSStreamEventHasSpaceAvailable");
            [self.forceDelegate receivedEvent:nil type:ET_WDESC extra:nil forMode:nil];
            break;
        case NSStreamEventErrorOccurred:
            ERROR("NSStreamEventErrorOccurred: read: %@, write: %@",
                  [self.readStream.streamError localizedDescription],
                  [self.writeStream.streamError localizedDescription]);
            if (self.readStream.streamError) {
                self.streamError = self.readStream.streamError;
            } else if (self.writeStream.streamError) {
                self.streamError = self.writeStream.streamError;
            }

            // We abuse ET_EDESC for error indication.
            [self.forceDelegate receivedEvent:nil type:ET_EDESC extra:nil forMode:nil];
            [self close];

            break;
        case NSStreamEventEndEncountered:
            WARN("NSStreamEventEndEncountered");

            [self.forceDelegate receivedEvent:nil type:ET_EDESC extra:nil forMode:nil];
            [self close];

            break;
    }
}

@end

@implementation CWTCPConnection (NSURLSessionDelegate)

@end

NS_ASSUME_NONNULL_END
