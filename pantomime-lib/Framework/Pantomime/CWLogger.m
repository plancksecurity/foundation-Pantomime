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
        [DDLog addLogger:[DDOSLogger sharedInstance]]; // Uses os_log
    }
}

+ (void)ping
{
}

@end
