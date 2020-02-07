
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

#import "CertificateLoader.h"

#import "Pantomime/CWLogger.h"

NS_ASSUME_NONNULL_BEGIN

static NSURLSession *s_session;

@interface CWTCPConnection ()

@property (atomic, strong) NSString *name;
@property (atomic) uint32_t port;
@property (atomic) ConnectionTransport transport;

@property (atomic, strong) NSMutableSet<NSStream *> *openConnections;
@property (atomic) BOOL isGettingClosed;

@property (atomic, strong, nullable) NSInputStream *readStream;
@property (atomic, strong, nullable) NSOutputStream *writeStream;
@property (nonatomic, strong) NSError *streamError;

/// The thread where the read- and write streams are scheduled on.
@property (nullable, strong) NSThread *backgroundThread;

@property (nonatomic) NSURLSessionStreamTask *task;

@end

@implementation CWTCPConnection

- (instancetype)initWithName:(NSString *)theName
                        port:(unsigned int)thePort
                   transport:(ConnectionTransport)transport
                  background:(BOOL)theBOOL
{
    if (self = [super init]) {
        _openConnections = [[NSMutableSet alloc] init];
        _name = [theName copy];
        _port = thePort;
        _transport = transport;
        _task = [[self session] streamTaskWithHostName:theName port:thePort];
        INFO("init %{public}@:%d (%{public}@)", self.name, self.port, self);
        NSAssert(theBOOL, @"TCPConnection only supports background mode");
    }
    return self;
}

- (void)dealloc
{
    INFO("dealloc %{public}@:%d (%{public}@)", self.name, self.port, self);
    [self close];
}

#pragma mark - CWConnection

- (void)startTLS
{
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
    @synchronized(self) {
        [self closeAndRemoveStream:self.readStream];
        [self closeAndRemoveStream:self.writeStream];
        self.isGettingClosed = YES;
        [self cancelBackgroundThread];
        [self.task closeRead];
        [self.task closeWrite];
        [self.task cancel];
    }
}

- (NSInteger)read:(unsigned char *)buf length:(NSInteger)len
{
    if (![self.readStream hasBytesAvailable]) {
        return -1;
    }
    NSInteger count = [self.readStream read:buf maxLength:len];

    /*INFO("< %@:%d %ld: \"%@\"",
         self.name, self.port,
         (long)count,
         [self bufferToString:buf length:count]);*/

    return count;
}

- (NSInteger) write:(unsigned char *)buf length:(NSInteger)len
{
    if (![self.writeStream hasSpaceAvailable]) {
        return -1;
    }
    NSInteger count = [self.writeStream write:buf maxLength:len];

    /*INFO("> %@:%d %ld: \"%@\"",
         self.name, self.port,
         (long)count,
         [self bufferToString:buf length:len]);*/

    return count;
}

- (void)connect
{
    [_task resume];
    [self.task startSecureConnection];
    [self.task captureStreams];
}

- (BOOL)canWrite
{
    return [self.writeStream hasSpaceAvailable];
}

#pragma mark - Run Loop

- (void)connectInBackgroundAndStartRunLoop
{
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
        [self performSelector:@selector(cancelNoop) onThread:self.backgroundThread withObject:nil
                waitUntilDone:NO];
    }
}

- (void)startRunLoopReadStream:(NSInputStream * _Nonnull)readStream
                   writeStream:(NSOutputStream * _Nonnull)writeStream
{
    self.readStream = readStream;
    self.writeStream = writeStream;

    self.backgroundThread = [[NSThread alloc]
                             initWithTarget:self
                             selector:@selector(connectInBackgroundAndStartRunLoop)
                             object:nil];
    self.backgroundThread.name = [NSString
                                  stringWithFormat:@"CWTCPConnection %@:%d 0x%lu",
                                  self.name,
                                  self.port,
                                  (unsigned long) self.backgroundThread];
    [self.backgroundThread start];
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
        [self.openConnections removeObject:stream];
        [stream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        if (stream == self.readStream) {
            self.readStream = nil;
        } else if (stream == self.writeStream) {
            self.writeStream = nil;
        }
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
 /// warns about it, and shuts the connection down.
 ///
 /// There's no point in going on without a live delegate.
 ///
 /// @return The set CWConnectionDelegate, or nil if not set or if it went out of scope.
- (id<CWConnectionDelegate>)forceDelegate
{
    if (self.delegate == nil) {
        WARN("CWTCPConnection: No delegate. Will close");
        if (!self.isGettingClosed) {
            [self close];
        }
    }
    return self.delegate;
}

@end

#pragma mark - NSStreamDelegate

@implementation CWTCPConnection (NSStreamDelegate)

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    switch (eventCode) {
        case NSStreamEventNone:
            //INFO("NSStreamEventNone");
            break;
        case NSStreamEventOpenCompleted:
            //INFO("NSStreamEventOpenCompleted");
            [self.openConnections addObject:aStream];
            if (self.openConnections.count == 2) {
                INFO("connectionEstablished");
                [self.forceDelegate connectionEstablished];
            }
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

#pragma mark - NSURLSessionDelegate

@implementation CWTCPConnection (NSURLSessionDelegate)

- (void)URLSession:(NSURLSession *)session
        streamTask:(NSURLSessionStreamTask *)streamTask
didBecomeInputStream:(NSInputStream *)inputStream
      outputStream:(NSOutputStream *)outputStream
{
    [self startRunLoopReadStream:inputStream writeStream:outputStream];
}

- (void)URLSession:(NSURLSession *)session
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition,
                             NSURLCredential *credential))completionHandler
{
    if ([challenge.protectionSpace.authenticationMethod
         isEqualToString:NSURLAuthenticationMethodClientCertificate]) {
        NSURLCredential *secureCredential = [CertificateLoader
                                             loadCertificateWithName:@"certificate"
                                             password: @"password"];
        if (secureCredential) {
            [[challenge sender]
             useCredential:secureCredential
             forAuthenticationChallenge:challenge];
            completionHandler(NSURLSessionAuthChallengeUseCredential, secureCredential);
            return;
        }
    }

    // Fallback
    NSURLCredential *fakeCredentials = [[NSURLCredential alloc]
                                        initWithUser:@""
                                        password:@""
                                        persistence:NSURLCredentialPersistenceNone];
    completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, fakeCredentials);
}

@end

NS_ASSUME_NONNULL_END
