/*
**  CWSMTP.m
**
**  Copyright (c) 2001-2007
**
**  Author: Ludovic Marcotte <ludovic@Sophos.ca>
**
**  This library is free software; you can redistribute it and/or
**  modify it under the terms of the GNU Lesser General Public
**  License as published by the Free Software Foundation; either
**  version 2.1 of the License, or (at your option) any later version.
**  
**  This library is distributed in the hope that it will be useful,
**  but WITHOUT ANY WARRANTY; without even the implied warranty of
**  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
**  Lesser General Public License for more details.
**  
**  You should have received a copy of the GNU Lesser General Public
**  License along with this library; if not, write to the Free Software
**  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
*/

#import "Pantomime/CWSMTP.h"
#import "CWSMTP+Protected.h"

#import "Pantomime/CWConnection.h"
#import "Pantomime/CWConstants.h"
#import "Pantomime/CWInternetAddress.h"
#import "Pantomime/CWMD5.h"
#import "Pantomime/CWMessage.h"
#import "Pantomime/NSData+Extensions.h"

#import <Foundation/NSEnumerator.h>
#import <Foundation/NSNotification.h>

#import "CWConnection.h"
#import "CWThreadSafeArray.h"
#import "CWThreadSafeData.h"

#import "CWService+Protected.h"

// The hostname/domain used to do EHLO/HELO
static NSString *pEpEHLOBase = @"pretty.Easy.privacy";

//
// This function returns the next recipient from the array depending
// if the message is redirected or not.
//
static inline CWInternetAddress *next_recipient(NSMutableArray *theRecipients, BOOL aBOOL)
{
  CWInternetAddress *theAddress;
  NSUInteger i, count;

  count = [theRecipients count];

  for (i = 0; i < count; i++)
    {
      theAddress = [theRecipients objectAtIndex: i];

      if (aBOOL)
	{
	  if ([theAddress type] > 3)
	    {
	      return theAddress;
	    }
	}
      else
	{
	  if ([theAddress type] < 4)
	    {
	      return theAddress;
	    }
	}
    }

  return nil;
}


//
// Private SMTP methods
//
@interface CWSMTP (Private)

- (void) _parseAUTH_CRAM_MD5;
- (void) _parseAUTH_LOGIN;
- (void) _parseAUTH_LOGIN_CHALLENGE;
- (void) _parseAUTH_PLAIN;
- (void) _parseAUTHORIZATION;
- (void) _parseDATA;
- (void) _parseEHLO;
- (void) _parseHELO;
- (void) _parseMAIL;
- (void) _parseNOOP;
- (void) _parseQUIT;
- (void) _parseRCPT;
- (void) _parseRSET;
- (void) _parseServerOutput;

@end


//
//
//
@implementation CWSMTP

//
// initializers
//
- (id) initWithName: (NSString *) theName
               port: (unsigned int) thePort
          transport: (ConnectionTransport)transport
{
    self = [super initWithName: theName  port: thePort transport: transport];

    _sent_recipients = nil;
    _recipients = nil;
    _message = nil;
    _data = nil;
    _max_size = 0;

    _lastCommand = SMTP_AUTHORIZATION;
  
    // We queue our first "command".
    [_queue addObject: AUTORELEASE([[CWSMTPQueueObject alloc] initWithCommand: _lastCommand  arguments: @""])];

    return self;
}


//
//
//
- (void) dealloc
{
  //INFO(NSStringFromClass([self class]), @"SMTP: -dealloc");
  RELEASE(_message);
  RELEASE(_data);
  RELEASE(_recipients);
  RELEASE(_sent_recipients);

  //[super dealloc];
}

#pragma mark - Overriden

//
//
//
- (void) cancelRequest
{
    dispatch_sync(self.serviceQueue, ^{
        [super cancelRequest];
    });
}


//
//
//
- (void) close
{
    dispatch_sync(self.serviceQueue, ^{
        if (_connected) {
            [self sendCommand: SMTP_QUIT  arguments: @"QUIT"];
        }
        [super close];
    });
}


