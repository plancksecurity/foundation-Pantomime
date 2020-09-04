//
//  CWLogger.h
//  Pantomime
//
//  Created by Dirk Zimmermann on 09/12/16.
//  Copyright © 2016 pEp Security S.A. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <os/log.h>

@import CocoaLumberjack;

static const DDLogLevel ddLogLevel = DDLogLevelDebug;

@interface CWLogger : NSObject

/// Make sure the logging system is initialized.
+ (void)ping;

@end

#define nsString(format) [[NSString alloc] initWithCString:format encoding:NSUTF8StringEncoding]

#define LOG(format, ...) DDLogInfo(nsString(format), ##__VA_ARGS__)
#define INFO(format, ...) DDLogInfo(nsString(format), ##__VA_ARGS__)
#define WARN(format, ...) DDLogWarn(nsString(format), ##__VA_ARGS__)
#define ERROR(format, ...) DDLogError(nsString(format), ##__VA_ARGS__)
