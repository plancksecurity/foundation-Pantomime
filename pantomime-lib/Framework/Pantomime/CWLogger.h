//
//  CWLogger.h
//  Pantomime
//
//  Created by Dirk Zimmermann on 09/12/16.
//  Copyright © 2016 pEp Security S.A. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CWLogger : NSObject

/// Make sure the logging system is initialized.
+ (void)ping;

@end

#define DDLogInfo(...) NSLog(@"INFO %@:%@ %@", __FILE__, __LINE__, [NSString stringWithFormat:__VA_ARGS__]);
#define DDLogWarn(...) NSLog(@"WARN %@:%@ %@", __FILE__, __LINE__, [NSString stringWithFormat:__VA_ARGS__]);
#define DDLogError(...) NSLog(@"ERROR %@:%@ %@", __FILE__, __LINE__, [NSString stringWithFormat:__VA_ARGS__]);
