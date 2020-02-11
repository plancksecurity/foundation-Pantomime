//
//  CertificateLoader.m
//  PantomimeFramework
//
//  Created by Dirk Zimmermann on 07.02.20.
//  Copyright © 2020 pEp Security. All rights reserved.
//

#import "CertificateLoader.h"

@implementation CertificateLoader

+ (NSURLCredential * _Nullable)loadCertificateWithName:(NSString *)certificateName
                                              password:(NSString *)password
{
    NSString *sslCertName = certificateName;
    NSString *path2 = [[NSBundle mainBundle] pathForResource:sslCertName ofType:nil];
    NSData *p12data = [NSData dataWithContentsOfFile:path2];

    if (!p12data) {
        return nil;
    }

    // explore the certificates
    [self exploreP12Data:p12data password:password];

    SecIdentityRef myIdentity;
    SecTrustRef myTrust;

    OSStatus status = [self extractIdentityAndTrustP12Data:p12data
                                                  identity:&myIdentity
                                                     trust:&myTrust
                                                  password: password];

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
    CFRelease(myIdentity);
    CFRelease(myTrust);

    return secureCredential;
}

#pragma mark - Helpers

+ (OSStatus)extractIdentityAndTrustP12Data:(NSData *)inP12data
                                  identity:(SecIdentityRef *)identity
                                     trust:(SecTrustRef *)trust
                                  password:(NSString *)password
{
    OSStatus status = errSecSuccess;

    CFStringRef cfPassword = (__bridge CFStringRef) password;
    const void *keys[] = { kSecImportExportPassphrase };
    const void *values[] = { cfPassword };

    CFDictionaryRef options = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);

    CFArrayRef items = CFArrayCreate(NULL, 0, 0, NULL);

    status = SecPKCS12Import((__bridge CFDataRef) inP12data, options, &items);

    if (status == 0) {
        CFDictionaryRef myIdentityAndTrust = CFArrayGetValueAtIndex(items, 0);
        const void *tempIdentity = NULL;
        tempIdentity = CFRetain(CFDictionaryGetValue(myIdentityAndTrust, kSecImportItemIdentity));
        *identity = (SecIdentityRef) tempIdentity;
        const void *tempTrust = NULL;
        tempTrust = CFRetain(CFDictionaryGetValue(myIdentityAndTrust, kSecImportItemTrust));
        *trust = (SecTrustRef)tempTrust;
    }

    if (options) {
        CFRelease(options);
    }

    return status;
}

+ (BOOL)exploreP12Data:(NSData *)p12Data password:(NSString *)password {
    NSArray *items = [self extractCertificatesP12Data:p12Data password:password];
    if (items == nil) {
        return NO;
    }

    for (NSDictionary *dict in items) {
        // client identity
        SecIdentityRef clientIdentity = (__bridge SecIdentityRef) [dict objectForKey:(id) kSecImportItemIdentity];

        // server identity
        NSArray *chain = [dict objectForKey:(id) kSecImportItemCertChain];
        id firstObject = [chain firstObject];
        for (id chainObj in chain) {
            SecCertificateRef cert = (__bridge SecCertificateRef) chainObj;
            CFStringRef summary = SecCertificateCopySubjectSummary(cert);
            NSString *strSummary = (__bridge_transfer NSString *) summary;
            if ([strSummary containsString:@"Root"] || (chainObj == firstObject)) {
                // have the root
            }
        }
    }

    return YES;
}

+ (NSArray * _Nullable)extractCertificatesP12Data:(NSData *)p12Data password:(NSString *)password {
    NSDictionary *p12Options = @{(id) kSecImportExportPassphrase: password};

    CFArrayRef items = CFArrayCreate(NULL, 0, 0, NULL);
    OSStatus err = SecPKCS12Import((CFDataRef) p12Data, (CFDictionaryRef) p12Options, &items);
    if (err != noErr) {
        return nil;
    }

    return (__bridge NSArray *) items;
}

@end
