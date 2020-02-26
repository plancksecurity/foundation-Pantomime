//
//  ClientCertificateTest.m
//  PantomimeFrameworkTests
//
//  Created by Dirk Zimmermann on 26.02.20.
//  Copyright © 2020 pEp Security. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <PantomimeFramework/PantomimeFramework.h>

#import "CWCertificateLoader.h"

static NSString *s_pfxBundleFilename = @"s_pfxBundleFilename";
static NSString *s_pfxBundlePassword = @"s_pfxBundlePassword";
static NSString *s_serverName = @"s_serverName";

static NSTimeInterval s_timeout = 10;

@interface ClientCertificateTest : XCTestCase

@property (nonatomic) SecIdentityRef certificate;
@property (nonatomic) XCTestExpectation *loggedIn;

@end

@implementation ClientCertificateTest

- (void)setUp
{
    NSBundle *myBundle = [NSBundle bundleForClass:[self class]];
    XCTAssertNotNil(myBundle);
    NSString *path = [myBundle pathForResource:s_pfxBundleFilename ofType:nil];
    XCTAssertNotNil(path);
    NSData *p12data = [NSData dataWithContentsOfFile:path];
    XCTAssertNotNil(p12data);
    self.certificate = [CWCertificateLoader secIdentityData:p12data
                                                   password:s_pfxBundlePassword];
    XCTAssertNotNil((__bridge id) self.certificate);
}

- (void)tearDown
{
}

- (void)testIMAP
{
    self.loggedIn = [self expectationWithDescription:@"loggedIn"];

    CWIMAPStore *imap = [[CWIMAPStore alloc] initWithName:s_serverName
                                                     port:993
                                                transport:ConnectionTransportTLS
                                        clientCertificate:self.certificate];
    imap.delegate = self;
    [imap connectInBackgroundAndNotify];
    [self waitForExpectations:@[self.loggedIn] timeout:s_timeout];
}

@end

@implementation ClientCertificateTest (CWServiceClient)

- (void) serviceInitialized: (NSNotification * _Nullable) theNotification
{
    NSLog(@"serviceInitialized");
}

@end
