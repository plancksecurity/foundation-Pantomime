//
//  ClientCertificateSmtpTest.m
//  PantomimeFrameworkTests
//
//  Created by Dirk Zimmermann on 27.02.20.
//  Copyright © 2020 pEp Security. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <PantomimeFramework/PantomimeFramework.h>

#import "CWCertificateLoader.h"

static NSString *s_pfxBundleFilename = @"s_pfxBundleFilename";
static NSString *s_pfxBundlePassword = @"s_pfxBundlePassword";
static NSString *s_serverName = @"s_serverName";
static NSString *s_serverUsername = @"s_serverUsername";
static NSString *s_serverPassword = @"s_serverPassword";

static NSTimeInterval s_timeout = 10;

@interface ClientCertificateSmtpTest : XCTestCase

@property (nonatomic) SecIdentityRef certificate;
@property (nonatomic) XCTestExpectation *didAuthenticateExpectation;
@property (nonatomic) CWSMTP *smtp;

@end

@implementation ClientCertificateSmtpTest

- (void)setUp
{
    NSBundle *myBundle = [NSBundle bundleForClass:[self class]];
    XCTAssertNotNil(myBundle);
    NSString *path = [myBundle pathForResource:s_pfxBundleFilename ofType:nil];
    XCTAssertNotNil(path);
    NSData *p12data = [NSData dataWithContentsOfFile:path];
    XCTAssertNotNil(p12data);
    self.certificate = [CWCertificateLoader secIdentityData:p12data password:s_pfxBundlePassword];
    XCTAssertNotNil((__bridge id) self.certificate);
}

- (void)tearDown
{
}

- (void)testSMTP
{
    self.didAuthenticateExpectation = [self expectationWithDescription:@"loggedIn"];

    self.smtp = [[CWSMTP alloc] initWithName:s_serverName
                                        port:587
                                   transport:ConnectionTransportTLS
                           clientCertificate:self.certificate];
    self.smtp.delegate = self;
    [self.smtp connectInBackgroundAndNotify];
    [self waitForExpectations:@[self.didAuthenticateExpectation] timeout:s_timeout];
}

@end

@implementation ClientCertificateSmtpTest (CWServiceClient)

- (void)serviceInitialized:(NSNotification * _Nullable)theNotification
{
    [self.smtp authenticate:s_serverUsername
                   password:s_serverPassword
                  mechanism:@"PLAIN"];
}

- (void)authenticationCompleted:(NSNotification * _Nullable)theNotification
{
    [self.didAuthenticateExpectation fulfill];
}

- (void)authenticationFailed:(NSNotification * _Nullable)theNotification
{
    XCTFail();
    [self.didAuthenticateExpectation fulfill];
}

@end
