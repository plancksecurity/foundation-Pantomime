//
//  CWThreadSafeArray.m
//  Pantomime
//
//  Created by Dirk Zimmermann on 27/05/16.
//  Copyright © 2016 pEp Security S.A. All rights reserved.
//

#import "CWThreadSafeArray.h"

@interface CWThreadSafeArray ()

@property (nonatomic, strong) NSMutableArray *mutableArray;
@property (nonatomic) dispatch_queue_t backgroundQueue;

@end

@implementation CWThreadSafeArray

- (instancetype _Nullable)init
{
    self = [super init];
    if (self) {
        _backgroundQueue = dispatch_queue_create("ThreadSafeArray", DISPATCH_QUEUE_SERIAL);
        _mutableArray = [[NSMutableArray alloc] init];
    }
    return self;
}

- (instancetype _Nullable)initWithArray:(NSArray * _Nonnull)anArray
{
    self = [self init];
    if (self) {
        _mutableArray = [[NSMutableArray alloc] initWithArray:anArray];
    }
    return  self;
}

- (void)removeAllObjects
{
    dispatch_sync(self.backgroundQueue, ^{
        [self.mutableArray removeAllObjects];
    });
}

- (NSUInteger)count
{
    __block NSUInteger theCount = 0;
    dispatch_sync(self.backgroundQueue, ^{
        theCount = self.mutableArray.count;
    });
    return theCount;
}

- (id)lastObject
{
    __block id obj = nil;
    dispatch_sync(self.backgroundQueue, ^{
        id theLast = [self.mutableArray lastObject];
        if (!theLast) {
            NSLog(@"self.count %lu", (unsigned long) self.count);
            for (id o in self.mutableArray) {
                NSLog(@"Element %@", o);
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
            NSLog(@"There: Trying to add nil!");
        }
        [self.mutableArray addObject:obj];
    });
}

- (id _Nonnull)objectAtIndex:(NSUInteger)index
{
    __block id obj = nil;
    dispatch_sync(self.backgroundQueue, ^{
        obj = [self.mutableArray objectAtIndex:index];
    });
    return obj;
}

- (void)insertObject:(id)anObject atIndex:(NSUInteger)index
{
    dispatch_sync(self.backgroundQueue, ^{
        [self.mutableArray insertObject:anObject atIndex:index];
    });
}

- (void)removeLastObject
{
    dispatch_sync(self.backgroundQueue, ^{
        [self.mutableArray removeLastObject];
    });
}

- (void)addObjectsFromArray:(NSArray * _Nonnull)otherArray
{
    dispatch_sync(self.backgroundQueue, ^{
        [self.mutableArray addObjectsFromArray:otherArray];
    });
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState * _Nonnull)state
                                  objects:(id _Nonnull __unsafe_unretained [])buffer
                                    count:(NSUInteger)len
{
    __block NSUInteger result = 0;
    dispatch_sync(self.backgroundQueue, ^{
        result = [self.mutableArray countByEnumeratingWithState:state objects:buffer count:len];
    });
    return result;
}

- (BOOL)containsObject:(id _Nonnull)anObject
{
    __block BOOL result = NO;
    dispatch_sync(self.backgroundQueue, ^{
        result = [self.mutableArray containsObject:anObject];
    });
    return result;
}

- (void)removeObjectsInArray:(NSArray * _Nonnull)otherArray
{
    dispatch_sync(self.backgroundQueue, ^{
        [self.mutableArray removeObjectsInArray:otherArray];
    });
}

- (NSArray * _Nonnull)array
{
    __block NSArray *result = nil;
    dispatch_sync(self.backgroundQueue, ^{
        result = [[NSArray alloc] initWithArray:self.mutableArray];
    });
    return result;
}

@end