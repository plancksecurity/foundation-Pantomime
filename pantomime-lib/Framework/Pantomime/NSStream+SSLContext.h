//
//  NSStream+SSLContext.h
//  PantomimeFramework
//
//  Created by Dirk Zimmermann on 13.02.20.
//  Copyright © 2020 pEp Security. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSStream (SSLContext)

/// Gets or sets the SSL context.
/// @note Getting it transfers ownership to the caller, make sure you release it.
@property (readwrite, nullable) SSLContextRef sslContext;

/// Sets a property, using `CFReadStreamSetProperty()` or `CFWriteStreamSetProperty()`,
/// depending on the type of self.
/// @param property The property (value) to set
/// @param key The key under which the property gets set
- (void)setStreamProperty:(id)property forKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
