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
+ (NSURLCredential * _Nullable)loadCertificateWithName:(NSString *)certificateName
                                              password:(NSString *)password;

@end

NS_ASSUME_NONNULL_END
