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
                                                  password:(NSString *)password
                                                  identity:&myIdentity
                                                     trust:&myTrust];

    if (status != noErr) {
        return nil;
    }

    SecCertificateRef myCertificate;
    SecIdentityCopyCertificate(myIdentity, &myCertificate);
    NSArray *certsArray = @[(__bridge_transfer id) myCertificate];

    CFRelease(myCertificate);

    NSURLCredential *secureCredential = [NSURLCredential
                                         credentialWithIdentity:myIdentity
                                         certificates:certsArray
                                         persistence:NSURLCredentialPersistencePermanent];
    CFRelease(myIdentity);
    CFRelease(myTrust);

    return secureCredential;
}

#pragma mark - Helpers

+ (BOOL)extractIdentityAndTrustP12Data:(NSData *)p12Data
                              password:(NSString *)password
                              identity:(SecIdentityRef *)identity
                                 trust:(SecTrustRef *)trust
{
    NSArray *items = [self extractCertificatesP12Data:p12Data password:password];
    if (items == nil) {
        return NO;
    }

    NSDictionary *myIdentityAndTrust = [items firstObject];
    if (myIdentityAndTrust) {
        id tmpIdentity = [myIdentityAndTrust objectForKey:(id) kSecImportItemIdentity];
        *identity = (__bridge_retained SecIdentityRef) tmpIdentity;
        id tmpTrust = [myIdentityAndTrust objectForKey:(id) kSecImportItemTrust];
        *trust = (__bridge_retained SecTrustRef) tmpTrust;
        return YES;
    }

    return NO;
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
