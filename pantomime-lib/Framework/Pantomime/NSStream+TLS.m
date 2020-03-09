//
//  NSStream+TLS.m
//  PantomimeFramework
//
//  Created by Dirk Zimmermann on 13.02.20.
//  Copyright © 2020 pEp Security. All rights reserved.
//

#import "NSStream+TLS.h"

#import "NSStream+Options.h"

@implementation NSStream (TLS)

- (void)enableTLS
{
    id tlsOptions = [self getStreamPropertyKey:(id) kCFStreamPropertySSLSettings];
    if (!tlsOptions) {
        [self setProperty:NSStreamSocketSecurityLevelNegotiatedSSL
                   forKey:NSStreamSocketSecurityLevelKey];
    }
}

- (void)disableTLS
{
    [self setProperty:NSStreamSocketSecurityLevelNone
               forKey:NSStreamSocketSecurityLevelKey];
}

- (void)setClientCertificate:(SecIdentityRef _Nonnull)secIdentity
{
    NSDictionary *options = @{(id) kCFStreamSSLCertificates: @[(__bridge id) secIdentity]};
    [self setStreamProperty:options forKey:(NSString *) kCFStreamPropertySSLSettings];
}

@end
