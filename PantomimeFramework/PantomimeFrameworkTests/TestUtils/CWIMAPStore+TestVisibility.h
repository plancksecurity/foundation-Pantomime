//
//  CWIMAPStore+TestVisibility.h
//  PantomimeTests
//
//  Created by Andreas Buff on 19.04.18.
//  Copyright © 2018 pEp Security S.A. All rights reserved.
//

#import <PantomimeFramework/CWIMAPStore.h>

/**
 Makes private methods visible for test target
 */
@interface CWIMAPStore (TestVisibility)
- (NSArray *)_uniqueIdentifiersFromFetchUidsResponseData:(NSData *)response;
- (NSArray *)_uniqueIdentifiersFromSearchResponseData:(NSData *)response;
@end
