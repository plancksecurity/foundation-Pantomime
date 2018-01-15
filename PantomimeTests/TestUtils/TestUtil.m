//
//  TestUtil.m
//  Pantomime
//
//  Created by Dirk Zimmermann on 27/02/2017.
//  Copyright © 2017 pEp Security S.A. All rights reserved.
//

#import "TestUtil.h"

#import <XCTest/XCTest.h>

@implementation TestUtil

+ (NSData  * _Nullable)loadDataWithFileName:(NSString * _Nonnull)fileName
{
    NSBundle *bundle = [NSBundle bundleForClass:self.class];
    NSString *path = [bundle pathForResource:fileName ofType:nil];
    NSURL *url = [NSURL fileURLWithPath:path];
    NSData *data = [NSData dataWithContentsOfURL:url];
    return data;
}

/**
 Extracts exactly 2 Int-Strings from a given String.
 */
+ (NSArray<NSString *> *_Nonnull)extractIntsFromString:(NSString *_Nonnull)string
                                               pattern:(NSString *_Nonnull)pattern
{
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression
                                  regularExpressionWithPattern:pattern
                                  options:0 error:&error];
    NSArray *matches = [regex matchesInString:string options:0
                                        range:NSMakeRange(0, string.length - 1)];
    if (matches.count == 1) {
        NSTextCheckingResult *result = [matches firstObject];
        if (result.numberOfRanges == 3) {
            NSString *s1 = [string substringWithRange:[result rangeAtIndex:1]];
            NSString *s2 = [string substringWithRange:[result rangeAtIndex:2]];
            return @[s1, s2];
        }
    }
    return @[];
}

@end
