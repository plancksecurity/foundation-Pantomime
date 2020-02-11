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

+ (NSURLCredential * _Nullable)loadCertificateWithName:(NSString *)certificateName
                                              password:(NSString *)password
{
    NSString *sslCertName = certificateName;
    NSString *path2 = [[NSBundle mainBundle] pathForResource:sslCertName ofType:nil];
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
    CFRelease(myIdentity);
    CFRelease(myTrust);

    return secureCredential;
}

- (BOOL)addToKeyChainP12Data:(NSData *)p12Data withPassphrase:(NSString *)passphrase {
    BOOL lastError = false;

    NSDictionary *p12Options = @{(id) kSecImportExportPassphrase: passphrase};

    CFArrayRef items = CFArrayCreate(NULL, 0, 0, NULL);
    OSStatus err = SecPKCS12Import((CFDataRef) p12Data, (CFDictionaryRef) p12Options, &items);
    if (err != noErr) {
        return NO;
    }
    if (!lastError && err == noErr && CFArrayGetCount(items) > 0) {
        CFDictionaryRef identityDict = CFArrayGetValueAtIndex(items, 0);
        // Clean-up

        NSArray *secItemClasses = @[(id) kSecClassCertificate,
                                    (id) kSecClassKey,
                                    (id) kSecClassIdentity];

        for (id secItemClass in secItemClasses) {
            NSDictionary *spec = @{(id) kSecClass: secItemClass};
            err = SecItemDelete((CFDictionaryRef) spec);
        }

        // Client Identity & Certificate

        SecIdentityRef clientIdentity = (SecIdentityRef) CFDictionaryGetValue(identityDict,
                                                                              kSecImportItemIdentity);

        NSString *kClientIdentityLabel = @"kClientIdentityLabel"; // arbitrary label
        NSString *kServerCertificateLabel = @"kServerCertificateLabel"; // arbitrary label

        NSDictionary *addIdentityQuery = @{(id) kSecAttrLabel: kClientIdentityLabel,
                                           (id) kSecValueRef: (__bridge id) clientIdentity};
        err = SecItemAdd((CFDictionaryRef) addIdentityQuery, NULL);
        if (err != noErr) {
            return NO;
        }
        // Server Certificate
        CFArrayRef chain = CFDictionaryGetValue(identityDict, kSecImportItemCertChain);
        CFIndex chainCount = CFArrayGetCount(chain);
        BOOL shouldBreak = false;
        for (CFIndex i = 0; (i < chainCount) && (!shouldBreak); i++) {
            SecCertificateRef cert = (SecCertificateRef)CFArrayGetValueAtIndex(chain, i);
            CFStringRef summary = SecCertificateCopySubjectSummary(cert);
            NSString *strSummary = (__bridge NSString *) summary;
            if ([strSummary containsString:@"Root"] || (i == chainCount)) {
                NSDictionary *addCertQuery = @{(id) kSecAttrLabel: kServerCertificateLabel,
                                               (id) kSecValueRef: (__bridge id) cert};
                err = SecItemAdd((CFDictionaryRef)addCertQuery, NULL);
                if (err != noErr) {
                    return NO;
                }
                shouldBreak = true;
            }
            CFRelease(summary);
        }
    }
    else {
        return NO;
    }
    CFRelease(items);

    return YES;
}

@end
