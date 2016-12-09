//
//  CWThreadSafeArray.m
//  Pantomime
//
//  Created by Dirk Zimmermann on 27/05/16.
//  Copyright © 2016 pEp Security S.A. All rights reserved.
//

#import "CWLogger.h"

#import "CWThreadSafeArray.h"

@interface CWThreadSafeArray ()

@property (nonatomic, strong) NSMutableOrderedSet *elements;
@property (nonatomic) dispatch_queue_t backgroundQueue;

@end

@implementation CWThreadSafeArray

- (instancetype _Nullable)init
{
    self = [super init];
    if (self) {
        INFO(NSStringFromClass([self class]), @"CWThreadSafeArray.init %@\n", self);
        _backgroundQueue = dispatch_queue_create("ThreadSafeArray", DISPATCH_QUEUE_SERIAL);
        _elements = [[NSMutableOrderedSet alloc] init];
    }
    return self;
}

- (instancetype _Nullable)initWithArray:(NSArray * _Nonnull)anArray
{
    self = [self init];
    if (self) {
        _elements = [[NSMutableOrderedSet alloc] initWithArray:anArray];
    }
    return  self;
}

- (void)dealloc
{
    INFO(NSStringFromClass([self class]), @"CWThreadSafeArray.dealloc %@\n", self);
}

- (void)removeAllObjects
{
    dispatch_sync(self.backgroundQueue, ^{
        [self.elements removeAllObjects];
    });
}

- (NSUInteger)count
{
    __block NSUInteger theCount = 0;
    dispatch_sync(self.backgroundQueue, ^{
        theCount = self.elements.count;
    });
    return theCount;
}

- (id)lastObject
{
    __block id obj = nil;
    dispatch_sync(self.backgroundQueue, ^{
        id theLast = [self.elements lastObject];
        if (!theLast) {
            INFO(NSStringFromClass([self class]), @"self.count %lu", (unsigned long) self.elements.count);
            for (id o in self.elements) {
                INFO(NSStringFromClass([self class]), @"Element %@", o);
            }
        }
        obj = theLast;
    });
    return obj;
}

- (void)addObject:(id _Nonnull)obj
{
    dispatch_sync(self.backgroundQueue, ^{
        if (!obj) {
            INFO(NSStringFromClass([self class]), @"There: Trying to add nil!");
        }
        [self.elements addObject:obj];
    });
}

- (id _Nonnull)objectAtIndex:(NSUInteger)index
{
    __block id obj = nil;
    dispatch_sync(self.backgroundQueue, ^{
        obj = [self.elements objectAtIndex:index];
    });
    return obj;
}

- (void)insertObject:(id)anObject atIndex:(NSUInteger)index
{
    dispatch_sync(self.backgroundQueue, ^{
        [self.elements insertObject:anObject atIndex:index];
    });
}

- (void)removeLastObject
{
    dispatch_sync(self.backgroundQueue, ^{
        [self.elements removeObjectAtIndex:self.elements.count - 1];
    });
}

- (void)addObjectsFromArray:(NSArray * _Nonnull)otherArray
{
    dispatch_sync(self.backgroundQueue, ^{
        [self.elements addObjectsFromArray:otherArray];
    });
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState * _Nonnull)state
                                  objects:(id _Nonnull __unsafe_unretained [])buffer
                                    count:(NSUInteger)len
{
    __block NSUInteger result = 0;
    dispatch_sync(self.backgroundQueue, ^{
        result = [self.elements countByEnumeratingWithState:state objects:buffer count:len];
    });
    return result;
}

- (BOOL)containsObject:(id _Nonnull)anObject
{
    __block BOOL result = NO;
    dispatch_sync(self.backgroundQueue, ^{
        result = [self.elements containsObject:anObject];
    });
    return result;
}

- (void)removeObjectsInArray:(NSArray * _Nonnull)otherArray
{
    dispatch_sync(self.backgroundQueue, ^{
        [self.elements removeObjectsInArray:otherArray];
    });
}

- (NSArray * _Nonnull)array
{
    __block NSArray *result = nil;
    dispatch_sync(self.backgroundQueue, ^{
        result = self.elements.array;
    });
    return result;
}

@end
