//
//  NSMutableString+Extension.h
//  PantomimeStatic
//
//  Created by Andreas Buff on 20.08.18.
//  Copyright © 2018 pEp Security S.A. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableString (Extension)

/**
 Unwraps the receiver (if wrapped in angle brackets).
 Example: "<Hello Wolrd>" -> "Hello Wolrd"
 */
- (void)unwrap;

@end
