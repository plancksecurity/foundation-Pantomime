//
//  CWLogger.m
//  Pantomime
//
//  Created by Dirk Zimmermann on 09/12/16.
//  Copyright © 2016 pEp Security S.A. All rights reserved.
//

#import "CWLogger.h"

static os_log_t s_theLog;

os_log_t theLog(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_theLog = os_log_create("security.pEp.app.pEpForiOS.pantomime", "general");
    });
    return s_theLog;
}

extern NSString * _Nonnull varString(const char * _Nonnull format, ...) {
    va_list args;
    va_start(args, format);
    NSString *formatString = [[NSString alloc]
                              initWithCString:format
                              encoding:NSUTF8StringEncoding];
    NSString *s = [[NSString alloc] initWithFormat:formatString arguments:args];
    va_end(args);
    return s;
}

@implementation CWLogger

+ (void)log:(NSString * _Nonnull)string
{
}

+ (void)logInfo:(NSString * _Nonnull)string
{
}

+ (void)logWarn:(NSString * _Nonnull)string
{
}

+ (void)logError:(NSString * _Nonnull)string
{
}

@end
