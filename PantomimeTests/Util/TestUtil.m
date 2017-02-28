//
//  TestUtil.m
//  Pantomime
//
//  Created by Dirk Zimmermann on 27/02/2017.
//  Copyright © 2017 pEp Security S.A. All rights reserved.
//

#import "TestUtil.h"

@implementation TestUtil

+ (NSData  * _Nullable)loadDataWithFileName:(NSString * _Nonnull)fileName
{
    NSBundle *bundle = [NSBundle bundleForClass:self.class];
    NSString *path = [bundle pathForResource:fileName ofType:nil];
    NSURL *url = [NSURL fileURLWithPath:path];
    NSData *data = [NSData dataWithContentsOfURL:url];
    return data;
}

@end
