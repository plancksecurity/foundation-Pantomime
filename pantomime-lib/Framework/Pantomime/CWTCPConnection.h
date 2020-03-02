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

@interface CWTCPConnection : NSObject<CWConnection, NSStreamDelegate>

/// Required from CWConnection
@property (nonatomic, nullable, weak) id<CWConnectionDelegate> delegate;

/// The first (or most specific, if known) error that canceled a connection
@property (nonatomic, nullable, strong) NSError *streamError;

@end
