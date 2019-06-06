//
//  NSString+PEPDataUtils.h
//  PantomimeTests
//
//  Created by Andreas Buff on 31.01.18.
//  Copyright © 2018 pEp Security S.A. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (PEPDataUtils)

/**
 Creates `NSData` from hexadecimal string representation.
 Takes a hexadecimal representation and creates a `NSData` object.
 Note:  if the string has any spaces or non-hex characters (spaces, '<' and '>'), those are ignored
 and only hex characters are processed.

 @return data converted from hex string representation
 */
- (NSData *)dataFromHexString;

@end
