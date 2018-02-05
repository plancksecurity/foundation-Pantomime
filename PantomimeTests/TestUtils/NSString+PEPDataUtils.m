//
//  NSString+PEPDataUtils.m
//  PantomimeTests
//
//  Created by Andreas Buff on 31.01.18.
//  Copyright © 2018 pEp Security S.A. All rights reserved.
//

#import "NSString+PEPDataUtils.h"

@implementation NSString (PEPDataUtils)

- (NSData *)dataFromHexString;
{
    NSString *hexString = self.copy;
    hexString = [hexString stringByReplacingOccurrencesOfString:@" " withString:@""];
    hexString = [hexString stringByReplacingOccurrencesOfString:@"<" withString:@""];
    hexString = [hexString stringByReplacingOccurrencesOfString:@">" withString:@""];

    NSMutableData *result= [[NSMutableData alloc] init];
    unsigned char whole_byte;
    char byte_chars[3] = {'\0','\0','\0'};
    int i;
    for (i=0; i < [hexString length] / 2; i++) {
        byte_chars[0] = [hexString characterAtIndex:i*2];
        byte_chars[1] = [hexString characterAtIndex:i*2+1];
        whole_byte = strtol(byte_chars, NULL, 16);
        [result appendBytes:&whole_byte length:1];
    }

    return result;
}

@end
