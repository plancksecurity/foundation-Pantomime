//
//  NSData+CWParsingUtils.h
//  PantomimeStatic
//
//  Created by Andreas Buff on 07.09.18.
//  Copyright © 2018 pEp Security S.A. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (CWParsingUtils)

/**
 First occurrence of ";" or "\n"

 @param range range to search in
 @return range of first occurence if found, NSNotFond otherwize
 */
- (NSRange)firstSemicolonOrNewlineInRange:(NSRange)range;

@end