//
// This method sends a RSET SMTP command.
//
- (void) reset
{
    dispatch_sync(self.serviceQueue, ^{
        [self sendCommand: SMTP_RSET  arguments: @"RSET"];
    });
}


//
// This methods reads everything the server sends. Once it judge it has
// read a full response, it calls _parseServerOutput in order to react
// to what we've just received from the server.
// 
//
// RFC2821 rationale:
//
//   An SMTP reply consists of a three digit number (transmitted as three
//   numeric characters) followed by some text unless specified otherwise
//   in this document.  The number is for use by automata to determine
//   what state to enter next; the text is for the human user.  The three
//   digits contain enough encoded information that the SMTP client need
//   not examine the text and may either discard it or pass it on to the
//   user, as appropriate.  Exceptions are as noted elsewhere in this
//   document.  In particular, the 220, 221, 251, 421, and 551 reply codes
//   are associated with message text that must be parsed and interpreted
//   by machines
//
//   (...)
//
//   The format for multiline replies requires that every line, except the
//   last, begin with the reply code, followed immediately by a hyphen,
//   "-" (also known as minus), followed by text.  The last line will
//   begin with the reply code, followed immediately by <SP>, optionally
//   some text, and <CRLF>.  As noted above, servers SHOULD send the <SP>
//   if subsequent text is not sent, but clients MUST be prepared for it
//   to be omitted.
//
//   For example:
//
//      123-First line
//      123-Second line
//      123-234 text beginning with numbers
//      123 The last line
//
//
//  (...)
//
//   ... Only the EHLO, EXPN, and HELP
//   commands are expected to result in multiline replies in normal
//   circumstances, however, multiline replies are allowed for any
//   command.
//
- (void) updateRead
{
    // Intentionally not serialized on serviceQueue. Must never been called directly by clients.
    NSData *aData;
    char *buf;
    NSUInteger count;

    //INFO(NSStringFromClass([self class]), @"IN UPDATE READ");

    [super updateRead];

    while ((aData = [_rbuf dropFirstLine]))
    {
        [_responsesFromServer addObject: aData];

        buf = (char *)[aData bytes];
        count = [aData length];

        // If we got only a response code OR if we're done reading
        // a multiline reply, we parse the output!
        if (count == 3 || (count > 3 && (*(buf+3) != '-')))
        {
            [self _parseServerOutput];
        }
    }
}


//
// This method sends a NOOP SMTP command.
//
- (void) noop
{
    dispatch_sync(self.serviceQueue, ^{
        [self sendCommand: SMTP_NOOP  arguments: @"NOOP"];
    });
}


//
//
//
- (int) reconnect
{
    dispatch_sync(self.serviceQueue, ^{
        [super reconnect];
    });

    return 0; // In case you wonder see reconnect doc: @result Pending.
}


//
//
//
- (void) startTLS
{
    dispatch_sync(self.serviceQueue, ^{
        [self sendCommand: SMTP_STARTTLS  arguments: @"STARTTLS"];
    });
}


//
//
//
- (void) connectInBackgroundAndNotify
{
    dispatch_sync(self.serviceQueue, ^{
        [super connectInBackgroundAndNotify];
    });
}


//
// This method is used to authenticate ourself to the SMTP server.
//
- (void) authenticate: (NSString *) theUsername
             password: (NSString *) thePassword
            mechanism: (NSString *) theMechanism
{
    dispatch_sync(self.serviceQueue, ^{
        ASSIGN(_username, theUsername);
        ASSIGN(_password, thePassword);
        ASSIGN(_mechanism, theMechanism);

        if (!theMechanism)
        {
            AUTHENTICATION_FAILED(_delegate, @"");
        }
        else if ([theMechanism caseInsensitiveCompare: @"PLAIN"] == NSOrderedSame)
        {
            [self sendCommand: SMTP_AUTH_PLAIN  arguments: @"AUTH PLAIN"];
        }
        else if ([theMechanism caseInsensitiveCompare: @"LOGIN"] == NSOrderedSame)
        {
            [self sendCommand: SMTP_AUTH_LOGIN  arguments: @"AUTH LOGIN"];
        }
        else if ([theMechanism caseInsensitiveCompare: @"CRAM-MD5"] == NSOrderedSame)
        {
            [self sendCommand: SMTP_AUTH_CRAM_MD5  arguments: @"AUTH CRAM-MD5"];
        }
        else
        {
            // Unknown / Unsupported mechanism
            AUTHENTICATION_FAILED(_delegate, theMechanism);
        }
    });
}

