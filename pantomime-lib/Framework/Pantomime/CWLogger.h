//
//  CWLogger.h
//  Pantomime
//
//  Created by Dirk Zimmermann on 09/12/16.
//  Copyright © 2016 pEp Security S.A. All rights reserved.
//

#import <Foundation/Foundation.h>

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

#define INFO(COMP, FORMAT, ...)\
[[CWLogger logger] infoComponent:COMP message:[NSString stringWithFormat:FORMAT, ##__VA_ARGS__]];

#define WARN(COMP, FORMAT, ...)\
[[CWLogger logger] warnComponent:COMP message:[NSString stringWithFormat:FORMAT, ##__VA_ARGS__]];

#define ERROR(COMP, FORMAT, ...)\
[[CWLogger logger] errorComponent:COMP message:[NSString stringWithFormat:FORMAT, ##__VA_ARGS__]];
