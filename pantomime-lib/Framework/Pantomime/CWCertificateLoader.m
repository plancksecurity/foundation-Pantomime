//
//  CWCertificateLoader.m
//  PantomimeFramework
//
//  Created by Dirk Zimmermann on 07.02.20.
//  Copyright © 2020 pEp Security. All rights reserved.
//

#import "CWCertificateLoader.h"

@implementation CWCertificateLoader

+ (NSURLCredential * _Nullable)urlCredentialFromP12CertificateWithName:(NSString *)certificateName
                                                              password:(NSString *)password
{
    NSString *path2 = [[NSBundle mainBundle] pathForResource:certificateName ofType:nil];
    NSData *p12data = [NSData dataWithContentsOfFile:path2];

    if (!p12data) {
        return nil;
    }

    SecIdentityRef myIdentity = nil;
    SecTrustRef myTrust = nil;

    NSArray *certs = [self extractCertificateDataFromP12Data:p12data
                                                    password:(NSString *)password
                                                    identity:&myIdentity
                                                       trust:&myTrust];

    if (!certs) {
        // We took ownership of myIdentity and myTrust, but if
        // extractCertificateDataFromP12Data returns nil
        // then we have the guarantee that they weren't created.
        // Nevertheless, keep the static analyzer happy and make the code explicit.
        if (myIdentity) {
            CFRelease(myIdentity);
        }
        if (myTrust) {
            CFRelease(myTrust);
        }
        return nil;
    }

    NSURLCredential *secureCredential = [NSURLCredential
                                         credentialWithIdentity:myIdentity
                                         certificates:certs
                                         persistence:NSURLCredentialPersistencePermanent];
    if (myIdentity) {
        CFRelease(myIdentity);
    }
    if (myTrust) {
        CFRelease(myTrust);
    }

    return secureCredential;
}

#pragma mark - Helpers

/// Extracts the certificate chain, the identity and the trust from the given p12 data blob
/// @param p12Data The p12 data blob to parse
/// @param password The password that was used to encrypt the data
/// @param identity Pointer to ref, which will be set on success. You take ownership,
///   release when done with it.
/// @param trust Pointer to ref, which will be set on success. You take ownership,
///   release when done with it.
/// @returns On success, returns an array of dictionaries containing the certificate chain,
///  and sets the pointers (identity and trust). On error, nil is returned.
+ (NSArray<NSDictionary *> * _Nullable)extractCertificateDataFromP12Data:(NSData *)p12Data
                                                                password:(NSString *)password
                                                                identity:(SecIdentityRef *)identity
                                                                   trust:(SecTrustRef *)trust
{
    NSArray<NSDictionary *> *items = [self extractCertificatesFromP12Data:p12Data password:password];
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

/// Gathers all certificates from the given data
/// @param dictionaries An array of dictionaries that are assumed to contain
///  an entry under `kSecImportItemCertChain`, which is supposed to be an array
///  of `SecCertificateRef`s.
+ (NSArray<NSDictionary *> *)extractCertificates:(NSArray<NSDictionary *> *)dictionaries
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

/// Parses the given p12 data into a list of items via `SecPKCS12Import`.
/// @param p12Data The encrypted p12 data
/// @param password The password to decrypt the given p12 data
+ (NSArray<NSDictionary *> * _Nullable)extractCertificatesFromP12Data:(NSData *)p12Data
                                                             password:(NSString *)password
{
    NSDictionary *p12Options = @{(id) kSecImportExportPassphrase: password};

    CFArrayRef items;
    OSStatus err = SecPKCS12Import((CFDataRef) p12Data, (CFDictionaryRef) p12Options, &items);
    if (err != noErr) {
        return nil;
    }

    return [NSArray arrayWithArray:(__bridge NSArray *) items];
}

@end
