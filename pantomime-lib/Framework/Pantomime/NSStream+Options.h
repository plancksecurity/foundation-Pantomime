//
//  NSStream+Options.h
//  PantomimeFramework
//
//  Created by Dirk Zimmermann on 13.02.20.
//  Copyright © 2020 pEp Security. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSStream (Options)

/// Sets a property, using `CFReadStreamSetProperty` or `CFWriteStreamSetProperty`,
/// depending on the type of self.
/// @param property The property (value) to set
/// @param key The key under which the property gets set
- (void)setStreamProperty:(id)property forKey:(NSString *)key;

/// Gets a property, using `CFReadStreamGetProperty` or `CFWriteStreamGetProperty`,
/// depending on the type of self.
/// @param key The key for the property to read
- (id _Nullable)getStreamPropertyKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