#pragma mark - CWTransport

//
// To send a message, we need its data value and the recipients at least.
//
// Depending on what was specified using the "set" methods, we initialize
// what we really want and proceed to send the mail.
//
- (void) sendMessage
{
    dispatch_sync(self.serviceQueue, ^{
        NSString *aString;

        if (!_message && !_data)
        {
            [self fail];
            return;
        }
        if (!_recipients && _message)
        {
            ASSIGN(_recipients, [NSMutableArray arrayWithArray: [_message recipients]]);

            if (!_data)
            {
                ASSIGN(_data, [_message dataValue]);
            }
        }
        else if (!_recipients && _data)
        {
            CWMessage *aMessage;

            aMessage = [[CWMessage alloc] initWithData: _data];
            ASSIGN(_message, aMessage);
            ASSIGN(_recipients, [NSMutableArray arrayWithArray: [aMessage recipients]]);

            RELEASE(aMessage);
        }

        DESTROY(_sent_recipients);
        _sent_recipients = [_recipients mutableCopy];

        // We first verify if it's a redirected message
        if ([_message resentFrom])
        {
            _redirected = YES;
            aString = [[_message resentFrom] address];
        }
        else
        {
            _redirected = NO;
            aString = [[_message from] address];
        }

        if (_max_size)
        {
            [self sendCommand: SMTP_MAIL  arguments: @"MAIL FROM:<%@> SIZE=%d", aString, [_data length]];
        }
        else
        {
            [self sendCommand: SMTP_MAIL  arguments: @"MAIL FROM:<%@>", aString];
        }
    });
}


//
//
//
- (void) setMessage: (CWMessage *) theMessage
{
    dispatch_sync(self.serviceQueue, ^{
        DESTROY(_data);
        ASSIGN(_message, theMessage);
    });
}

- (CWMessage *) message
{
    __block CWMessage *returnee = nil;
    dispatch_sync(self.serviceQueue, ^{
        returnee = _message;
    });

    return returnee;
}


//
//
//
- (void) setMessageData: (NSData *) theData
{
    dispatch_sync(self.serviceQueue, ^{
        DESTROY(_message);
        ASSIGN(_data, theData);
    });
}

- (NSData *) messageData
{
    __block NSData *returnee = nil;
    dispatch_sync(self.serviceQueue, ^{
        returnee = _data;
    });

    return returnee;
}


//
//
//
- (void) setRecipients: (NSArray *) theRecipients
{
    dispatch_sync(self.serviceQueue, ^{
        DESTROY(_recipients);

        if (theRecipients)
        {
            ASSIGN(_recipients, [NSMutableArray arrayWithArray: theRecipients]);
        }
    });
}


//
//
//
- (NSArray *) recipients
{
    __block NSArray *returnee = nil;
    dispatch_sync(self.serviceQueue, ^{
        returnee = _recipients;
    });

    return returnee;
}

@end


//
// Private methods
//
@implementation CWSMTP (Private)

- (void) _parseAUTH_CRAM_MD5
{
  NSData *aData;
  
  aData = [_responsesFromServer lastObject];
 
  if ([aData hasCPrefix: "334"])
    {
      NSString *aString;
      CWMD5 *aMD5;
      
      // We trim the "334 ", decode the data using base64 and we keep the challenge phrase
      aData = [[aData subdataFromIndex: 4] decodeBase64];
      aMD5 = [[CWMD5 alloc] initWithData: aData];
      [aMD5 computeDigest];
      
      aString = [NSString stringWithFormat: @"%@ %@", _username, [aMD5 hmacAsStringUsingPassword: _password]];
        [self bulkWriteData:@[[[aString dataUsingEncoding:  _defaultCStringEncoding] encodeBase64WithLineLength: 0],
                                 _crlf]];
      RELEASE(aMD5);
    }
  else if ([aData hasCPrefix: "235"])
    {
      AUTHENTICATION_COMPLETED(_delegate, @"CRAM-MD5");
    }
  else
    {
      AUTHENTICATION_FAILED(_delegate, @"CRAM-MD5");
    }
}


