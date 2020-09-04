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

@interface CWLogger : NSObject

+ (void)log:(NSString * _Nonnull)string;
+ (void)logInfo:(NSString * _Nonnull)string;
+ (void)logWarn:(NSString * _Nonnull)string;
+ (void)logError:(NSString * _Nonnull)string;

@end

extern os_log_t _Nonnull theLog(void);
extern NSString * _Nonnull varString(const char * _Nonnull format, ...);

#define INFO(format, ...) \
if (@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)) {\
  os_log_info(theLog(), format, ##__VA_ARGS__);\
  [CWLogger logInfo:varString(format, ##__VA_ARGS__)];\
} else {\
  [CWLogger logInfo:varString(format, ##__VA_ARGS__)];\
}

/**
 There is no WARN for os_log, the closest is just using `default`, which we do.
 */
#define WARN(format, ...) \
if (@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)) {\
  os_log(theLog(), format, ##__VA_ARGS__);\
  [CWLogger logWarn:varString(format, ##__VA_ARGS__)];\
} else {\
  [CWLogger logWarn:varString(format, ##__VA_ARGS__)];\
}

/**
 This uses os_log's `default`, like WARN does.
 */
#define LOG(format, ...) \
if (@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)) {\
os_log(theLog(), format, ##__VA_ARGS__);\
  [CWLogger log:varString(format, ##__VA_ARGS__)];\
} else {\
  [CWLogger log:varString(format, ##__VA_ARGS__)];\
}

#define ERROR(format, ...) \
if (@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)) {\
  os_log_error(theLog(), format, ##__VA_ARGS__);\
  [CWLogger logError:varString(format, ##__VA_ARGS__)];\
} else {\
  [CWLogger logError:varString(format, ##__VA_ARGS__)];\
}
