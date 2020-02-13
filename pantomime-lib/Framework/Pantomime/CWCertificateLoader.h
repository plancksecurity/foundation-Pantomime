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

/// Tries to load a certificate from the main bundle and construct a certificate chain
/// from it so that the first element is the identity, and the following elements
/// are certificates in that chain.
/// @param certificateName The filename of the certificate, including extension
/// @param password The password that was used to encrypt the certificate
/// @return An array representing the certificate chain on success, or nil on error.
+ (NSArray * _Nullable)certificateChainFromP12CertificateWithName:(NSString *)certificateName
                                                         password:(NSString *)password;

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

/// Tries to load a certificate chain from the given filename, with the given password,
/// and set it into the given stream's SSL context, if available.
/// @param certificateName The filename of the certificate, including extension
/// @param password The password that was used to encrypt the certificate
/// @param stream The stream to override the SSL context with the loaded certificate chain.
/// @return YES on error, NO otherwise.
+ (BOOL)setSSLContextCertificateChainFromP12CertificateWithName:(NSString *)certificateName
                                                       password:(NSString *)password
                                                         stream:(NSStream *)stream;

/// Tries to load a certificate chain from the given filename, with the given password,
/// and set it into the given stream's options, via `kCFStreamPropertySSLSettings`.
/// @param certificateName The filename of the certificate, including extension
/// @param password The password that was used to encrypt the certificate
/// @param stream The stream to set the key chain for.
/// @return YES on error, NO otherwise.
+ (BOOL)setStreamPropertySSLSettingsFromP12CertificateWithName:(NSString *)certificateName
                                                      password:(NSString *)password
                                                        stream:(NSStream *)stream;

@end

NS_ASSUME_NONNULL_END
