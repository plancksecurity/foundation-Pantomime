//
//  TCPConnection.m
//  Pantomime
//
//  Created by Dirk Zimmermann on 12/04/16.
//  Copyright © 2016 pEp Security S.A. All rights reserved.
//

#import "TCPConnection.h"

static NSString *comp = @"TCPConnection";

@interface TCPConnection ()

@property (nonatomic) BOOL connected;
@property (nonatomic, strong) NSString *name;
@property (nonatomic) uint32_t port;
@property (nonatomic) ConnectionTransport transport;
@property (nonatomic, strong) NSInputStream *readStream;
@property (nonatomic, strong) NSOutputStream *writeStream;
@property (nonatomic, strong) NSMutableSet<NSStream *> *openConnections;

@end

@implementation TCPConnection

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
    [self.delegate receivedEvent:nil type:ET_EDESC extra:nil forMode:nil];
}

- (NSString *)bufferToString:(unsigned char *)buf length:(NSInteger)length
{
    if (length) {
        NSData *data = [NSData dataWithBytes:buf length:length];
        NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
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
    NSLog(@"read %d: \"%@\"", count, [self bufferToString:buf length:len]);
    return count;
}

- (NSInteger) write:(unsigned char *)buf length:(NSInteger)len
{
    if (![self.writeStream hasSpaceAvailable]) {
        return -1;
    }
    NSInteger count = [self.writeStream write:buf maxLength:len];
    NSLog(@"wrote %d: \"%@\"", count, [self bufferToString:buf length:len]);
    return count;
}

- (void)connect
{
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
}

- (BOOL)canWrite
{
    return [self.writeStream hasSpaceAvailable];
}

#pragma mark -- NSStreamDelegate

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    switch (eventCode) {
        case NSStreamEventNone:
            NSLog(@"NSStreamEventNone");
            break;
        case NSStreamEventOpenCompleted:
            NSLog(@"NSStreamEventOpenCompleted");
            [self.openConnections addObject:aStream];
            if (self.openConnections.count == 2) {
                NSLog(@"connectionEstablished");
                self.connected = YES;
                [self.delegate connectionEstablished];
            }
            break;
        case NSStreamEventHasBytesAvailable:
            NSLog(@"NSStreamEventHasBytesAvailable");
            [self.delegate receivedEvent:nil type:ET_RDESC extra:nil forMode:nil];
            break;
        case NSStreamEventHasSpaceAvailable:
            NSLog(@"NSStreamEventHasSpaceAvailable");
            [self.delegate receivedEvent:nil type:ET_WDESC extra:nil forMode:nil];
            break;
        case NSStreamEventErrorOccurred:
            NSLog(@"NSStreamEventErrorOccurred");
            [self.delegate receivedEvent:nil type:ET_RDESC extra:nil forMode:nil];
            break;
        case NSStreamEventEndEncountered:
            NSLog(@"NSStreamEventEndEncountered");
            [self.delegate receivedEvent:nil type:ET_RDESC extra:nil forMode:nil];
            break;
    }
}

@end
