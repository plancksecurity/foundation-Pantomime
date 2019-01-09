//
//  CWLogger.h
//  Pantomime
//
//  Created by Dirk Zimmermann on 09/12/16.
//  Copyright © 2016 pEp Security S.A. All rights reserved.
//

#import <Foundation/Foundation.h>

#if OS_LOG_TARGET_HAS_10_13_FEATURES
#import <os/log.h>
#endif

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

#if OS_LOG_TARGET_HAS_10_13_FEATURES

static os_log_t s_theLog;

#define INFO(format, ...) \
os_log_with_type(s_theLog, OS_LOG_TYPE_INFO, format, ##__VA_ARGS__);

#define WARN(format, ...) \
os_log_with_type(s_theLog, OS_LOG_TYPE_DEFAULT, format, ##__VA_ARGS__);

#define ERROR(format, ...) \
os_log_with_type(s_theLog, OS_LOG_TYPE_ERROR, format, ##__VA_ARGS__);

#else

#define INFO(format, ...) \
fprintf(stderr, "INFO %s ", __FUNCTION__);\
fprintf(stderr, format, ##__VA_ARGS__);\
fprintf(stderr, "\n");

#define WARN(format, ...) \
fprintf(stderr, "WARN %s ", __FUNCTION__);\
/*fprintf(stderr, format, ##__VA_ARGS__);*/\
fprintf(stderr, "\n");

#define ERROR(format, ...) \
fprintf(stderr, "ERROR %s ", __FUNCTION__);\
/*fprintf(stderr, format, ##__VA_ARGS__);*/\
fprintf(stderr, "\n");

#endif
