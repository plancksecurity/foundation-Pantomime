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

@property (readwrite, nullable) SSLContextRef sslContext;

@end

NS_ASSUME_NONNULL_END
