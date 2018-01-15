//
//  CWOAuthUtils.h
//  PantomimeTests
//
//  Created by Andreas Buff on 12.01.18.
//  Copyright © 2018 pEp Security S.A. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CWOAuthUtils : NSObject

+ (NSString *)base64EncodedClientResponseForUser:(NSString *)user
                                     accessToken:(NSString *)accessToken;

@end
