
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

static NSString *comp = @"CWTCPConnection";

static NSInteger s_numberOfConnectionThreads = 0;

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
@property (atomic) BOOL gettingClosed;

@end

@implementation CWTCPConnection

+ (NSInteger)numberOfRunningConnections
{
    return s_numberOfConnectionThreads;
}

- (instancetype)initWithName:(NSString *)theName port:(unsigned int)thePort
         transport:(ConnectionTransport)transport background:(BOOL)theBOOL
{
    if (self = [super init]) {
        _openConnections = [[NSMutableSet alloc] init];
        _connected = NO;
        _name = [theName copy];
        _port = thePort;
        _transport = transport;
        NSAssert(theBOOL, @"TCPConnection only supports background mode");
    }
    return self;
}

- (void)dealloc
{
    INFO("dealloc %{public}@", self);
    [self close];
}

- (void)startTLS
{
    [self.readStream setProperty:NSStreamSocketSecurityLevelNegotiatedSSL
                          forKey:NSStreamSocketSecurityLevelKey];
    [self.writeStream setProperty:NSStreamSocketSecurityLevelNegotiatedSSL
                           forKey:NSStreamSocketSecurityLevelKey];
}

- (void)setupStream:(NSStream *)stream
{
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
        if (stream == self.readStream) {
            self.readStream = nil;
        } else if (stream == self.writeStream) {
            self.writeStream = nil;
        }
    }
}

/**
 Sets a socket option (the SOL_SOCKET layer) for a given stream.
 */
- (NSInteger)setSocketOption:(int)optionName optionNameString:(NSString *)optionNameString
                 optionValue:(NSInteger)optionValue onStream:(NSStream *)stream
{
    CFReadStreamRef cfStream = (__bridge CFReadStreamRef) (NSInputStream *) stream;
    CFDataRef nativeSocket = CFReadStreamCopyProperty(cfStream,
                                                      kCFStreamPropertySocketNativeHandle);
    CFSocketNativeHandle *cfSock = (CFSocketNativeHandle *) CFDataGetBytePtr(nativeSocket);

    NSUInteger originalValue = 500;
    NSUInteger newValue = 501;
    socklen_t originalValueSize = sizeof(originalValue);
    socklen_t newValueSize = sizeof(newValue);
    getsockopt(*cfSock, SOL_SOCKET, optionName, &originalValue, &originalValueSize);
    setsockopt(*cfSock, SOL_SOCKET, optionName, &optionValue, sizeof(optionValue));
    getsockopt(*cfSock, SOL_SOCKET, optionName, &newValue, &newValueSize);
    INFO("%@: %lu (%d bytes) -> %lu (%d bytes)",
         optionNameString,
         (unsigned long) originalValue, originalValueSize,
         (unsigned long) newValue, newValueSize);

    CFRelease(nativeSocket);
    return newValue;
}

/**
 Set SO_RCVLOWAT for the read stream socket, which is not needed because the default (1)
 is already the desired value.
 */
- (void)setupSocketForStream:(NSStream *)stream
{
    if (stream == self.readStream) {
        [self setSocketOption:SO_RCVLOWAT optionNameString:@"SO_RCVLOWAT" optionValue:1
                     onStream: stream];
    }
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

- (void)connectInBackgroundAndStartRunLoop
{
    s_numberOfConnectionThreads++;

    CFReadStreamRef readStream = nil;
    CFWriteStreamRef writeStream = nil;
    CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, (__bridge CFStringRef) self.name,
                                       self.port, &readStream, &writeStream);

    NSAssert(readStream != nil, @"Could not create input stream");
    NSAssert(writeStream != nil, @"Could not create output stream");

    if (readStream != nil && writeStream != nil) {
        self.readStream = CFBridgingRelease(readStream);
        self.writeStream = CFBridgingRelease(writeStream);
        [self setupStream:self.readStream];
        [self setupStream:self.writeStream];
    }

    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    while (1) {
        if ( [NSThread currentThread].isCancelled ) {
            break;
        }
        @autoreleasepool {
            [runLoop runMode:NSDefaultRunLoopMode beforeDate: [NSDate distantFuture]];
        }
    }
    s_numberOfConnectionThreads--;
    self.backgroundThread = nil;
}

- (void)cancelNoop {}

- (void)cancelBackgroundThead
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
        self.gettingClosed = YES;
        [self cancelBackgroundThead];
    }
}

- (NSInteger)read:(unsigned char *)buf length:(NSInteger)len
{
    if (![self.readStream hasBytesAvailable]) {
        return -1;
    }
    NSInteger count = [self.readStream read:buf maxLength:len];

    INFO("< %@:%d %ld: \"%@\"",
         self.name, self.port,
         (long)count,
         [self bufferToString:buf length:count]);

    return count;
}

- (NSInteger) write:(unsigned char *)buf length:(NSInteger)len
{
    if (![self.writeStream hasSpaceAvailable]) {
        return -1;
    }
    NSInteger count = [self.writeStream write:buf maxLength:len];

    INFO("> %@:%d %ld: \"%@\"",
         self.name, self.port,
         (long)count,
         [self bufferToString:buf length:len]);

    return count;
}

- (void)connect
{
    self.backgroundThread = [[NSThread alloc]
                             initWithTarget:self
                             selector:@selector(connectInBackgroundAndStartRunLoop)
                             object:nil];
    self.backgroundThread.name = [NSString stringWithFormat:@"CWTCPConnection 0x%lu",
                                  (unsigned long) self.backgroundThread];
    [self.backgroundThread start];
}

- (BOOL)canWrite
{
    return [self.writeStream hasSpaceAvailable];
}

#pragma mark - NSStreamDelegate

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    switch (eventCode) {
        case NSStreamEventNone:
            INFO("NSStreamEventNone");
            break;
        case NSStreamEventOpenCompleted:
            INFO("NSStreamEventOpenCompleted");
            [self.openConnections addObject:aStream];
            if (self.openConnections.count == 2) {
                INFO("connectionEstablished");
                self.connected = YES;
                [self.delegate connectionEstablished];
            }
            break;
        case NSStreamEventHasBytesAvailable:
            INFO("NSStreamEventHasBytesAvailable");
            [self.delegate receivedEvent:nil type:ET_RDESC extra:nil forMode:nil];
            break;
        case NSStreamEventHasSpaceAvailable:
            INFO("NSStreamEventHasSpaceAvailable");
            [self.delegate receivedEvent:nil type:ET_WDESC extra:nil forMode:nil];
            break;
        case NSStreamEventErrorOccurred:
            INFO("NSStreamEventErrorOccurred: read: %@, write: %@",
                 [self.readStream.streamError localizedDescription],
                 [self.writeStream.streamError localizedDescription]);
            if (self.readStream.streamError) {
                self.streamError = self.readStream.streamError;
            } else if (self.writeStream.streamError) {
                self.streamError = self.writeStream.streamError;
            }

            // We abuse ET_EDESC for error indicication.
            [self.delegate receivedEvent:nil type:ET_EDESC extra:nil forMode:nil];
            [self cancelBackgroundThead];

            break;
        case NSStreamEventEndEncountered:
            INFO("NSStreamEventEndEncountered");

            [self.delegate receivedEvent:nil type:ET_EDESC extra:nil forMode:nil];
            [self cancelBackgroundThead];

            break;
    }
}

@end

NS_ASSUME_NONNULL_END
