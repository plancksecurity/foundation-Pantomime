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

static os_log_t s_theLog;

#define INFO(format, ...) \
if (@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)) {\
  NSLog(@"*** YES ***");\
  os_log_with_type(s_theLog, OS_LOG_TYPE_INFO, format, ##__VA_ARGS__);\
} else {\
  NSLog(@"*** NO ***");\
  NSLog([NSString stringWithCString:format encoding:NSUTF8StringEncoding], ##__VA_ARGS__);\
}

#define WARN(format, ...) \
if (@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)) {\
  os_log_with_type(s_theLog, OS_LOG_TYPE_DEFAULT, format, ##__VA_ARGS__);\
} else {\
  NSLog([NSString stringWithCString:format encoding:NSUTF8StringEncoding], ##__VA_ARGS__);\
}

#define ERROR(format, ...) \
if (@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)) {\
  os_log_with_type(s_theLog, OS_LOG_TYPE_ERROR, format, ##__VA_ARGS__);\
} else {\
  NSLog([NSString stringWithCString:format encoding:NSUTF8StringEncoding], ##__VA_ARGS__);\
}
