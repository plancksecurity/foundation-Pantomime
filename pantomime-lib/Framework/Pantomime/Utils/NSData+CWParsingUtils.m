//
//  NSData+CWParsingUtils.m
//  PantomimeStatic
//
//  Created by Andreas Buff on 07.09.18.
//  Copyright © 2018 pEp Security S.A. All rights reserved.
//

#import "NSData+CWParsingUtils.h"

#import "NSData+Extensions.h"
#import "NSString+Extensions.h"

@implementation NSData (CWParsingUtils)

#pragma mark - API

- (NSRange)firstSemicolonOrNewlineInRange:(NSRange)range;
{
    return [self firstSemicolonOrNewlineInRange:range ignoreQuoted:NO];
}

- (NSRange)firstSemicolonOrNewlineInRange:(NSRange)range ignoreQuoted:(BOOL)ignoreQuoted;
{
    NSArray *seachFor = @[@";", @"\n"];
    return [self firstOccurrenceOfOneIn:seachFor inRange:range];
}

#pragma mark - Other

- (NSRange)firstOccurrenceOfOneIn:(NSArray<NSString*> *)searchTerms
                          inRange:(NSRange)range
{
    NSRange nearestRange = NSMakeRange(NSNotFound, 0);
    for (NSString *searchFor in searchTerms) {
        NSRange found = [self rangeOfCString:[searchFor cStringUsingEncoding:NSASCIIStringEncoding] //IOS-1303: maybe
                                     options:0
                                       range:range];
        if (found.location == NSNotFound) {
            continue;
        }

        if (found.location < nearestRange.location) {
            nearestRange = found;
        }
    }
    return nearestRange;
}

@end
