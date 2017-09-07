//
//  CWSMTP+Protected.h
//  Pantomime
//
//  Created by Andreas Buff on 06.09.17.
//  Copyright © 2017 pEp Security S.A. All rights reserved.
//

#import "CWSMTP.h"

@interface CWSMTP (Protected)

/*!
 @method lastResponse
 @discussion This method is used to obtain the last response
 received from the SMTP server. If the server
 sent a multi-line response, only the last line
 will be returned.
 @result The last response in its complete form, nil if no
 response was read.
 */
- (NSData *) lastResponse;

/*!
 @method lastResponseCode
 @discussion This method is used to obtain the last response code
 received from the SMTP server. If the server
 sent a multi-line response, only the code of the
 last line will be returned.
 @result The last response code in its complete form, 0 if
 no response was read.
 */
- (int) lastResponseCode;

/*!
 @method sendCommand: arguments: ...
 @discussion This method is used to send commands to the SMTP server.
 Normally, you should not call this method directly.
 @param theCommand The SMTP command to send.
 @param theFormat The format defining the variable arguments list.
 */
- (void) sendCommand: (SMTPCommand) theCommand  arguments: (NSString *) theFormat, ...;



- (void) fail;

@end


//
//
//
@interface CWSMTPQueueObject : NSObject
{
@public
    SMTPCommand command;
    NSString *arguments;
}
- (id) initWithCommand: (SMTPCommand) theCommand
             arguments: (NSString *) theArguments;
@end
