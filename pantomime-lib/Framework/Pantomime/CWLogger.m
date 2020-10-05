//
//  CWLogger.m
//  Pantomime
//
//  Created by Dirk Zimmermann on 09/12/16.
//  Copyright © 2016 pEp Security S.A. All rights reserved.
//

#import <pEpIOSToolbox/pEpIOSToolbox-Swift.h>

#import "CWLogger.h"

@implementation CWLogger

+ (void)logInfoFilename:(const char *)filename
               function:(const char *)function
                   line:(NSInteger)line
                message:(NSString *)message
{
    [[Log shared]
     logInfoWithMessage:message
     function:[NSString stringWithUTF8String:function]
     filePath:[NSString stringWithUTF8String:filename]
     fileLine:line];
}

@end
