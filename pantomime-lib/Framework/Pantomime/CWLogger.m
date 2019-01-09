//
//  CWLogger.m
//  Pantomime
//
//  Created by Dirk Zimmermann on 09/12/16.
//  Copyright © 2016 pEp Security S.A. All rights reserved.
//

#import "CWLogger.h"

#if OS_LOG_TARGET_HAS_10_13_FEATURES

static os_log_t s_theLog = os_log_create("pep.security.imap", "pantomime");

#endif

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
