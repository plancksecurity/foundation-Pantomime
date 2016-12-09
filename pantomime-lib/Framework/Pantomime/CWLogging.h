//
//  CWLogging.h
//  Pantomime
//
//  Created by Dirk Zimmermann on 12/04/16.
//  Copyright © 2016 p≡p Security S.A. All rights reserved.
//

#ifndef CWLogging_h
#define CWLogging_h

#import <Foundation/Foundation.h>

@protocol CWLogging <NSObject>

/** Log a verbose message */
- (void)infoComponent:(NSString *)component message:(NSString *)message;

/** Issue a warning */
- (void)warnComponent:(NSString *)component message:(NSString *)message;

/** Issue an error message */
- (void)errorComponent:(NSString *)component message:(NSString *)message;

@end


#endif /* CWLogging_h */
