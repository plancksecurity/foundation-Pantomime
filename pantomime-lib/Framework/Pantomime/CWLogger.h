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

+ (void)logWarnFilename:(const char *)filename
               function:(const char *)function
                   line:(NSInteger)line
                message:(NSString *)message;

+ (void)logErrorFilename:(const char *)filename
                function:(const char *)function
                    line:(NSInteger)line
                 message:(NSString *)message;

@end

#define LogInfo(...) [CWLogger logInfoFilename:__FILE__ function:__FUNCTION__ line:__LINE__ message:[NSString stringWithFormat:__VA_ARGS__]];
#define LogWarn(...) [CWLogger logWarnFilename:__FILE__ function:__FUNCTION__ line:__LINE__ message:[NSString stringWithFormat:__VA_ARGS__]];
#define LogError(...) [CWLogger logErrorFilename:__FILE__ function:__FUNCTION__ line:__LINE__ message:[NSString stringWithFormat:__VA_ARGS__]];

NS_ASSUME_NONNULL_END
