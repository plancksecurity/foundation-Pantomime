//
//  NSData+CWParsingUtils.h
//  PantomimeStatic
//
//  Created by Andreas Buff on 07.09.18.
//  Copyright © 2018 pEp Security S.A. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (CWParsingUtils)

- (NSRange)firstSemicolonOrNewlineInRange:(NSRange)range;

@end
