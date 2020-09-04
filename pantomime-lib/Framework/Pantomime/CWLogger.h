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

#define LOG(format, ...) DDLogInfo(format, ##__VA_ARGS__)
#define INFO(format, ...) DDLogInfo(format, ##__VA_ARGS__)
#define WARN(format, ...) DDLogWarn(format, ##__VA_ARGS__)
#define ERROR(format, ...) DDLogError(format, ##__VA_ARGS__)
