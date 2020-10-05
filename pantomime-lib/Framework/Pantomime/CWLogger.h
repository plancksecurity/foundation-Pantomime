//
//  CWLogger.h
//  Pantomime
//
//  Created by Dirk Zimmermann on 09/12/16.
//  Copyright © 2016 pEp Security S.A. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CWLogger : NSObject

+ (void)logInfoFilename:(const char *)filename
               function:(const char *)function
                   line:(NSInteger)line
                 message:(NSString *)message;

@end

#define LogInfo(...) 
#define LogWarn(...) NSLog(@"WARN %s:%d %@", __FILE__, __LINE__, [NSString stringWithFormat:__VA_ARGS__]);
#define LogError(...) NSLog(@"ERROR %s:%d %@", __FILE__, __LINE__, [NSString stringWithFormat:__VA_ARGS__]);

NS_ASSUME_NONNULL_END
