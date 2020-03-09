//
//  NSStream+Options.m
//  PantomimeFramework
//
//  Created by Dirk Zimmermann on 13.02.20.
//  Copyright © 2020 pEp Security. All rights reserved.
//

#import "NSStream+Options.h"

@implementation NSStream (Options)

- (void)setStreamProperty:(id)property forKey:(NSString *)key
{
    if ([self isKindOfClass:[NSInputStream class]]) {
        BOOL result = CFReadStreamSetProperty((__bridge CFReadStreamRef) (NSInputStream *) self,
                                              (__bridge CFStreamPropertyKey) key,
                                              (__bridge CFTypeRef) property);
        NSAssert2(result,
                  @"CFReadStreamSetProperty did not accept %@ with a value of %@",
                  property,
                  key);
    } else if ([self isKindOfClass:[NSOutputStream class]]) {
        BOOL result = CFWriteStreamSetProperty((__bridge CFWriteStreamRef) (NSOutputStream *) self,
                                               (__bridge CFStreamPropertyKey) key,
                                               (__bridge CFTypeRef) property);
        NSAssert2(result,
                  @"CFWriteStreamSetProperty did not accept %@ with a value of %@",
                  property,
                  key);
    } else {
        NSAssert(false,
                 @"Called setStreamProperty for something that is neither NSInputStream nor NSOutputStream");
    }
}

- (id _Nullable)getStreamPropertyKey:(NSString *)key
{
    if ([self isKindOfClass:[NSInputStream class]]) {
        CFTypeRef cfRef = CFReadStreamCopyProperty((__bridge CFReadStreamRef) (NSInputStream *) self,
                                                   (__bridge CFStreamPropertyKey) key);
        if (cfRef) {
            return (__bridge_transfer id) cfRef;
        } else {
            return nil;
        }
    } else if ([self isKindOfClass:[NSOutputStream class]]) {
        CFTypeRef cfRef = CFWriteStreamCopyProperty((__bridge CFWriteStreamRef) (NSOutputStream *) self,
                                                    (__bridge CFStreamPropertyKey) key);
        if (cfRef) {
            return (__bridge_transfer id) cfRef;
        } else {
            return nil;
        }
    } else {
        NSAssert(false,
                 @"Called getStreamPropertyKey for something that is neither NSInputStream nor NSOutputStream");
        return nil;
    }
}

@end
