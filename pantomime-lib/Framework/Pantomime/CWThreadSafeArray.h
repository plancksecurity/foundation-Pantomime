//
//  CWThreadSafeArray.h
//  Pantomime
//
//  Created by Dirk Zimmermann on 27/05/16.
//  Copyright © 2016 pEp Security S.A. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CWThreadSafeArray : NSObject

- (instancetype _Nullable)init;
- (instancetype _Nullable)initWithArray:(NSArray * _Nonnull)anArray;
- (void)removeAllObjects;
- (NSUInteger)count;
- (id _Nullable)lastObject;
- (void)addObject:(id _Nonnull)obj;
- (id _Nonnull)objectAtIndex:(NSUInteger)index;
- (void)insertObject:(id _Nonnull)anObject atIndex:(NSUInteger)index;
- (void)removeLastObject;
- (void)addObjectsFromArray:(NSArray * _Nonnull)otherArray;
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState * _Nonnull)state
                                  objects:(id _Nonnull __unsafe_unretained [])buffer
                                    count:(NSUInteger)len;
- (BOOL)containsObject:(id _Nonnull)anObject;
- (void)removeObjectsInArray:(NSArray * _Nonnull)otherArray;
- (NSArray * _Nonnull)array;

@end
