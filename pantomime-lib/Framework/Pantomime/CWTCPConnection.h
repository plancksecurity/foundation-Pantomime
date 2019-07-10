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

/** Required from CWConnection */
@property (nonatomic, nullable, weak) id<CWConnectionDelegate> delegate;

/**
 The thread where the read- and write streams are scheduled on.
 */
@property (nonatomic, readonly, nullable) NSThread *backgroundThread;

/**
 Is this connection connected to a server and alive?
  A connection is not connected:
   * Before the connection to the server is established.
   * When there was an error.
   * When the server closed the connection.
 */
@property (nonatomic, readonly) BOOL isConnected;

@end
