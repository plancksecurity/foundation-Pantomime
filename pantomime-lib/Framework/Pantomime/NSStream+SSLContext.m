//
//  NSStream+SSLContext.m
//  PantomimeFramework
//
//  Created by Dirk Zimmermann on 13.02.20.
//  Copyright © 2020 pEp Security. All rights reserved.
//

#import "NSStream+SSLContext.h"

@implementation NSStream (SSLContext)

- (SSLContextRef)sslContext
{
    if ([self isKindOfClass:[NSInputStream class]]) {
        CFTypeRef ref = CFReadStreamCopyProperty((__bridge CFReadStreamRef) (NSInputStream *) self,
                                                 kCFStreamPropertySSLContext);
        return (SSLContextRef) ref;
    }

    if ([self isKindOfClass:[NSOutputStream class]]) {
        CFTypeRef ref = CFWriteStreamCopyProperty((__bridge CFWriteStreamRef) (NSOutputStream *) self,
                                                  kCFStreamPropertySSLContext);
        return (SSLContextRef) ref;
    }

    return nil;
}

- (void)setSslContext:(SSLContextRef)context
{
    [self setProperty:(__bridge id) context forKey:(NSString *) kCFStreamPropertySSLContext];
}

- (void)setProperty:(id)property forKey:(NSString *)key
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
    }
    NSAssert(false,
             @"Called setProperty for something that is neither NSInputStream nor NSOutputStream");
}

@end