//
//
//
- (void) _parseAUTH_LOGIN
{
  NSData *aData;
  
  aData = [_responsesFromServer lastObject];
  
  if ([aData hasCPrefix: "334"])
    {
      NSString *aString;
      
      aString = [[NSString alloc] initWithData: [[_username dataUsingEncoding: _defaultCStringEncoding] encodeBase64WithLineLength: 0]
						   encoding: _defaultCStringEncoding];
      [self sendCommand: SMTP_AUTH_LOGIN_CHALLENGE  arguments: aString];
      RELEASE(aString);
    }
  else
    {
      AUTHENTICATION_FAILED(_delegate, @"LOGIN");
    }
}


//
// FIXME, rename if needed.
//
- (void) _parseAUTH_LOGIN_CHALLENGE
{
  NSData *aData;
  
  aData = [_responsesFromServer lastObject];
  
  if ([aData hasCPrefix: "334"])
    {
      NSString *aString;
      
      aString = [[NSString alloc] initWithData: [[_password dataUsingEncoding: _defaultCStringEncoding] encodeBase64WithLineLength: 0]
				  encoding: _defaultCStringEncoding];
      
      [self sendCommand: SMTP_AUTH_LOGIN_CHALLENGE  arguments: aString];
      RELEASE(aString);
    }
  else if ([aData hasCPrefix: "235"])
    {
      AUTHENTICATION_COMPLETED(_delegate, @"LOGIN");
    }
  else
    {
        INFO(NSStringFromClass([self class]),
             @"Authentification response: |%@|",
             [aData asciiString]);
        AUTHENTICATION_FAILED(_delegate, @"LOGIN");
    }
}


//
//
//
- (void) _parseAUTH_PLAIN
{
  NSData *aData;
  
  aData = [_responsesFromServer lastObject];

  if ([aData hasCPrefix: "334"])
    {
      NSMutableData *aMutableData;
      NSUInteger len_username, len_password;
      
      len_username = [_username length];
  
      if (!_password)
	{
	  len_password = 0;
	}
      else
	{
	  len_password = [_password length];
	}
      
      // We create our phrase
      aMutableData = [NSMutableData dataWithLength: (len_username + len_password + 2)];
      
      [aMutableData replaceBytesInRange: NSMakeRange(1,len_username)
		    withBytes: [[_username dataUsingEncoding: _defaultCStringEncoding] bytes]];
      
      
      [aMutableData replaceBytesInRange: NSMakeRange(2 + len_username, len_password)
		    withBytes: [[_password dataUsingEncoding:  [NSString defaultCStringEncoding]] bytes]];

        [self bulkWriteData:@[[aMutableData encodeBase64WithLineLength: 0],
                                 _crlf]];
    }
  else if ([aData hasCPrefix: "235"])
    {
      AUTHENTICATION_COMPLETED(_delegate, @"PLAIN");
    }
  else
    {
      AUTHENTICATION_FAILED(_delegate, @"PLAIN");
    }
}


//
//
//
- (void) _parseAUTHORIZATION
{
  NSData *aData;
  
  aData = [_responsesFromServer lastObject];
  
  // 220 <domain> Service ready
  if ([aData hasCPrefix: "220"])
    {
      [self sendCommand: SMTP_EHLO  arguments: [NSString stringWithFormat:@"EHLO %@", pEpEHLOBase]];
    }
  else
    {
      // Handle the fact when a server is loaded and can't handle our requests
      // right away.
#warning FIXME
    }
}


