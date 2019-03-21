//
//  TestUtil.h
//  Pantomime
//
//  Created by Dirk Zimmermann on 27/02/2017.
//  Copyright © 2017 pEp Security S.A. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NSString+PEPDataUtils.h"

@interface TestUtil : NSObject

+ (NSData  * _Nullable)loadDataWithFileName:(NSString * _Nonnull)fileName;

/**
 Extracts exactly 2 Int-Strings from a given String.
 */
+ (NSArray<NSString *> *_Nonnull)extractIntsFromString:(NSString *_Nonnull)string
                                               pattern:(NSString *_Nonnull)pattern;

@end
