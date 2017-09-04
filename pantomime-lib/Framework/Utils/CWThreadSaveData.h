//
//  CWThreadSaveData.h
//  Pantomime
//
//  Created by Andreas Buff on 04.09.17.
//  Copyright © 2017 pEp Security S.A. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CWThreadSaveData : NSObject

- (instancetype _Nullable)init;

/**
 Initializes a data object with the contents of another data object.

 @param data data to initialize the new object with
 @return  object initialized with the contents data
 */
- (instancetype _Nullable)initWithData:(NSData *)data;

/**
 Creates and returns a data object containing a given number of bytes copied from a given buffer.

 @param bytes data for the new object.
 @param length The number of bytes to copy from bytes. This value must not exceed the length of bytes.
 @return A data object containing length bytes copied from the buffer bytes.
 */
- (instancetype _Nullable)initWithBytes:(char*)bytes length:(NSUInteger)length;

/**
 @return The number of bytes contained by the object
 */
- (NSUInteger)length;

/**
 Removes all data so the esulting length is zero.
 */
- (void)reset;

/**
 Removes a given number of bytes from the beginning of the inner byte array.

 @param numBytes number of bytes to remove
 */
- (void)truncateLeadingBytes:(NSUInteger)numBytes;

/**
 @return a copy of the inner byte array.
 */
- (const char*)copyOfBytes;

/**
 @discussion This method is used to obtain the subdata to <i>index</i>
 from the receiver. The byte at <i>index</i> is not included in
 returned NSData instance.
 @param index The index used to get the subdata to.
 @result The subdata.
 */
- (NSData *)subdataToIndex:(NSUInteger)index;

- (void)appendData:(NSData *)data;

/**
 This function splits lines by CRLF, returns the first one found and removes it from the internal data store.
 @discussion Useful for server responses that are CRLF terminated (for instance IMAP, POP3 and SMTP servers)
 @result A line as a NSData instance, nil if no line was splitted.
 */
- (NSData *)dropFirstLine;

@end

NS_ASSUME_NONNULL_END