//
//
//
- (void) _parseDATA
{
  NSData *aData;
  
  aData = [_responsesFromServer lastObject];

  // If we can proceed to write the message's data, let's do so.
  if ([aData hasCPrefix: "354"])
    {
      NSMutableData *aMutableData;
      NSRange r1, r2;
      
      // We first replace all occurences of LF by CRLF in the Message's data.
      //
      aMutableData = [[NSMutableData dataWithData: _data] replaceLFWithCRLF];
  
      //
      // According to RFC 2821 section 4.5.2, we must check for the character
      // sequence "<CRLF>.<CRLF>"; any occurrence have its period duplicated
      // to avoid data transparency. 
      //
      r1 = [aMutableData rangeOfCString: "\r\n."];
      
      while (r1.location != NSNotFound)
	{
	  [aMutableData replaceBytesInRange: r1  withBytes: "\r\n.."  length: 4];
	  
	  r1 = [aMutableData rangeOfCString: "\r\n."
			     options: 0 
			     range: NSMakeRange(NSMaxRange(r1)+1, [aMutableData length]-NSMaxRange(r1)-1)];
	}

      //
      // We now look for the Bcc: header. If it is present, we remove it.
      // Some servers, like qmail, do not remove it automatically.
      //
      r1 = [aMutableData rangeOfCString: "\r\n\r\n"];
      r1 = [aMutableData rangeOfCString: "\r\nBcc: "
			 options: 0
			 range: NSMakeRange(0,r1.location-1)];
      
      if (r1.location != NSNotFound)
	{
	  // We search for the first \r\n AFTER the Bcc: header and
	  // replace the whole thing with \r\n.
	  r2 = [aMutableData rangeOfCString: "\r\n"
			     options: 0
			     range: NSMakeRange(NSMaxRange(r1)+1,[aMutableData length]-NSMaxRange(r1)-1)];
	  [aMutableData replaceBytesInRange: NSMakeRange(r1.location, NSMaxRange(r2)-r1.location)
			withBytes: "\r\n"
			length: 2];
    }
        [self bulkWriteData:@[aMutableData,
                                 [NSData dataWithBytes: "\r\n.\r\n"  length: 5]]];
    }
  else if ([aData hasCPrefix: "250"])
    {
      // The data we wrote in the previous call was sucessfully written.
      // We inform the delegate that the mail was sucessfully sent.
      POST_NOTIFICATION(PantomimeMessageSent, self, [NSDictionary dictionaryWithObject: _message  forKey: @"Message"]);
      PERFORM_SELECTOR_2(_delegate, @selector(messageSent:), PantomimeMessageSent, _message, @"Message");
    }
  else
    {
      [self fail];
    }
}


//
//
//
- (void) _parseEHLO
{
  NSData *aData;
  NSUInteger i, count;

  count = [_responsesFromServer count];
  
  for (i = 0; i < count; i++)
    {
      aData = [_responsesFromServer objectAtIndex: i];

      if ([aData hasCPrefix: "250"])
	{
	  // We parse the SMTP service extensions. For now, we support the SIZE
	  // and the AUTH extensions. We ignore the rest.
	  aData = [aData subdataFromIndex: 4];

	  // We add it to our capabilities
	  [_capabilities addObject: AUTORELEASE([[NSString alloc] initWithData: aData  encoding: _defaultCStringEncoding])];

	  // Example of responses:
	  //
	  // AUTH LOGIN
	  // AUTH=PLAIN CRAM-MD5 DIGEST-MD5
	  //
	  if ([aData hasCPrefix: "AUTH"])
	    {
	      NSEnumerator *theEnumerator;
	      id aString;

	      // We chomp the "AUTH " or "AUTH=" part and we decode our
	      // supported mechanisms.
	      theEnumerator = [[[aData subdataFromIndex: 5] componentsSeparatedByCString: " "] objectEnumerator];

	      while ((aString = [theEnumerator nextObject]))
		{
		  aString = [aString asciiString];

		  if (![_supportedMechanisms containsObject: aString])
		    {
		      [_supportedMechanisms addObject: aString];
		    }
		}
	    }
	  //
	  // SIZE size-param
	  // size-param ::= [1*DIGIT]
	  //
	  // See RFC1870 for detailed information.
	  //
	  else if ([aData hasCPrefix: "SIZE"])
	    {
	      NSRange aRange;

	      // We must be careful here. Some broken servers will send only
	      // 250-SIZE
	      // and we don't want to parse an inexistant value.
	      aRange = [aData rangeOfCString: " "];

	      if (aRange.length)
		{
		  _max_size = atoi([[aData subdataFromIndex: aRange.location+1] cString]);
		}
	    }
	}
      else
	{
	  // The server doesn't handle EHLO. We send it
	  // a HELO greeting instead.
	  [self sendCommand: SMTP_HELO  arguments: [NSString stringWithFormat:@"HELO %@", pEpEHLOBase]];
	  break;
	}
    }


#warning FIXME - Inform the delegate if it is ready or not, especially if EHLO failed
  POST_NOTIFICATION(PantomimeServiceInitialized, self, nil);
  PERFORM_SELECTOR_1(_delegate, @selector(serviceInitialized:), PantomimeServiceInitialized);
}


