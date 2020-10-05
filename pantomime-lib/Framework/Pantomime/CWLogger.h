//
//  CWLogger.h
//  Pantomime
//
//  Created by Dirk Zimmermann on 09/12/16.
//  Copyright © 2016 pEp Security S.A. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <pEpIOSToolbox/pEpIOSToolbox-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@interface CWLogger : NSObject

+ (void)logInfoFilename:(const char *)filename
               function:(const char *)function
                   line:(NSInteger)line
                 message:(NSString *)message;

@end

#define LogInfo(...) [[Log shared] \
logInfoWithMessage:[NSString stringWithFormat:__VA_ARGS__] \
function:[NSString stringWithUTF8String:__FUNCTION__] \
filePath:[NSString stringWithUTF8String:__FILE__] \
fileLine:__LINE__]; //[CWLogger logInfoFilename:__FILE__ function:__FUNCTION__ line:__LINE__ message:[NSString stringWithFormat:__VA_ARGS__]];
#define LogWarn(...) NSLog(@"WARN %s:%d %@", __FILE__, __LINE__, [NSString stringWithFormat:__VA_ARGS__]);
#define LogError(...) NSLog(@"ERROR %s:%d %@", __FILE__, __LINE__, [NSString stringWithFormat:__VA_ARGS__]);

NS_ASSUME_NONNULL_END
