//
//  CWCertificateLoader.h
//  PantomimeFramework
//
//  Created by Dirk Zimmermann on 07.02.20.
//  Copyright © 2020 pEp Security. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CWCertificateLoader : NSObject

/// Tries to load a certificate from the main bundle and parse it into an `NSURLCredential`
/// suitable for handling a `NSURLAuthenticationMethodClientCertificate`
/// in a `NSURLSessionDelegate`.
/// @param certificateName The filename of the certificate, including extension
/// @param password The password that was used to encrypt the certificate
/// @return A `NSURLCredential` on success, or nil on error
+ (NSURLCredential * _Nullable)urlCredentialFromP12CertificateWithName:(NSString *)certificateName
                                                              password:(NSString *)password;

/// Tries to load a certificate from the main bundle and construct an options dictionary
/// from it that is suitable for being set as `kCFStreamPropertySSLSettings` in a stream.
/// @param certificateName The filename of the certificate, including extension
/// @param password The password that was used to encrypt the certificate
/// @return An options dictionary on success, or nil on error
+ (NSDictionary * _Nullable)tlsOptionsFromP12CertificateWithName:(NSString *)certificateName
                                                        password:(NSString *)password;

/// Tries to load a certificate from the main bundle and construct an SSLContextRef
/// from it that is suitable for being set as `kCFStreamPropertySSLContext` in a stream.
/// @param certificateName The filename of the certificate, including extension
/// @param password The password that was used to encrypt the certificate
/// @return An SSLContextRef on success, or nil on error. You take ownership, so release
///  when done with it.
+ (SSLContextRef _Nullable)sslContextRefFromP12CertificateWithName:(NSString *)certificateName
                                                          password:(NSString *)password;

@end

NS_ASSUME_NONNULL_END
