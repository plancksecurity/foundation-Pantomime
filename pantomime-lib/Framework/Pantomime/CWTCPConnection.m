
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

#import "NSStream+SSLContext.h"

NS_ASSUME_NONNULL_BEGIN

@interface CWTCPConnection ()

@property (atomic) BOOL connected;
@property (atomic, strong) NSString *name;
@property (atomic) uint32_t port;
@property (atomic) ConnectionTransport transport;
@property (atomic, strong, nullable) NSInputStream *readStream;
@property (atomic, strong, nullable) NSOutputStream *writeStream;
@property (atomic, strong) NSMutableSet<NSStream *> *openConnections;
@property (nonatomic, strong) NSError *streamError;
@property (nullable, strong) NSThread *backgroundThread;
@property (atomic) BOOL isGettingClosed;

@end

@implementation CWTCPConnection

- (instancetype)initWithName:(NSString *)theName port:(unsigned int)thePort
         transport:(ConnectionTransport)transport background:(BOOL)theBOOL
{
    if (self = [super init]) {
        _openConnections = [[NSMutableSet alloc] init];
        _connected = NO;
        _name = [theName copy];
        _port = thePort;
        _transport = transport;
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

- (void)startTLS
{
    [self.readStream setProperty:NSStreamSocketSecurityLevelNegotiatedSSL
                          forKey:NSStreamSocketSecurityLevelKey];
    [self.writeStream setProperty:NSStreamSocketSecurityLevelNegotiatedSSL
                           forKey:NSStreamSocketSecurityLevelKey];
}

#pragma mark - Stream Handling

- (void)setupStream:(NSStream *)stream
{
    SSLContextRef context = stream.sslContext;
    if (context) {
        CFRelease(context);
    }

    stream.delegate = self;
    switch (self.transport) {
        case ConnectionTransportPlain:
        case ConnectionTransportStartTLS:
            [stream setProperty:NSStreamSocketSecurityLevelNone
                         forKey:NSStreamSocketSecurityLevelKey];
            break;
        case ConnectionTransportTLS:
            [stream setProperty:NSStreamSocketSecurityLevelNegotiatedSSL
                         forKey:NSStreamSocketSecurityLevelKey];
            break;
    }
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

#pragma mark - Run Loop

- (void)connectInBackgroundAndStartRunLoop
{
    NSInputStream *inputStream = nil;
    NSOutputStream *outputStream = nil;

    [NSStream getStreamsToHostWithName:self.name
                                  port:self.port
                           inputStream:&inputStream
                          outputStream:&outputStream];

    if (inputStream == nil || outputStream == nil) {
        [self signalErrorAndClose];
    }

    self.readStream = inputStream;
    self.writeStream = outputStream;

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

#pragma mark - CWConnection

- (BOOL)isConnected
{
    return _connected;
}

- (void)close
{
    @synchronized(self) {
        [self closeAndRemoveStream:self.readStream];
        [self closeAndRemoveStream:self.writeStream];
        self.connected = NO;
        self.isGettingClosed = YES;
        [self cancelBackgroundThread];
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

- (BOOL)canWrite
{
    return [self.writeStream hasSpaceAvailable];
}

#pragma mark - Util

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

- (void)signalErrorAndClose
{
    // We abuse ET_EDESC for error indication.
    [self.forceDelegate receivedEvent:nil type:ET_EDESC extra:nil forMode:nil];
    [self close];
}

@end

@implementation CWTCPConnection (NSStreamDelegate)

#pragma mark - NSStreamDelegate

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
                self.connected = YES;
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

            [self signalErrorAndClose];

            break;
        case NSStreamEventEndEncountered:
            WARN("NSStreamEventEndEncountered");

            [self.forceDelegate receivedEvent:nil type:ET_EDESC extra:nil forMode:nil];
            [self close];

            break;
    }
}

@end

NS_ASSUME_NONNULL_END
