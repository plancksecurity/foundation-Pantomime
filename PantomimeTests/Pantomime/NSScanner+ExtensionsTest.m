//
//  NSScanner+ExtensionsTest.m
//  PantomimeTests
//
//  Created by Andreas Buff on 19.04.18.
//  Copyright © 2018 pEp Security S.A. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "NSScanner+Extensions.h"

@interface NSScanner_ExtensionsTest : XCTestCase
@property (nonatomic) NSDictionary *testInputs;
@end

@implementation NSScanner_ExtensionsTest

- (void)setUp {
    [super setUp];
    self.testInputs = @{/*@"* SEARCH 1 4 59 81": @[@1, @4, @59, @81],
                         @"* SEARCH": @[],
                         @"* 5 FETCH (UID 905)": @[@905],*/
                         @"0A34": @[@0, @34]/*,
                        @"ABCD": @[]*/};
}

//IOS-1057
- (void)testScanUnsignedInt
{
    for (int i = 0; i < self.testInputs.count; ++i) {
        NSString *testee = self.testInputs.allKeys[i];
        NSMutableArray *results = [NSMutableArray new];
        NSUInteger result;
        NSScanner *scanner = [[NSScanner alloc] initWithString: testee];
        while (![scanner isAtEnd]) {
            [scanner scanUnsignedInt: &result];
            [results addObject: [NSNumber numberWithInteger: result]];
        }
        for (NSNumber *expected in self.testInputs.allValues[i]) {
            XCTAssertTrue([results containsObject:expected]);
        }
        NSLog(@"testee: %@ : results: %@", testee, results);
    }
}

@end
