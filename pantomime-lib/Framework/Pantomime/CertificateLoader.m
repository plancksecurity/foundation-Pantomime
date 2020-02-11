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

    SecIdentityRef myIdentity;
    SecTrustRef myTrust;

    NSArray *certs = [self extractIdentityAndTrustP12Data:p12data
                                                 password:(NSString *)password
                                                 identity:&myIdentity
                                                    trust:&myTrust];

    if (!certs) {
        return nil;
    }

    NSURLCredential *secureCredential = [NSURLCredential
                                         credentialWithIdentity:myIdentity
                                         certificates:certs
                                         persistence:NSURLCredentialPersistencePermanent];
    CFRelease(myIdentity);
    CFRelease(myTrust);

    return secureCredential;
}

#pragma mark - Helpers

+ (NSArray<NSDictionary *> * _Nullable)extractIdentityAndTrustP12Data:(NSData *)p12Data
                                                             password:(NSString *)password
                                                             identity:(SecIdentityRef *)identity
                                                                trust:(SecTrustRef *)trust
{
    NSArray *items = [self extractCertificatesP12Data:p12Data password:password];
    if (items == nil) {
        return nil;
    }

    NSDictionary *myIdentityAndTrust = [items firstObject];
    if (myIdentityAndTrust) {
        id tmpIdentity = [myIdentityAndTrust objectForKey:(id) kSecImportItemIdentity];
        *identity = (__bridge_retained SecIdentityRef) tmpIdentity;
        id tmpTrust = [myIdentityAndTrust objectForKey:(id) kSecImportItemTrust];
        *trust = (__bridge_retained SecTrustRef) tmpTrust;
        NSArray *certs = [self extractCertificates:items];
        return certs;
    }

    return nil;
}

+ (NSArray *)extractCertificates:(NSArray<NSDictionary *> *)dictionaries
{
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:1];

    for (NSDictionary *dict in dictionaries) {
        NSArray *certificateChain = [dict objectForKey:(id) kSecImportItemCertChain];
        for (id certObj in certificateChain) {
            SecCertificateRef cert = (__bridge SecCertificateRef) certObj;
            CFStringRef summary = SecCertificateCopySubjectSummary(cert);
            NSString *strSummary = (__bridge_transfer NSString *) summary;
            NSLog(@"**** certificate %@: %@", strSummary, certObj);
            [result addObject:certObj];
        }
    }

    return [NSArray arrayWithArray:result];
}

+ (NSArray * _Nullable)extractCertificatesP12Data:(NSData *)p12Data password:(NSString *)password
{
    NSDictionary *p12Options = @{(id) kSecImportExportPassphrase: password};

    CFArrayRef items = CFArrayCreate(NULL, 0, 0, NULL);
    OSStatus err = SecPKCS12Import((CFDataRef) p12Data, (CFDictionaryRef) p12Options, &items);
    if (err != noErr) {
        return nil;
    }

    return (__bridge NSArray *) items;
}

@end
