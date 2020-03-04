//
//  NSDate+StringRepresentation.h
//  Pantomime
//
//  Created by Dirk Zimmermann on 12/04/16.
//  Copyright © 2016 p≡p Security S.A. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDate (StringRepresentation)

- (NSString *)rfc2822String;

/// Creates a string representations in forma IMAP date/time, which is defined as:
/// date-day:                   2DIGIT                                                Day of month
/// date-month:                 [ "Jan" |"Feb" | "Mar" / "Apr"| "May" | "Jun" / "Jul" | "Aug" | "Sep" | "Oct" | "Nov" | "Dec"]
/// date-year:                  4DIGIT
/// zone:                          [+|-]4DIGIT
/// date-time                   "date-day-fixed "-" date-month "-" date-year zone"
/// @note: The date-month MUST use us-EN names for months.
/// @Return: IMAP date/time string representation
- (NSString *)dateTimeString;

@end
