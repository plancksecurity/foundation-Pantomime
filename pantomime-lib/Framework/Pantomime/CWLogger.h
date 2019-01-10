//
//  CWLogger.h
//  Pantomime
//
//  Created by Dirk Zimmermann on 09/12/16.
//  Copyright © 2016 pEp Security S.A. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <os/log.h>

@protocol CWLogging <NSObject>

/** Log a verbose message */
- (void)infoComponent:(NSString * _Nonnull)component message:(NSString * _Nonnull)message;

/** Issue a warning */
- (void)warnComponent:(NSString * _Nonnull)component message:(NSString * _Nonnull)message;

/** Issue an error message */
- (void)errorComponent:(NSString * _Nonnull)component message:(NSString * _Nonnull)message;

@end

@interface CWLogger : NSObject

+ (void)setLogger:(id<CWLogging> _Nonnull)logger;
+ (id<CWLogging> _Nullable)logger;

@end

extern os_log_t theLog(void);

#define INFO(format, ...) \
if (@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)) {\
  os_log_info(theLog(), format, ##__VA_ARGS__);\
}

/**
 There is no WARN for os_log, the closest is just using `default`, which we do.
 */
#define WARN(format, ...) \
if (@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)) {\
  os_log(theLog(), format, ##__VA_ARGS__);\
}

/**
 This uses os_log's `default`, like WARN does.
 */
#define LOG(format, ...) \
if (@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)) {\
os_log(theLog(), format, ##__VA_ARGS__);\
}

#define ERROR(format, ...) \
if (@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)) {\
  os_log_error(theLog(), format, ##__VA_ARGS__);\
}
