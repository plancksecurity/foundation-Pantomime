//
//  CWCertificateLoader.m
//  PantomimeFramework
//
//  Created by Dirk Zimmermann on 07.02.20.
//  Copyright © 2020 pEp Security. All rights reserved.
//

#import "CWCertificateLoader.h"

#import "NSStream+SSLContext.h"

@implementation CWCertificateLoader

+ (NSArray * _Nullable)certificateChainFromP12CertificateWithName:(NSString *)certificateName
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

    // Not used for output, can release right now
    if (myTrust) {
        CFRelease(myTrust);
    }

    if (!myIdentity) {
        return nil;
    }

    // Safely wrap the identity in order to put it into the array
    id firstItem = (__bridge_transfer id) myIdentity;

    // The certificate chain consist of our identity, plus certificates
    NSMutableArray *certificateChain = [NSMutableArray arrayWithObject:firstItem];
    [certificateChain addObjectsFromArray:certs];

    return [NSArray arrayWithArray:certificateChain];
}

+ (NSURLCredential * _Nullable)urlCredentialFromP12CertificateWithName:(NSString *)certificateName
                                                              password:(NSString *)password
{
    NSArray *certificateChain = [self certificateChainFromP12CertificateWithName:certificateName
                                                                        password:password];

    if (!certificateChain) {
        return nil;
    }

    id myIdentity = [certificateChain firstObject];

    NSPredicate *sortOut = [NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject,
                                                                 NSDictionary<NSString *,id> * _Nullable bindings) {
        if (evaluatedObject == myIdentity) {
            return NO;
        }
        return YES;
    }];
    NSArray *theRest = [certificateChain filteredArrayUsingPredicate:sortOut];

    NSURLCredential *secureCredential = [NSURLCredential
                                         credentialWithIdentity:(__bridge SecIdentityRef) myIdentity
                                         certificates:theRest
                                         persistence:NSURLCredentialPersistencePermanent];
    return secureCredential;
}

+ (NSDictionary * _Nullable)tlsOptionsFromP12CertificateWithName:(NSString *)certificateName
                                                        password:(NSString *)password
{
    NSArray *certificateChain = [self certificateChainFromP12CertificateWithName:certificateName
                                                                        password:password];

    if (!certificateChain) {
        return nil;
    }

    return @{(id) kCFStreamSSLCertificates: certificateChain};
}

+ (SSLContextRef _Nullable)sslContextRefFromP12CertificateWithName:(NSString *)certificateName
                                                          password:(NSString *)password
{
    NSArray *certificateChain = [self certificateChainFromP12CertificateWithName:certificateName
                                                                        password:password];

    if (!certificateChain) {
        return nil;
    }

    SSLContextRef context = SSLCreateContext(kCFAllocatorDefault, kSSLClientSide, kSSLStreamType);
    SSLSetCertificate(context, (__bridge CFArrayRef) certificateChain);

    return context;
}

+ (BOOL)setSSLContextCertificateChainFromP12CertificateWithName:(NSString *)certificateName
                                                       password:(NSString *)password
                                                         stream:(NSStream *)stream
{
    SSLContextRef context = stream.sslContext;
    if (!context) {
        return NO;
    }

    NSArray *certificates = [self certificateChainFromP12CertificateWithName:certificateName
                                                                    password:password];

    if (!certificates) {
        return NO;
    }

    OSStatus status = SSLSetCertificate(context, (__bridge CFArrayRef) certificates);
    if (status != noErr) {
        return NO;
    }

    stream.sslContext = context;
    return YES;
}

#pragma mark - Helpers

/// Extracts the certificate chain, the identity and the trust from the given p12 data blob.
/// @param p12Data The p12 data blob to parse
/// @param password The password that was used to encrypt the data
/// @param identity Pointer to ref, which will be set on success. You take ownership,
///   release when done with it.
/// @param trust Pointer to ref, which will be set on success. You take ownership,
///   release when done with it.
/// @returns On success, returns an array of `SecCertificateRef`,
///  and sets the pointers (identity and trust). On error, nil is returned.
+ (NSArray * _Nullable)extractCertificateDataFromP12Data:(NSData *)p12Data
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

/// Gathers all certificates from the given data, which is assumed
/// to be the result of a call to `SecPKCS12Import` as an `NSArray`.
/// @param dictionaries An array of dictionaries that are assumed to contain
///  an entry under `kSecImportItemCertChain`, which is supposed to be an array
///  of `SecCertificateRef`s.
/// @return An array of `SecCertificateRef`.
+ (NSArray *)extractCertificates:(NSArray<NSDictionary *> *)dictionaries
{
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:1];

    for (NSDictionary *dict in dictionaries) {
        NSArray *certificateChain = [dict objectForKey:(id) kSecImportItemCertChain];
        for (id certObj in certificateChain) {
            [result addObject:certObj];
        }
    }

    return [NSArray arrayWithArray:result];
}

/// Wraps `SecPKCS12Import`, that is parses the given p12 data, protected by the given password,
/// into a list of dictionaries.
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
