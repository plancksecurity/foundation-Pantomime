//
//  CWLogging.h
//  Pantomime
//
//  Created by Dirk Zimmermann on 12/04/16.
//  Copyright © 2016 pEp Security S.A. All rights reserved.
//

#ifndef CWLogging_h
#define CWLogging_h

#import <Foundation/Foundation.h>

@protocol CWLogging <NSObject>

/** Log a verbose message */
- (void)infoComponent:(NSString *)component message:(NSString *)message;

- (void)warnComponent:(NSString *)component message:(NSString *)message;

@end


#endif /* CWLogging_h */
