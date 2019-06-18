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

static id<CWLogging> s_logger;

@implementation CWLogger

+ (void)setLogger:(id<CWLogging> _Nonnull)logger
{
    s_logger = logger;
}

+ (id<CWLogging> _Nullable)logger
{
    return s_logger;
}

@end
