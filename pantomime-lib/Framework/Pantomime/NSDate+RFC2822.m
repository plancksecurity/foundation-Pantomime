//
//  NSDate+RFC2822.m
//  Pantomime
//
//  Created by Dirk Zimmermann on 12/04/16.
//  Copyright © 2016 p≡p Security S.A. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NSDate+RFC2822.h"

@implementation NSDate (RFC2822) //BUFF: rename!

- (NSString *)rfc2822String {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"EEE, dd MMM yyyy HH:mm:ss Z";
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    return [formatter stringFromDate:self];
}

- (NSString *)dateTimeString {
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateFormat = @"dd-MMM-yyyy HH:mm:ss Z";
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    return [formatter stringFromDate:self];
}

@end