//
//
//
- (void) _parseHELO
{
  // FIXME - Implement. + inform the delegate if it's ready or not.
}


//
// This method parses the result received from the server
// after issuing a "MAIL FROM: <>" command.
//
// If the result is successful, we proceed by sending the first RCPT.
//
- (void) _parseMAIL
{
  NSData *aData;
  
  aData = [_responsesFromServer lastObject];

  if ([aData hasCPrefix: "250"])
    {
      // We write the first recipient while respecting the fact
      // that we are bouncing or not the message.
      POST_NOTIFICATION(PantomimeTransactionInitiationCompleted, self, [NSDictionary dictionaryWithObject: _message  forKey: @"Message"]);
      PERFORM_SELECTOR_1(_delegate, @selector(transactionInitiationCompleted:), PantomimeTransactionInitiationCompleted);

      [self sendCommand: SMTP_RCPT  arguments: @"RCPT TO:<%@>", [next_recipient(_sent_recipients, _redirected) address]];
    }
  else
    {
      if (PERFORM_SELECTOR_1(_delegate, @selector(transactionInitiationFailed:), PantomimeTransactionInitiationFailed))
	{
	  POST_NOTIFICATION(PantomimeTransactionInitiationFailed, self, [NSDictionary dictionaryWithObject: _message  forKey: @"Message"]);
	}
      else
	{
	  [self fail];
	}
    }
}


//
//
//
- (void) _parseNOOP
{
  // Do what?
}


//
//
//
- (void) _parseQUIT
{
  NSData *aData;
  
  aData = [_responsesFromServer lastObject];
  
  if ([aData hasCPrefix: "221"])
    {
      // Do anything special here?
    }

  [super close];
}


//
// This method is invoked everytime we sent a recipient to the
// server using the RCPT command.
//
// If it was successful, this command sends the next one, if any
// by first removing the previously sent one from _recipients.
//
- (void) _parseRCPT
{
  NSData *aData;
  
  aData = [_responsesFromServer lastObject];

  if ([aData hasCPrefix: "250"])
    {
      CWInternetAddress *theAddress;

      theAddress = next_recipient(_sent_recipients, _redirected);

      if (theAddress)
	{
	  [_sent_recipients removeObject: theAddress];
	  
	  theAddress = next_recipient(_sent_recipients, _redirected);
	  
	  if (theAddress)
	    {
	      [self sendCommand: SMTP_RCPT  arguments: @"RCPT TO:<%@>", [theAddress address]];
	      return;
	    }
	}

      // We are done writing the recipients, we now write the content
      // of the message.
      POST_NOTIFICATION(PantomimeRecipientIdentificationCompleted, self, [NSDictionary dictionaryWithObject: _recipients  forKey: @"Recipients"]);
      PERFORM_SELECTOR_2(_delegate, @selector(recipientIdentificationCompleted:), PantomimeRecipientIdentificationCompleted, _recipients, @"Recipients");
      [self sendCommand: SMTP_DATA  arguments: @"DATA"];
    }
  else
    {
#warning also send the invalid recipient in perform selector and when posting the notification
      if (PERFORM_SELECTOR_1(_delegate, @selector(recipientIdentificationFailed:), PantomimeRecipientIdentificationFailed))
	{
	  POST_NOTIFICATION(PantomimeRecipientIdentificationFailed, self, [NSDictionary dictionaryWithObject: _recipients  forKey: @"Recipients"]);
	}
      else
	{
	  [self fail];
	}
    }
}


