//
//  CWSMTP+Protected.m
//  Pantomime
//
//  Created by Andreas Buff on 06.09.17.
//  Copyright © 2017 pEp Security S.A. All rights reserved.
//

#import "CWSMTP+Protected.h"
#import "CWService+Protected.h"

#import <PantomimeFramework/CWMessage.h>
#import "CWThreadSafeArray.h"

#import "Pantomime/CWLogger.h"
#import <PantomimeFramework/NSData+Extensions.h>

@implementation CWSMTP (Protected)

//
// This method returns the last response obtained from the SMTP
// server. If the last command issued a multiline response, it'll return the
// last text response and none of the previous ones.
//
- (NSData *) lastResponse
{
    return [_responsesFromServer lastObject];
}


//
// Same as -lastResponse except it does return only the response code.
//
- (int) lastResponseCode
{
    if ([_responsesFromServer count] > 0)
    {
        return atoi([[[_responsesFromServer lastObject] subdataToIndex: 3] cString]);
    }

    return 0;
}


//
// This method sends a SMTP command to the server.
//
// It automatically adds the trailing CRLF to every command.
//
// RFC2821:
//
//   The SMTP commands define the mail transfer or the mail system
//   function requested by the user.  SMTP commands are character strings
//   terminated by <CRLF>.  The commands themselves are alphabetic
//   characters terminated by <SP> if parameters follow and <CRLF>
//   otherwise.  (In the interest of improved interoperability, SMTP
//   receivers are encouraged to tolerate trailing white space before the
//   terminating <CRLF>.)  The syntax of the local part of a mailbox must
//   conform to receiver site conventions and the syntax specified in
//   section 4.1.2.  The SMTP commands are discussed below.  The SMTP
//   replies are discussed in section 4.2.
//
// The following list of commands is supported:
//
// - EHLO / HELO
// - MAIL
// - RCPT
// - DATA
// - RSET
// - QUIT
//
// Unimplemented commands:
//
// - VRFY
// - EXPN
// - HELP
// - NOOP
//
- (void) sendCommand:(SMTPCommand)theCommand  arguments:(NSString *)theFormat, ...
{
    // If two calls to this method happen concurrently, one might empty the queue the other is
    // currenly using (causes |SENDING null|).
    @synchronized(self) {
        CWSMTPQueueObject *aQueueObject;

        if (theCommand == SMTP_EMPTY_QUEUE) {
            if ([_queue count]) {
                // We dequeue the first inserted command from the queue.
                aQueueObject = [_queue lastObject];
                if (!aQueueObject) {
                    INFO("_queue has %lu objects", (unsigned long) _queue.count);
                    for (NSObject *obj in _queue) {
                        INFO("obj %@", obj);
                    }
                    INFO("aQueueObject nil");
                }
            } else {
                // The queue is empty, we have nothing more to do...
                return;
            }
        } else {
            va_list args;
            va_start(args, theFormat);

            NSString *aString = [[NSString alloc] initWithFormat: theFormat  arguments: args];
            aQueueObject = [[CWSMTPQueueObject alloc] initWithCommand: theCommand
                                                            arguments: aString];
            [_queue insertObject: aQueueObject  atIndex: 0];

            // If we had queued commands, we return since we'll eventually
            // dequeue them one by one. Otherwise, we run it immediately.
            if ([_queue count] > 1) {
                return;
            }
        }

        if (aQueueObject) {
            BOOL isPrivate = NO;
            if ((aQueueObject->command == SMTP_AUTH_CRAM_MD5 ||
                 aQueueObject->command ==  SMTP_AUTH_LOGIN ||
                 aQueueObject->command == SMTP_AUTH_LOGIN_CHALLENGE ||
                 aQueueObject->command == SMTP_AUTH_PLAIN) &&
                ![aQueueObject->arguments hasPrefix:@"AUTH"]) {
                isPrivate = YES;
            }
            if (isPrivate) {
                INFO("Sending private data |*******|");
            } else {
                INFO("Sending |%@|", aQueueObject->arguments);
            }
            _lastCommand = aQueueObject->command;
            [self bulkWriteData:@[[aQueueObject->arguments
                                   dataUsingEncoding: _defaultCStringEncoding],
                                  _crlf]];
        } else {
            INFO("Sending with nil queue object");
        }
    }
}


//
//
//
- (void) fail
{
    if (_message) {
        PERFORM_SELECTOR_2(_delegate, @selector(messageNotSent:),
                           PantomimeMessageNotSent,
                           _message, @"Message");
    }
    else {
        PERFORM_SELECTOR_1(_delegate, @selector(messageNotSent:), PantomimeMessageNotSent);
    }
}

@end


@implementation CWSMTPQueueObject


//
//
//
- (id) initWithCommand: (SMTPCommand) theCommand
             arguments: (NSString *) theArguments
{
    self = [super init];
    command = theCommand;
    ASSIGN(arguments, theArguments);
    return self;
}


//
//
//
- (void) dealloc
{
    RELEASE(arguments);
    //[super dealloc];
}

@end
