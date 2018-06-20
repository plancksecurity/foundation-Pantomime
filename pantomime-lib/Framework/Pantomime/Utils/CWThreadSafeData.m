//
//  CWThreadSafeData.m
//  Pantomime
//
//  Created by Andreas Buff on 04.09.17.
//  Copyright © 2017 pEp Security S.A. All rights reserved.
//

#import "CWThreadSafeData.h"

NS_ASSUME_NONNULL_BEGIN

@interface CWThreadSafeData ()
@property (nonatomic) dispatch_queue_t queue;
@property (atomic) __block NSMutableData *data;
@end

@implementation CWThreadSafeData

- (instancetype _Nullable)init
{
    self = [super init];
    if (self) {
        self.queue = dispatch_queue_create("CWThreadSaveData", DISPATCH_QUEUE_SERIAL);
        self.data = [NSMutableData new];
    }
    return self;
}

- (instancetype _Nullable)initWithData:(NSData *)data
{
    self = [self init];
    if (self) {
        self.data = [NSMutableData dataWithData:data];
    }
    return  self;
}

- (instancetype _Nullable)initWithBytes:(char*)bytes length:(NSUInteger)length
{
    self = [self init];
    if (self) {
        self.data = [NSMutableData dataWithBytes:bytes length:length];
    }
    return  self;
}

- (NSUInteger)length
{
    __block NSUInteger result = 0;
    dispatch_sync(self.queue, ^{
        result = self.data.length;
    });
    return result;
}

- (void)reset
{
    dispatch_sync(self.queue, ^{
        self.data = [NSMutableData new];
    });
}

- (void)truncateLeadingBytes:(NSUInteger)numBytes
{
    dispatch_sync(self.queue, ^{
        NSUInteger length = self.data.length - numBytes;
        NSData *newData =  [self.data subdataWithRange:NSMakeRange(numBytes, length)];
        self.data = [NSMutableData dataWithData: newData];
    });
}

- (const char*)copyOfBytes
{
    __block const char* copyOfBytes = nil;
    dispatch_sync(self.queue, ^{
        NSData *copy = self.data.copy;
        copyOfBytes = copy.bytes;
    });

    return copyOfBytes;
}

- (NSData *)subdataToIndex:(NSUInteger)index
{
    __block NSData *subData = nil;
    dispatch_sync(self.queue, ^{
            subData = [self.data subdataWithRange: NSMakeRange(0, index)];
    });

    return subData;
}

- (void)appendData:(NSData *)data
{
    dispatch_sync(self.queue, ^{
        [self.data appendData:data];
    });
}

- (NSData * _Nullable)dropFirstLine
{
    __block NSData *firstLine = nil;
    dispatch_sync(self.queue, ^{
        char *bytes, *end;
        NSUInteger i, count;

        bytes = (char *)[self.data mutableBytes];
        end = bytes + 1;
        count = self.data.length;

        for (i = 1; i < count; i++) {
            if (*end == '\n' && *(end - 1) == '\r') {
                NSData *aData = [NSData dataWithBytes: bytes  length: (i - 1)];
                memmove(bytes,end + 1,count - i - 1);
                [self.data setLength: count - i - 1];
                firstLine = aData;
                return;
            }
            end++;
        }
    });
    
    return firstLine;
}

@end

NS_ASSUME_NONNULL_END
