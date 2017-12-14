//
//  NSString+PantomimeTestHelper.h
//  PantomimeTests
//
//  Created by Andreas Buff on 14.12.17.
//  Copyright © 2017 pEp Security S.A. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (PantomimeTestHelper)

- (NSString *)quoted;

- (NSString *)unquoted;

@end
