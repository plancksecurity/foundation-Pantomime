//
//  NSString+PantomimeTestHelper.m
//  PantomimeTests
//
//  Created by Andreas Buff on 14.12.17.
//  Copyright © 2017 pEp Security S.A. All rights reserved.
//

#import "NSString+PantomimeTestHelper.h"

@implementation NSString (PantomimeTestHelper)

- (NSString *)quoted;
{
    return [NSString stringWithFormat:@"\"%@\"", self];
}

- (NSString *)unquoted;
{
    NSCharacterSet *quotes = [NSCharacterSet characterSetWithCharactersInString:@"\""];
    return [self stringByTrimmingCharactersInSet:quotes];
}

@end
