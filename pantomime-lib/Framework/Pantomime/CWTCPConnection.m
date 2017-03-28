//
//  CWTCPConnection.m
//  Pantomime
//
//  Created by Dirk Zimmermann on 12/04/16.
//  Copyright © 2016 p≡p Security S.A. All rights reserved.
//

#import "CWTCPConnection.h"

#import "Pantomime/CWLogger.h"

static NSString *comp = @"CWTCPConnection";

static NSInteger s_numberOfConnectionThreads = 0;

@interface CWTCPConnection ()

@property (nonatomic) BOOL connected;
@property (nonatomic, strong) NSString *name;
@property (nonatomic) uint32_t port;
@property (nonatomic) ConnectionTransport transport;
@property (nonatomic, strong) NSInputStream *readStream;
@property (nonatomic, strong) NSOutputStream *writeStream;
@property (nonatomic, strong) NSMutableSet<NSStream *> *openConnections;
@property (nonatomic, strong) NSError *streamError;
@property (nullable, strong) NSThread *backgroundThread;
@property (nonatomic) BOOL gettingClosed;

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
    [self.logger infoComponent:comp
                       message:[NSString
                                stringWithFormat:@"%x dealloc", (unsigned int) self]];
    [self close];
}

- (id<CWLogging>)logger
{
    return [CWLogger logger];
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

#pragma mark -- CWConnection

- (BOOL)isConnected
{
    return _connected;
}

- (void)close
{
    [self closeAndRemoveStream:self.readStream];
    [self closeAndRemoveStream:self.writeStream];
    self.connected = NO;
    self.gettingClosed = YES;
    [self cancelBackgroundThead];
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

- (NSInteger)read:(unsigned char *)buf length:(NSInteger)len
{
    if (![self.readStream hasBytesAvailable]) {
        return -1;
    }
    NSInteger count = [self.readStream read:buf maxLength:len];
    /*
    [self.logger infoComponent:comp
                       message:[NSString
                                stringWithFormat:@"read %ld: \"%@\"", (long)count,
                                [self bufferToString:buf length:count]]];*/
    return count;
}

- (NSInteger) write:(unsigned char *)buf length:(NSInteger)len
{
    if (![self.writeStream hasSpaceAvailable]) {
        return -1;
    }
    NSInteger count = [self.writeStream write:buf maxLength:len];
    /*
    [self.logger infoComponent:comp
                       message:[NSString
                                stringWithFormat:@"wrote %ld: \"%@\"", (long)count,
                                [self bufferToString:buf length:len]]];*/
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

- (BOOL)canWrite
{
    return [self.writeStream hasSpaceAvailable];
}

- (void)cancelBackgroundThead
{
    if (self.backgroundThread) {
        [self.backgroundThread cancel];
        [self performSelector:@selector(cancelNoop) onThread:self.backgroundThread withObject:nil
                waitUntilDone:NO];
    }
}

- (void)cancelNoop {}

#pragma mark -- NSStreamDelegate

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    switch (eventCode) {
        case NSStreamEventNone:
            [self.logger infoComponent:comp message:@"NSStreamEventNone"];
            break;
        case NSStreamEventOpenCompleted:
            [self.logger infoComponent:comp message:@"NSStreamEventOpenCompleted"];
            [self.openConnections addObject:aStream];
            if (self.openConnections.count == 2) {
                [self.logger infoComponent:comp message:@"connectionEstablished"];
                self.connected = YES;
                [self.delegate connectionEstablished];
            }
            break;
        case NSStreamEventHasBytesAvailable:
            //[self.logger infoComponent:comp message:@"NSStreamEventHasBytesAvailable"];
            [self.delegate receivedEvent:nil type:ET_RDESC extra:nil forMode:nil];
            break;
        case NSStreamEventHasSpaceAvailable:
            //[self.logger infoComponent:comp message:@"NSStreamEventHasSpaceAvailable"];
            [self.delegate receivedEvent:nil type:ET_WDESC extra:nil forMode:nil];
            break;
        case NSStreamEventErrorOccurred:
            [self.logger
             infoComponent:comp
             message:[NSString
                      stringWithFormat:@"NSStreamEventErrorOccurred: read: %@, write: %@",
                      [self.readStream.streamError localizedDescription],
                      [self.writeStream.streamError localizedDescription]]];
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
            [self.logger infoComponent:comp message:@"NSStreamEventEndEncountered"];
            [self close];
            break;
    }
}

@end