//
//
//
- (void) _parseRSET
{
  NSData *aData;
  
  aData = [_responsesFromServer lastObject];
  
  if ([aData hasCPrefix: "250"])
    {
      POST_NOTIFICATION(PantomimeTransactionResetCompleted, self, nil);
      PERFORM_SELECTOR_1(_delegate, @selector(transactionResetCompleted:), PantomimeTransactionResetCompleted);
    }
  else
    {
      POST_NOTIFICATION(PantomimeTransactionResetFailed, self, nil);
      PERFORM_SELECTOR_1(_delegate, @selector(transactionResetFailed:), PantomimeTransactionResetFailed);
    }
}


//
//
//
- (void) _parseSTARTTLS
{
  NSData *aData;

  aData = [_responsesFromServer lastObject];
  
  if ([aData hasCPrefix: "220"])
    {          
      // We first activate SSL.
      [(id<CWConnection>) _connection startTLS];

      // We now forget about the initial negotiated state; see RFC2487 for more details,
      [_supportedMechanisms removeAllObjects];
      [self sendCommand: SMTP_EHLO  arguments: [NSString stringWithFormat:@"EHLO %@", pEpEHLOBase]];
    }
  else
    {
      // The server probably doesn't support TLS. We inform the delegate that the transaction initiation
      // failed or that the message wasn't sent.
      if (PERFORM_SELECTOR_1(_delegate, @selector(transactionInitiationFailed:), PantomimeTransactionInitiationFailed))
	{
	  POST_NOTIFICATION(PantomimeTransactionInitiationFailed, self, [NSDictionary dictionaryWithObject: _message  forKey: @"Message"]);
	}
      else
	{
	  [self fail];
	}
    }
}


//
//
//
- (void) _parseServerOutput
{
  NSData *aData;

  if (![_responsesFromServer count])
    {
      return;
    }

  // We read only the first response. The _parseXYZ methods
  // will handle multiline responses.
  aData = [_responsesFromServer objectAtIndex: 0];

  if ([aData hasCPrefix: "421"])
    {
      // FIXME: - lost connection
      //INFO(NSStringFromClass([self class]), @"LOST CONNECTION TO THE SERVER");
      [super close];
    }
  else
    {
      switch (_lastCommand)
	{
	case SMTP_AUTH_CRAM_MD5:
	  [self _parseAUTH_CRAM_MD5];
	  break;

	case SMTP_AUTH_LOGIN:
	  [self _parseAUTH_LOGIN];
	  break;
	  
	case SMTP_AUTH_LOGIN_CHALLENGE:
	  [self _parseAUTH_LOGIN_CHALLENGE];
	  break;

	case SMTP_AUTH_PLAIN:
	  [self _parseAUTH_PLAIN];
	  break;

	case SMTP_DATA:
	  [self _parseDATA];
	  break;

	case SMTP_EHLO:
	  [self _parseEHLO];
	  break;
	  
	case SMTP_HELO:
	  [self _parseHELO];
	  break;

	case SMTP_MAIL:
	  [self _parseMAIL];
	  break;

	case SMTP_NOOP:
	  [self _parseNOOP];
	  break;

	case SMTP_QUIT:
	  [self _parseQUIT];
	  break;

	case SMTP_RCPT:
	  [self _parseRCPT];
	  break;

	case SMTP_RSET:
	  [self _parseRSET];
	  break;

	case SMTP_STARTTLS:
	  [self _parseSTARTTLS];
	  break;
	  
	case SMTP_AUTHORIZATION:
	  [self _parseAUTHORIZATION];
	  break;

	default:
	  break;
	  // FIXME
	}
    }
  
  // We are done parsing this entry...
  [_responsesFromServer removeAllObjects];

  // We remove the last object of the queue....
  if ([_queue lastObject])
    {
      [_queue removeLastObject];
    }

  [self sendCommand: SMTP_EMPTY_QUEUE  arguments: @""];
}

@end
