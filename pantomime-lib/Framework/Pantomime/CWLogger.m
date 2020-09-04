//
//  CWLogger.m
//  Pantomime
//
//  Created by Dirk Zimmermann on 09/12/16.
//  Copyright © 2016 pEp Security S.A. All rights reserved.
//

@import CocoaLumberjack;

#import "CWLogger.h"

@implementation CWLogger

+ (void)initialize
{
    if (self == [CWLogger class]) {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSURL * documentsUrl = [[fm URLsForDirectory:NSDocumentDirectory
                                           inDomains:NSUserDomainMask] firstObject];

        [DDLog addLogger:[DDOSLogger sharedInstance]]; // Uses os_log

        if (documentsUrl == nil) {
            DDLogWarn(@"Could not find the documents directory");
            return;
        }

        DDLogFileManagerDefault *fileManager = [[DDLogFileManagerDefault alloc]
                                                initWithLogsDirectory:documentsUrl.path];

        DDFileLogger *fileLogger = [[DDFileLogger alloc] initWithLogFileManager:fileManager];
        fileLogger.rollingFrequency = 60 * 60 * 24; // 24 hour rolling
        fileLogger.logFileManager.maximumNumberOfLogFiles = 7;
        [DDLog addLogger:fileLogger];
    }
}

+ (void)ping
{
}

@end
