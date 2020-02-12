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

/// Loads a certificate from the main bundle.
/// @param certificateName The filename of the certificate, including extension
/// @param password The password that was used to encrypt the certificate
/// @return A `NSURLCredential` on success, or nil on error
+ (NSURLCredential * _Nullable)urlCredentialFromP12CertificateWithName:(NSString *)certificateName
                                                              password:(NSString *)password;

@end

NS_ASSUME_NONNULL_END
