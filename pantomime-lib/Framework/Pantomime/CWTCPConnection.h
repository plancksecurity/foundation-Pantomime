//
//  CWTCPConnection.h
//  Pantomime
//
//  Created by Dirk Zimmermann on 12/04/16.
//  Copyright © 2016 p≡p Security S.A. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CWConnection.h"

#import "Pantomime/CWLogger.h"

@interface CWTCPConnection : NSObject<CWConnection, NSURLSessionDelegate>

/// Required from CWConnection
@property (nonatomic, nullable, weak) id<CWConnectionDelegate> delegate;

/// The timeout for reading data
@property (nonatomic) NSTimeInterval readTimeout;

/// The timeout for writing data
@property (nonatomic) NSTimeInterval writeTimeout;

/// The size of the read buffer
@property (nonatomic) NSUInteger readBufferSize;

@end
