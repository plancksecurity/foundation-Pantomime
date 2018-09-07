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
    return [self firstOccurrenceOfOneIn:seachFor inRange:range ignoreQuoted:ignoreQuoted];
}

#pragma mark - Other

- (NSRange)firstOccurrenceOfOneIn:(NSArray<NSString*> *)searchTerms
                          inRange:(NSRange)range
                     ignoreQuoted:(BOOL)ignoreQuoted;
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

- (NSArray<NSNumber*> *)locationsOfQuotes;
{
    return [self locationsOfChar:'\"'];
}

- (NSArray<NSNumber*> *)locationsOfChar:(char)seachChar
{
    return [self locationsOfChar:seachChar inRange:NSMakeRange(0, 1)];

}

- (NSArray<NSNumber*> *)locationsOfChar:(char)seachChar inRange:(NSRange)range
{
    NSMutableArray<NSNumber*> *locations = @[];
    NSInteger oneChar = 1;
    NSRange curRange = range;
    while (curRange.location < self.length && (curRange.location + curRange.length < self.length) ) {
        NSRange found = [self rangeOfCString: &seachChar options:0 range: range];
        if (found.location == NSNotFound) {
            break;
        }
        [locations addObject:@(found.location)];
        NSInteger nextLocation = curRange.location + oneChar;
        curRange = NSMakeRange(nextLocation, self.length - nextLocation);
    }

    return locations;
}

@end
