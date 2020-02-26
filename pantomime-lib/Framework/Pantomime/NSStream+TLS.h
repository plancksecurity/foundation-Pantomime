//
//  NSStream+TLS.h
//  PantomimeFramework
//
//  Created by Dirk Zimmermann on 13.02.20.
//  Copyright © 2020 pEp Security. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSStream (TLS)

/// Gets or sets the SSL context.
/// @note Getting it transfers ownership to the caller, make sure you release it.
@property (readwrite, nullable) SSLContextRef sslContext;

/// If TLS is not already enabled on this stream, enable it.
- (void)enableTLS;

/// Disable TLS.
- (void)disableTLS;

/// Set the given client certificate to the stream's TLS options
/// @param secIdentity The client certificate to set
- (void)setClientCertificate:(SecIdentityRef _Nonnull)secIdentity;

@end

NS_ASSUME_NONNULL_END
