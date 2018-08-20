//
//  NSMutableString+Extension.m
//  PantomimeStatic
//
//  Created by Andreas Buff on 20.08.18.
//  Copyright © 2018 pEp Security S.A. All rights reserved.
//

#import "NSMutableString+Extension.h"

@implementation NSMutableString (Extension)

- (void)unwrap;
{
    [self replaceOccurrencesOfString:@"<" withString:@""
                             options:0 range:NSMakeRange(0, self.length)];
    [self replaceOccurrencesOfString:@">" withString:@""
                             options:0 range:NSMakeRange(0, self.length)];
}

@end
