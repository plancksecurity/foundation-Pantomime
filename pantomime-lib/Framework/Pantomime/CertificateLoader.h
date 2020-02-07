//
//  CertificateLoader.h
//  PantomimeFramework
//
//  Created by Dirk Zimmermann on 07.02.20.
//  Copyright © 2020 pEp Security. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CertificateLoader : NSObject

+ (NSURLCredential * _Nullable)loadCertificateWithName:(NSString *)certificateName
                                              password:(NSString *)password;

@end

NS_ASSUME_NONNULL_END
