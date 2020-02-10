//
//  CertificateLoader.m
//  PantomimeFramework
//
//  Created by Dirk Zimmermann on 07.02.20.
//  Copyright © 2020 pEp Security. All rights reserved.
//

#import "CertificateLoader.h"

@implementation CertificateLoader

OSStatus extractIdentityAndTrust(CFDataRef inP12data,
                                 SecIdentityRef *identity,
                                 SecTrustRef *trust,
                                 NSString *password)
{
    OSStatus status = errSecSuccess;

    CFStringRef cfPassword = (__bridge CFStringRef) password;
    const void *keys[] = { kSecImportExportPassphrase };
    const void *values[] = { cfPassword };

    CFDictionaryRef options = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);

    CFArrayRef items = CFArrayCreate(NULL, 0, 0, NULL);

    status = SecPKCS12Import(inP12data, options, &items);

    if (status == 0) {
        CFDictionaryRef myIdentityAndTrust = CFArrayGetValueAtIndex(items, 0);
        const void *tempIdentity = NULL;
        tempIdentity = CFDictionaryGetValue(myIdentityAndTrust, kSecImportItemIdentity);
        *identity = (SecIdentityRef)tempIdentity;
        const void *tempTrust = NULL;
        tempTrust = CFDictionaryGetValue(myIdentityAndTrust, kSecImportItemTrust);
        *trust = (SecTrustRef)tempTrust;
    }

    if (options) {
        CFRelease(options);
    }

    CFRelease(items);

    return status;
}

+ (NSURLCredential * _Nullable)loadCertificateWithName:(NSString *)certificateName
                                              password:(NSString *)password
{
    NSString *sslCertName = certificateName;
    NSString *path2 = [[NSBundle mainBundle] pathForResource:sslCertName ofType:@"p12"];
    NSData *p12data = [NSData dataWithContentsOfFile:path2];

    if (!p12data) {
        return nil;
    }

    CFDataRef inP12data = (__bridge CFDataRef) p12data;

    SecIdentityRef myIdentity;
    SecTrustRef myTrust;

    OSStatus status = extractIdentityAndTrust(inP12data, &myIdentity, &myTrust, password);

    if (status != noErr) {
        return nil;
    }

    SecCertificateRef myCertificate;
    SecIdentityCopyCertificate(myIdentity, &myCertificate);
    const void *certs[] = {myCertificate};
    CFArrayRef certsArray = CFArrayCreate(NULL, certs, 1, NULL);

    CFRelease(myCertificate);

    NSURLCredential *secureCredential = [NSURLCredential
                                         credentialWithIdentity:myIdentity
                                         certificates:(__bridge NSArray *) certsArray
                                         persistence:NSURLCredentialPersistencePermanent];
    CFRelease(certsArray);

    return secureCredential;
}

@end
