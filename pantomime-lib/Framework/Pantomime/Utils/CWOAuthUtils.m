//
//  CWOAuthUtils.m
//  PantomimeTests
//
//  Created by Andreas Buff on 12.01.18.
//  Copyright © 2018 pEp Security S.A. All rights reserved.
//

#import "CWOAuthUtils.h"

@implementation CWOAuthUtils

// MARK: - PUBLIC API

+ (NSString *)base64EncodedClientResponseForUser:(NSString *)user
                                     accessToken:(NSString *)accessToken
{
    NSString *response = [self clientResponseForUser:user accessToken:accessToken];
    NSData *data = [response dataUsingEncoding:NSASCIIStringEncoding];
    return [data base64EncodedStringWithOptions:0];
}

// MARK: - INTERNAL

/**
 Builds the OAuth2 client response for a given user and access token.

 Response format: 
 user={User}^Aauth=Bearer {Access Token}^A^A"
 where ^A represents a Control+A (\001).

 Example output:
 user=someuser@example.com^Aauth=Bearer vF9dft4qmTc2Nvb3RlckBhdHRhdmlzdGEuY29tCg==^A^A

 @param user user to create client response for
 @param accessToken OAuth2 access token
 @return client response
 */
+ (NSString *)clientResponseForUser:(NSString *)user accessToken:(NSString *)accessToken
{
    return [NSString stringWithFormat: @"user=%@\001auth=Bearer %@\001\001", user, accessToken];
}

@end
