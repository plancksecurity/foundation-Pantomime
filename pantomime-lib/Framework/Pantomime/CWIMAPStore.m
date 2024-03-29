/*
 **  CWIMAPStore.m
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

#import "CWIMAPStore+Protected.h"

#import <PlanckToolboxForExtensions/PEPLogger.h>
#import "CWConstants.h"
#import "CWFlags.h"
#import "Pantomime/CWFolderInformation.h"
#import "CWIMAPFolder.h"
#import "CWIMAPMessage.h"
#import "Pantomime/CWMD5.h"
#import "CWMIMEUtility.h"
#import "Pantomime/CWURLName.h"
#import "NSData+Extensions.h"
#import "Pantomime/NSScanner+Extensions.h"
#import "Pantomime/NSString+Extensions.h"


#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSCharacterSet.h>
#import <Foundation/NSException.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSPathUtilities.h>
#import <Foundation/NSScanner.h>
#import <Foundation/NSValue.h>

#import "CWIMAPCacheManager.h"
#import "CWThreadSafeArray.h"
#import "CWThreadSafeData.h"

#import "NSDate+StringRepresentation.h"

#import <ctype.h>
#import <stdio.h>

#import "CWOAuthUtils.h"
#import "CWService+Protected.h"
#import "CWIMAPFolder+CWProtected.h"

//
// This C function is used to verify if a line (specified in
// "buf", with length "c") has a literal. If it does, the
// value of the literal is returned.
//
// "0" means no literal.
//
static inline int has_literal(char *buf, NSUInteger c)
{
    char *s;

    if (c == 0 || *buf != '*') return 0;

    s = buf+c-1;

    if (*s == '}')
    {
        int value, d;

        value = 0;
        d = 1;
        s--;

        while (isdigit((int)(unsigned char)*s))
        {
            value += ((*s-48) * d);
            d *= 10;
            s--;
        }

        //LogInfo(@"LITERAL = %d", value);

        return value;
    }

    return 0;
}

@interface CWIMAPStore ()

/**
 Regular expression for extracting the UID from a FETCH response.
 */
@property (strong, nonatomic, nonnull) NSRegularExpression *uidRegex;

@end

//
// Private methods
//
@interface CWIMAPStore (Private)

- (void) _parseAUTHENTICATE_CRAM_MD5;
- (void) _parseAUTHENTICATE_LOGIN;
- (void) _parseBAD;
- (void) _parseBYE;
- (void) _parseCAPABILITY;
- (void) _parseEXISTS;
- (void) _parseEXPUNGE;
- (void) _parseFETCH_UIDS;
- (void) _parseFETCH: (NSInteger) theMSN;
- (void) _parseLIST;
- (void) _parseLSUB;
- (void) _parseNO;
- (void) _parseNOOP;
- (void) _parseOK;
- (void) _parseRECENT;
- (void) _parseSEARCH;
- (void) _parseSEARCH_NewMails;
- (void) _parseSEARCH_CACHE;
- (void) _parseSELECT;
- (void) _parseSTATUS;
- (void) _parseSTARTTLS;
- (void) _parseUIDVALIDITY: (const char *) theString;
- (void) _restoreQueue;

@end

//
//
//
@implementation CWIMAPStore

//
//
//
+ (BOOL)accessInstanceVariablesDirectly
{
    return NO;
}


//
//
//
- (instancetype) initWithName: (NSString *) theName
                         port: (unsigned int) thePort
                    transport: (ConnectionTransport)transport
            clientCertificate: (SecIdentityRef _Nullable)clientCertificate
{
    if (thePort == 0) thePort = 143;

    self = [super initWithName:theName
                          port:thePort
                     transport:transport
             clientCertificate:clientCertificate];

    LogInfo(@"CWIMAPStore.init %@", self);

    _folderSeparator = 0;
    _selectedFolder = nil;
    _tag = 1;

    _folders = [[NSMutableDictionary alloc] init];
    _openFolders = [[NSMutableDictionary alloc] init];
    _subscribedFolders = [[NSMutableArray alloc] init];
    _folderStatus = [[NSMutableDictionary alloc] init];

    _lastCommand = IMAP_AUTHORIZATION;
    _currentQueueObject = nil;

    NSError *error;
    _uidRegex = [NSRegularExpression
                 regularExpressionWithPattern:@".*UID (\\d+).*"
                 options: 0 error: &error];
    assert(error == nil);

    return self;
}


//
//
//
- (void) dealloc
{
    LogInfo(@"dealloc %@", self);
    RELEASE(_folders);
    RELEASE(_folderStatus);
    RELEASE(_openFolders);
    RELEASE(_subscribedFolders);
    //[super dealloc];
}


//
//
//
- (void)exitIDLE
{
    dispatch_sync(self.serviceQueue, ^{
        if (self.lastCommand == IMAP_IDLE) {
            _lastCommand = IMAP_IDLE_DONE;
            [self writeData: [[NSData alloc] initWithBytes: "DONE\r\n"  length: 6]];
        }
    });
}


//
//
//
- (void) sendCommand: (IMAPCommand) theCommand  info: (NSDictionary * _Nullable) theInfo
              string:(NSString * _Nonnull)theString
{
    dispatch_sync(self.serviceQueue, ^{
        [self sendCommandInternal:theCommand info:theInfo string:theString];
    });
}


//
//
//
- (NSArray *) supportedMechanisms
{
    __block NSArray *returnee = nil;
    __weak typeof(self) weakSelf = self;
    dispatch_sync(self.serviceQueue, ^{
        typeof(self) strongSelf = weakSelf;
        NSMutableArray *aMutableArray;
        NSString *aString;
        NSUInteger i, count;;

        aMutableArray = [NSMutableArray array];
        count = [strongSelf->_capabilities count];

        for (i = 0; i < count; i++)
        {
            aString = [strongSelf->_capabilities objectAtIndex: i];

            if ([aString hasCaseInsensitivePrefix: @"AUTH="])
            {
                [aMutableArray addObject: [aString substringFromIndex: 5]];
            }
        }
        
        returnee =  aMutableArray;
    });
    
    return returnee;
}


//
//
//
////! VERIFY FOR NoSelect
- (CWIMAPFolder *) folderForName: (NSString *) theName
                            mode: (PantomimeFolderMode) theMode
               updateExistsCount: (BOOL)updateExistsCount
{
    __block CWIMAPFolder *returnee = nil;
    dispatch_sync(self.serviceQueue, ^{
        returnee = [self folderForNameInternal:theName
                                          mode:theMode
                             updateExistsCount:updateExistsCount];
    });

    return returnee;
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
    __weak typeof(self) weakSelf = self;
    dispatch_sync(self.serviceQueue, ^{
        typeof(self) strongSelf = weakSelf;
        // ignore all subsequent messages from the servers
        strongSelf->_delegate = nil;

        [strongSelf->_openFolders removeAllObjects];

        if (strongSelf->_connected) {
            [strongSelf sendCommand: IMAP_LOGOUT  info: nil  arguments: @"LOGOUT"];
        }
        [super close]; 
    });
}


/**
 When this method is called, we are receiving bytes
 from the _lastCommand.

 Rationale:

 This command accumulates the responses (split into lines)
 from the server in _responsesFromServer.

 It will NOT add untagged reponses but rather process them right-away.

 If it's receiving a FETCH response, it will NOT verify for
 tag line ('0123 OK', '0123 BAD', '0123 NO') for the duration
 of reading the literal length. For example, if we got {400},
 we will not consider a '0123 OK' response if we read less
 than 400 bytes. This prevent us from reading a '0123 OK' that
 could occur in a message.
 */
- (void) updateRead
{
        NSData *aData;

        NSUInteger i, count;
        char *buf;

        [super updateRead];

        //LogInfo(@"_rbul len == %d |%@|", [_rbuf length], [_rbuf asciiString]);

        if (![_rbuf length]) return;

        while ((aData = [_rbuf dropFirstLine]))
        {
            //LogInfo(@"aLine = |%@|", [aData asciiString]);
            buf = (char *)[aData bytes];
            count = [aData length];

            // If we are reading a literal, do so.
            if (self.currentQueueObject && self.currentQueueObject.literal)
            {
                self.currentQueueObject.literal -= (int) (count+2);
                //LogInfo(@"literal = %d, count = %d", self.currentQueueObject.literal, count);

                if (self.currentQueueObject.literal < 0)
                {
                    int x;

                    x = -2-self.currentQueueObject.literal;
                    [[self.currentQueueObject.info objectForKey: @"NSData"] appendData: [aData subdataToIndex: x]];
                    [_responsesFromServer addObject: [aData subdataFromIndex: x]];
                    //LogInfo(@"orig = |%@|, chooped = |%@| |%@|", [aData asciiString], [[aData subdataToIndex: x] asciiString], [[aData subdataFromIndex: x] asciiString]);
                }
                else
                {
                    [[self.currentQueueObject.info objectForKey: @"NSData"] appendData: aData];
                }

                // We are done reading a literal. Let's read again
                // to see if we got a full response.
                if (self.currentQueueObject.literal <= 0)
                {
                    //LogInfo(@"DONE ACCUMULATING LITTERAL!\nread = |%@|", [[self.currentQueueObject.info objectForKey: @"NSData"] asciiString]);
                    //
                    // Let's see, if we can, what does the next line contain. If we got
                    // something, we add this to the remaining _responsesFromServer
                    // and we are ready to parse that response (_responsesFromServer + bytes of literal).
                    //
                    // If it's nil, that's because we have nothing to read. In that case, just loop
                    // and call -updateRead in order to read the rest of the response.
                    //
                    // We must also be careful about what we read. Microsoft Exchange sometimes send us
                    // stuff like this:
                    //
                    // * 5 FETCH (BODY[TEXT] {1175}
                    // <!DOCTYPE HTML ...
                    // ...
                    // </HTML> UID 5)
                    // 0010 OK FETCH completed.
                    //
                    // The "</HTML> UID 5)" line will result in a _negative_ literal. Which we
                    // handle well here and just a couple of lines above this one.
                    //
                    if (self.currentQueueObject.literal < 0)
                    {
                        self.currentQueueObject.literal = 0;
                    }
                    else
                    {
                        // We MUST wait until we are done reading our full
                        // FETCH response. _rbuf could end immediately at the
                        // end of our literal response and we need to call
                        // [super updateRead] to get more bytes from the socket
                        // in order to read the rest (")" or " UID 123)" for example).
                        while (!(aData = [_rbuf dropFirstLine]))
                        {
                            //SLog(@"NOTHING TO READ! WAITING...");
                            [super updateRead];
                        }
                        [_responsesFromServer addObject: aData];
                    }

                    //
                    // Let's rollback in what are processing/read in order to
                    // reparse our initial response. It's if it's FETCH response,
                    // the literal will now be 0 so the parsing of this response
                    // will occur.
                    //
                    aData = [_responsesFromServer objectAtIndex: 0];
                    buf = (char *)[aData bytes];
                    count = [aData length];
                }
                else
                {
                    //LogInfo(@"Accumulating... %d remaining...", self.currentQueueObject.literal);
                    //
                    // We are still accumulating bytes of the literal. Once we have appended
                    // our CRLF, we just continue the loop since there's no need to try to
                    // parse anything, as we don't have the complete response yet.
                    //
                    [[self.currentQueueObject.info objectForKey: @"NSData"] appendData: _crlf];
                    continue;
                }
            }
            else
            {
                //LogInfo(@"aLine = |%@|", [aData asciiString]);
                [_responsesFromServer addObject: aData];

                if (self.currentQueueObject && (self.currentQueueObject.literal = has_literal(buf, count)))
                {
                    //LogInfo(@"literal = %d", self.currentQueueObject.literal);
                    [self.currentQueueObject.info setObject: [NSMutableData dataWithCapacity: self.currentQueueObject.literal]
                                                     forKey: @"NSData"];
                }
            }

            // Now search for the position of the first space in our response.
            i = 0;
            while (i < count && *buf != ' ')
            {
                buf++; i++;
            }

            //LogInfo(@"i = %d  count = %d", i, count);

            //
            // We got an untagged response or a command continuation request.
            //
            if (i == 1)
            {
                NSInteger d, j, msn, len;
                BOOL b;

                //
                // We verify if we received a command continuation request.
                // This response is used in the AUTHENTICATE command or
                // in any argument to the command is a literal. In the current
                // code, the only command which has a literal argument is
                // the APPEND command. We must NOT use "break;" at the very
                // end of this block since we could read a line in a mail
                // that begins with a '+'.
                //
                if (*(buf-i) == '+')
                {
                    if (self.currentQueueObject && _lastCommand == IMAP_APPEND)
                    {
                        [self bulkWriteData:@[[self.currentQueueObject.info objectForKey: @"NSDataToAppend"],
                                              _crlf]];
                        break;
                    }
                    else if (_lastCommand == IMAP_AUTHENTICATE_CRAM_MD5)
                    {
                        [self _parseAUTHENTICATE_CRAM_MD5];
                        break;
                    }
                    else if (_lastCommand == IMAP_AUTHENTICATE_LOGIN)
                    {
                        [self _parseAUTHENTICATE_LOGIN];
                        break;
                    }

                    // IMAP_AUTHENTICATE_XOAUTH2 answers with OK response in case of success.
                    // In case case of failure a JSON containing the status is returned, no BAD or NO
                    // response.
                    //
                    // Example success response from gmail:
                    // "0002 OK Thats all she wrote! o3mb34104947ljc"
                    //
                    // Example failure response from gmail:
                    // + eyJzdGF0dXMiOiI0MDAiLCJzY2hlbWVzIjoiQmVhcmVyIiwic2NvcGUiOiJodHRwczovL21haWwuZ29vZ2xlLmNvbS8ifQ==
                    // decoded:
                    // {"status":"400","schemes":"Bearer","scope":"https://mail.google.com/"}
                    else if (_lastCommand == IMAP_AUTHENTICATE_XOAUTH2)
                    {
                        // We ignore the status contained in the response.
                        // This if clause is reached only in failure case.
                        AUTHENTICATION_FAILED(_delegate, _mechanism);
                        break;
                    }

                    else if (self.currentQueueObject && _lastCommand == IMAP_LOGIN)
                    {
                        //LogInfo(@"writing password |%s|", [[self.currentQueueObject.info objectForKey: @"Password"] cString]);
                        [self bulkWriteData:@[[self.currentQueueObject.info objectForKey: @"Password"],
                                              _crlf]];
                        break;
                    } else if (_lastCommand == IMAP_IDLE) {
                        LogInfo(@"entering IDLE");
                        PERFORM_SELECTOR_1(_delegate, @selector(idleEntered:), PantomimeIdleEntered);
                    }
                }

                msn = 0; b = YES; d = 1;
                j = i+1; buf++;

                // Let's see if we can read a MSN
                while (j < count && *buf != ' ')
                {
                    if (!isdigit((int)(unsigned char)*buf)) b = NO;
                    buf++; j++;
                }

                //LogInfo(@"j = %d, b = %d", j, b);

                //
                // The token following our "*" is all-digit. Let's
                // decode the MSN and get the kind of response.
                //
                // We will also read the untagged responses we get
                // when SELECT'ing a mailbox ("* 4 EXISTS" for example).
                //
                // We parse those results but we ignore the "MSN" since
                // it bears no relation to an actual MSN.
                //
                if (b)
                {
                    NSInteger k;

                    k = j;

                    // We compute the MSN
                    while (k > i+1)
                    {
                        buf--; k--;
                        //LogInfo(@"msn c = %c", *buf);
                        msn += ((*buf-48) * d);
                        d *= 10;
                    }

                    //LogInfo(@"Done computing the msn = %d  k = %d", msn, k);

                    // We now get what kind of response we read (FETCH, etc?)
                    buf += (j-i);
                    k = j+1;

                    while (k < count && isalpha((int)(unsigned char)*buf))
                    {
                        //LogInfo(@"response after c = %c", *buf);
                        buf++; k++;
                    }

                    //LogInfo(@"Done reading response: i = %d  j = %d  k = %d", i, j, k);

                    buf = buf-k+j+1;
                    len = k-j-1;
                }
                //
                // It's NOT all-digit.
                //
                else
                {
                    buf = buf-j+i+1;
                    len = j-i-1;
                }

                //NSData *foo;
                //foo = [NSData dataWithBytes: buf  length: len];
                //LogInfo(@"DONE!!! foo after * = |%@| b = %d, msn = %d", [foo asciiString], b, msn);
                //LogInfo(@"len = %d", len);

                //
                // We got an untagged OK response. We handle only the one used in the IMAP authorization
                // state and ignore the ones required during a SELECT command (like OK [UNSEEN <n>]).
                //
                if (len && strncasecmp("OK", buf, 2) == 0 && _lastCommand == IMAP_AUTHORIZATION)
                {
                    [self _parseOK];
                }
                //
                // We got a BAD response without sequence number.
                // Example: "* BAD internal server error"
                // Stop parsing. _parseBAD is responsable for handling it.
                //
                else if (len && strncasecmp("BAD", buf, 3) == 0)
                {
                    [self _parseBAD];
                }
                //
                // We check if we got disconnected from the IMAP server.
                // If it's the case, we invoke -reconnect.
                //
                else if (len && strncasecmp("BYE", buf, 3) == 0)
                {
                    [self _parseBYE];
                }
                //
                //
                //
                else if (len && strncasecmp("LIST", buf, 4) == 0)
                {
                    [self _parseLIST];
                }
                //
                //
                //
                else if (len && strncasecmp("LSUB", buf, 4) == 0)
                {
                    [self _parseLSUB];
                }
                //
                // We got a FETCH response and we are done reading all
                // bytes specified by our literal. We also handle
                // untagged responses coming AFTER a tagged response,
                // like that:
                //
                // 000c UID FETCH 3071053:3071053 BODY[TEXT]
                // * 1 FETCH (UID 3071053 BODY[TEXT] {859}
                // f00 bar zarb
                // ..
                // )
                // 000c OK UID FETCH completed
                // * 1 FETCH (FLAGS (\Seen))
                //
                // Responses like that must be carefully handled since
                // self.currentQueueObject would nil after getting the
                // tagged response.
                //
                else if (len && strncasecmp("FETCH", buf, 5) == 0 &&
                         (!self.currentQueueObject || (self.currentQueueObject && self.currentQueueObject.literal == 0)))
                {
                    switch (_lastCommand)
                    {
                        case IMAP_UID_FETCH_UIDS:
                            [self _parseFETCH_UIDS];
                            break;
                        default:
                            [self _parseFETCH: msn];
                    }
                }
                //
                //
                //
                else if (len && strncasecmp("EXISTS", buf, 6) == 0)
                {
                    [self _parseEXISTS];
                    [_responsesFromServer removeLastObject];
                }
                //
                //
                //
                else if (len && strncasecmp("RECENT", buf, 6) == 0)
                {
                    [self _parseRECENT];
                    [_responsesFromServer removeLastObject];
                }
                //
                //
                //
                else if (len && strncasecmp("SEARCH", buf, 6) == 0)
                {
                    switch (_lastCommand)
                    {
                        case IMAP_UID_SEARCH:
                        case IMAP_UID_SEARCH_ANSWERED:
                        case IMAP_UID_SEARCH_FLAGGED:
                        case IMAP_UID_SEARCH_UNSEEN:
                            [self _parseSEARCH_CACHE];
                            break;
                        case IMAP_SEARCH_NEW_MAILS:
                            [self _parseSEARCH_NewMails];
                            break;
                        default:
                            [self _parseSEARCH];
                    }
                }
                //
                //
                //
                else if (len && strncasecmp("STATUS", buf, 6) == 0)
                {
                    [self _parseSTATUS];
                }
                //
                //
                //
                else if (len && strncasecmp("EXPUNGE", buf, 7) == 0)
                {
                    [self _parseEXPUNGE];
                }
                //
                //
                //
                else if (len && strncasecmp("CAPABILITY", buf, 10) == 0)
                {
                    [self _parseCAPABILITY];
                }
            }
            //
            // We got a tagged response
            //
            else
            {
                buf -= i; // go back to the beginning

                // convert buf into \0-terminated string
                char *tmpBuffer = malloc(count + 1);
                memcpy(tmpBuffer, buf, count);
                tmpBuffer[count] = '\0';

                char *response = malloc(count + 1);

                int itemsAssigned = sscanf(tmpBuffer, "%*s %s", response);

                if (itemsAssigned != 1) {
                    [self _parseBAD];
                } else {
                    if (strcmp(response, "OK") == 0) {
                        // From RFC3501:
                        //
                        // The server completion result response indicates the success or
                        // failure of the operation.  It is tagged with the same tag as the
                        // client command which began the operation.  Thus, if more than one
                        // command is in progress, the tag in a server completion response
                        // identifies the command to which the response applies.  There are
                        // three possible server completion responses: OK (indicating success),
                        // NO (indicating failure), or BAD (indicating a protocol error such as
                        // unrecognized command or command syntax error).
                        //
                        [self _parseOK];
                    } else if (strcmp(response, "NO") == 0) {
                        //
                        // RFC3501 says:
                        //
                        // The NO response indicates an operational error message from the
                        // server.  When tagged, it indicates unsuccessful completion of the
                        // associated command.  The untagged form indicates a warning; the
                        // command can still complete successfully.  The human-readable text
                        // describes the condition.
                        //
                        [self _parseNO];
                    } else {
                        [self _parseBAD];
                    }

               }
               free(tmpBuffer);
               free(response);
            }
        } // while ((aData = split_lines...
        
        //LogInfo(@"While loop broken!");
}


//
// This method NOOPs the IMAP store.
//
- (void) noop
{
    dispatch_sync(self.serviceQueue, ^{
        [self sendCommand: IMAP_NOOP  info: nil  arguments: @"NOOP"];
    });
}


//
//
//
- (int) reconnect
{
    __weak typeof(self) weakSelf = self;
    dispatch_sync(self.serviceQueue, ^{
        typeof(self) strongSelf = weakSelf;
        //LogInfo(@"CWIMAPStore: -reconnect");

        [strongSelf->_connection_state.previous_queue addObjectsFromArray: [strongSelf->_queue array]];
        strongSelf->_connection_state.reconnecting = YES;

        // We flush our read/write buffers.
        [strongSelf->_rbuf reset];
        [strongSelf->_wbuf reset];

        //
        // We first empty our queue and set again our _lastCommand ivar to
        // the IMAP_AUTHORIZATION command
        //
        //LogInfo(@"queue count = %d", [_queue count]);
        //LogInfo(@"%@", [_queue description]);
        [strongSelf->_queue removeAllObjects];
        strongSelf->_lastCommand = IMAP_AUTHORIZATION;
        LogInfo(@"reconnect currentQueueObject = nil");
        strongSelf.currentQueueObject = nil;
        strongSelf->_counter = 0;

        [super close];
        [super connectInBackgroundAndNotify];
    });

    return 0; // In case you wonder see reconnect doc: @result Pending.
}


//
//
//
- (void) startTLS
{
    dispatch_sync(self.serviceQueue, ^{
        [self sendCommand: IMAP_STARTTLS  info: nil  arguments: @"STARTTLS"];
    });
}


//
// This method authenticates the Store to the IMAP server.
// In case of an error, it returns NO.
//
//!  We MUST NOT send a login command if LOGINDISABLED is
//        enforced by the server (6.2.3).
//
- (void) authenticate: (NSString*) theUsername
             password: (NSString*) thePassword
            mechanism: (NSString*) theMechanism
{
    __weak typeof(self) weakSelf = self;
    dispatch_sync(self.serviceQueue, ^{
        typeof(self) strongSelf = weakSelf;
        strongSelf->_username = theUsername;
        strongSelf->_password = thePassword;
        strongSelf->_mechanism = theMechanism;

        // AUTH=CRAM-MD5
        if (theMechanism && [theMechanism caseInsensitiveCompare: @"CRAM-MD5"] == NSOrderedSame)
        {
            [strongSelf sendCommand: IMAP_AUTHENTICATE_CRAM_MD5  info: nil  arguments: @"AUTHENTICATE CRAM-MD5"];
            return;
        } // AUTH=LOGIN
        else if (theMechanism && [theMechanism caseInsensitiveCompare: @"LOGIN"] == NSOrderedSame)
        {
            [strongSelf sendCommand: IMAP_AUTHENTICATE_LOGIN  info: nil  arguments: @"AUTHENTICATE LOGIN"];
            return;
        }
        // AUTH=XOAUTH2
        else if (theMechanism && [theMechanism caseInsensitiveCompare: @"XOAUTH2"] == NSOrderedSame)
        {
            NSString *clientResponse = [CWOAuthUtils base64EncodedClientResponseForUser:theUsername
                                                                            accessToken:thePassword];
            [strongSelf sendCommand: IMAP_AUTHENTICATE_XOAUTH2
                         info: nil
                    arguments: @"AUTHENTICATE XOAUTH2 %@", clientResponse];
            return;
        }

        // Fallback to simple LOGIN (https://tools.ietf.org/html/rfc3501#section-6.2.3)

        NSString *safePassword = thePassword;

        // We must verify if we must quote the password
        if ([thePassword rangeOfCharacterFromSet: [NSCharacterSet punctuationCharacterSet]].length ||
            [thePassword rangeOfCharacterFromSet: [NSCharacterSet whitespaceCharacterSet]].length)
        {
            safePassword = [NSString stringWithFormat: @"\"%@\"", thePassword];
        }
        else if (![thePassword is7bitSafe])
        {
            NSData *aData;

            //
            // We support non-ASCII password by using the 8-bit ISO Latin 1 encoding.
            //!  Is there any standard on which encoding to use?
            //
            aData = [thePassword dataUsingEncoding: NSISOLatin1StringEncoding];

            [strongSelf sendCommand: IMAP_LOGIN
                               info: [NSDictionary dictionaryWithObject: aData  forKey: @"Password"]
                          arguments: @"LOGIN %@ {%d}", strongSelf->_username, [aData length]];
            return;
        }

        [strongSelf sendCommand: IMAP_LOGIN
                           info: nil
                      arguments: @"LOGIN %@ %@", strongSelf->_username, safePassword];
    });
}

#pragma mark - CWStore

//
// Create the mailbox and subscribe to it. The full path to the mailbox must
// be provided.
//
// The delegate will be notified when the folder has been created (or not).
//
- (void) createFolderWithName: (NSString *) theName
                         type: (PantomimeFolderFormat) theType
                     contents: (NSData *) theContents
{
    dispatch_sync(self.serviceQueue, ^{
        [self sendCommand: IMAP_CREATE
                     info: [NSDictionary dictionaryWithObject: theName  forKey: @"Name"]
                arguments: @"CREATE \"%@\"", [theName modifiedUTF7String]];
    });
}


//
// Delete the mailbox. The full path to the mailbox must be provided.
//
// The delegate will be notified when the folder has been deleted (or not).
//
- (void) deleteFolderWithName: (NSString *) theName
{
    dispatch_sync(self.serviceQueue, ^{
        [self sendCommand: IMAP_DELETE
                     info: [NSDictionary dictionaryWithObject: theName  forKey: @"Name"]
                arguments: @"DELETE \"%@\"", [theName modifiedUTF7String]];
    });
}


//
// This method is used to rename a folder.
//
// theName and theNewName MUST be the full path of those mailboxes.
// If they begin with the folder separator (ie., '/'), the character is
// automatically stripped.
//
// This method supports renaming SELECT'ed mailboxes.
//
// The delegate will be notified when the folder has been renamed (or not).
//
- (void) renameFolderWithName: (NSString *) theName
                       toName: (NSString *) theNewName
{
    __block NSString *blockName = theName;
    __block NSString *blockNewName = theNewName;

    __weak typeof(self) weakSelf = self;
    dispatch_sync(self.serviceQueue, ^{
        typeof(self) strongSelf = weakSelf;
        NSDictionary *info;

        blockName = [blockName stringByDeletingFirstPathSeparator: strongSelf->_folderSeparator];
        blockNewName = [blockNewName stringByDeletingFirstPathSeparator: strongSelf->_folderSeparator];
        info = [NSDictionary dictionaryWithObjectsAndKeys: blockName, @"Name", blockNewName, @"NewName", nil];

        if ([[blockName stringByTrimmingWhiteSpaces] length] == 0 ||
            [[blockNewName stringByTrimmingWhiteSpaces] length] == 0)
        {
            PERFORM_SELECTOR_3(strongSelf->_delegate, @selector(folderRenameFailed:),
                               PantomimeFolderRenameFailed, info);
        }

        [strongSelf sendCommand: IMAP_RENAME
                     info: info
                arguments: @"RENAME \"%@\" \"%@\"", [blockName modifiedUTF7String],
         [blockNewName modifiedUTF7String]];
    });
}


//
//
//
- (void)listFolders
{
    __weak typeof(self) weakSelf = self;
    dispatch_sync(self.serviceQueue, ^{
        typeof(self) strongSelf = weakSelf;

        // Throw away cached info about folders, and always fetch from server
        strongSelf->_folders = [[NSMutableDictionary alloc] init];

        // Only top level folders: LIST "" %
        [strongSelf sendCommand: IMAP_LIST  info: nil  arguments: @"LIST \"\" *"];
    });
}

//
//
//
- (void)sendIdle
{
    __weak typeof(self) weakSelf = self;
    dispatch_sync(self.serviceQueue, ^{
        typeof(self) strongSelf = weakSelf;
        [strongSelf sendCommand: IMAP_IDLE  info: nil  arguments: @"IDLE"];
    });
}


//
// This method works the same way as the -folderEnumerator method.
//
- (NSEnumerator *) subscribedFolderEnumerator
{
    __block NSEnumerator *returnee = nil;
    __weak typeof(self) weakSelf = self;
    dispatch_sync(self.serviceQueue, ^{
        typeof(self) strongSelf = weakSelf;
        if (![strongSelf->_subscribedFolders count])
        {
            [strongSelf sendCommand: IMAP_LSUB  info: nil  arguments: @"LSUB \"\" \"*\""];
            returnee = nil;

            return;
        }

        returnee = [strongSelf->_subscribedFolders objectEnumerator];
    });

    return returnee;
}


//
//
//
- (id) folderForURL: (NSString *) theURL
{
    __block id returnee = nil;
    dispatch_sync(self.serviceQueue, ^{
        CWURLName *theURLName;
        id aFolder;

        theURLName = [[CWURLName alloc] initWithString: theURL];

        aFolder = [self folderForNameInternal: [theURLName foldername]];
        RELEASE(theURLName);
        returnee = aFolder;
    });

    return returnee;
}


//
//
//
- (NSEnumerator *) openFoldersEnumerator
{
    __block NSEnumerator *returnee = nil;
    __weak typeof(self) weakSelf = self;
    dispatch_sync(self.serviceQueue, ^{
        typeof(self) strongSelf = weakSelf;
        returnee = [strongSelf->_openFolders objectEnumerator];
    });

    return returnee;
}


//
//
//
- (void) removeFolderFromOpenFolders: (CWFolder *) theFolder
{
    __weak typeof(self) weakSelf = self;
    dispatch_sync(self.serviceQueue, ^{
        typeof(self) strongSelf = weakSelf;
        if (strongSelf->_selectedFolder == (CWIMAPFolder *)theFolder)
        {
            strongSelf->_selectedFolder = nil;
        }

        [strongSelf->_openFolders removeObjectForKey: [theFolder name]];
    });
}


//
//
//
- (BOOL) folderForNameIsOpen: (NSString *) theName
{
    __block BOOL returnee = NO;
    dispatch_sync(self.serviceQueue, ^{
        NSEnumerator *anEnumerator;
        CWIMAPFolder *aFolder;

        anEnumerator = [self openFoldersEnumerator];

        while ((aFolder = [anEnumerator nextObject]))
        {
            if ([[aFolder name] compare: theName
                                options: NSCaseInsensitiveSearch] == NSOrderedSame)
            {
                returnee = YES;
                return;
            }
        }

        returnee = NO;
    });

    return returnee;
}


//
// This method verifies in the cache if theName is present.
// If so, it returns the associated value.
//
// If it's not present, it sends a LIST command to the server
// and the delegate will eventually be notified when the LIST
// command completed. It also returns 0 if it's not present.
//
- (PantomimeFolderAttribute) folderTypeForFolderName: (NSString *) theName
{
    __block PantomimeFolderAttribute returnee = 0;
    __weak typeof(self) weakSelf = self;
    dispatch_sync(self.serviceQueue, ^{
        typeof(self) strongSelf = weakSelf;
        id o = [strongSelf->_folders objectForKey: theName];

        if (o)
        {
            returnee = [o intValue];
            return;
        }

        [strongSelf sendCommand: IMAP_LIST
                           info: nil
                      arguments: @"LIST \"\" \"%@\"", [theName modifiedUTF7String]];
    });

    return returnee;

}


//
//
//
- (unsigned char) folderSeparator
{
    @synchronized (self) {
        return _folderSeparator;
    }
}


//
// The default folder in IMAP is always Inbox. This method will fetch
// the messages of an IMAP folder if they haven't been fetched before.
//
- (id) defaultFolder
{
    // is serialized by folderForName:
    return [self folderForName: @"INBOX" updateExistsCount: NO];
}

//
//
//
- (CWIMAPFolder *)folderWithName:(NSString *)name
{
    NSAssert(NO, @"Overwrite CWIMAPStore.folderWithName");
    return nil;
}


//
//
//
- (id) folderForName: (NSString *) theName  updateExistsCount: (BOOL)updateExistsCount
{
    __block id returnee = nil;
    dispatch_sync(self.serviceQueue, ^{
        returnee = [self folderForNameInternal: theName
                                          mode: PantomimeReadWriteMode
                             updateExistsCount:updateExistsCount];
    });

    return returnee;
}

//
//
// Non-serialized helper to avoid deadlocks chaining folderForName:... methods
- (id) folderForNameInternal: (NSString *) theName
{
    return [self folderForNameInternal: theName
                                  mode: PantomimeReadWriteMode updateExistsCount:NO];
}

@end


//
// Private methods
//
@implementation CWIMAPStore (Private)

//
// This method is used to parse the name of a mailbox.
//
// If the string was encoded using mUTF-7, it'll also
// decode it.
//
- (NSString *) _folderNameFromString: (NSString *) theString
{
    NSString *aString, *decodedString;
    NSRange aRange;

    aRange = [theString rangeOfString: @"\""];

    if (aRange.length)
    {
        NSUInteger mark;

        mark = aRange.location + 1;

        aRange = [theString rangeOfString: @"\""
                                  options: 0
                                    range: NSMakeRange(mark, [theString length] - mark)];

        aString = [theString substringWithRange: NSMakeRange(mark, aRange.location - mark)];

        // Check if we got "NIL" or a real separator.
        if ([aString length] == 1)
        {
            _folderSeparator = [aString characterAtIndex: 0];
        }
        else
        {
            _folderSeparator = 0;
        }

        mark = aRange.location + 2;
        aString = [theString substringFromIndex: mark];
    }
    else
    {
        aRange = [theString rangeOfString: @"NIL"  options: NSCaseInsensitiveSearch];

        if (aRange.length)
        {
            aString = [theString substringFromIndex: aRange.location + aRange.length + 1];
        }
        else
        {
            return theString;
        }
    }

    aString = [aString stringFromQuotedString];
    decodedString = [aString stringFromModifiedUTF7];

    return (decodedString != nil ? decodedString : aString);
}


//
// This method parses the flags received in theString and builds
// a corresponding Flags object for them.
//
- (void) _parseFlags: (NSString *) theString
             message: (CWIMAPMessage *) theMessage
              record: (CWCacheRecord *) theRecord
{
    CWFlags *theFlags;
    NSRange aRange;

    theFlags = [[CWFlags alloc] init];

    // We check if the message has the Seen flag
    aRange = [theString rangeOfString: @"\\Seen"
                              options: NSCaseInsensitiveSearch];

    if (aRange.location != NSNotFound)
    {
        [theFlags add: PantomimeFlagSeen];
    }

    // We check if the message has the Recent flag
    aRange = [theString rangeOfString: @"\\Recent"
                              options: NSCaseInsensitiveSearch];

    if (aRange.location != NSNotFound)
    {
        [theFlags add: PantomimeFlagRecent];
    }

    // We check if the message has the Deleted flag
    aRange = [theString rangeOfString: @"\\Deleted"
                              options: NSCaseInsensitiveSearch];

    if (aRange.location != NSNotFound)
    {
        [theFlags add: PantomimeFlagDeleted];
    }

    // We check if the message has the Answered flag
    aRange = [theString rangeOfString: @"\\Answered"
                              options: NSCaseInsensitiveSearch];

    if (aRange.location != NSNotFound)
    {
        [theFlags add: PantomimeFlagAnswered];
    }

    // We check if the message has the Flagged flag
    aRange = [theString rangeOfString: @"\\Flagged"
                              options: NSCaseInsensitiveSearch];

    if (aRange.location != NSNotFound)
    {
        [theFlags add: PantomimeFlagFlagged];
    }

    // We check if the message has the Draft flag
    aRange = [theString rangeOfString: @"\\Draft"
                              options: NSCaseInsensitiveSearch];

    if (aRange.location != NSNotFound)
    {
        [theFlags add: PantomimeFlagDraft];
    }

    [[theMessage flags] replaceWithFlags: theFlags];
    theRecord.flags = theFlags->flags;
    RELEASE(theFlags);

    //
    // If our previous command is NOT the FETCH command, we must inform our
    // delegate that messages flags have changed. The delegate SHOULD refresh
    // its view and does NOT have to issue any command to update the state
    // of the messages (since it has been done).
    //
    if (_lastCommand != IMAP_UID_FETCH_BODY_TEXT && _lastCommand != IMAP_UID_FETCH_HEADER_FIELDS &&
        _lastCommand != IMAP_UID_FETCH_HEADER_FIELDS_NOT && _lastCommand != IMAP_UID_FETCH_RFC822)
    {
        NSDictionary *userInfo = [NSDictionary
                                  dictionaryWithObject: theMessage  forKey: @"Message"];
        PERFORM_SELECTOR_2(_delegate, @selector(messageChanged:), PantomimeMessageChanged,
                           userInfo, PantomimeMessageChanged);
        }
}


//
//
//
- (void) _renameFolder
{
    CWFolderInformation *aFolderInformation;
    NSString *aName, *aNewName;
    CWIMAPFolder *aFolder;

    aName = [self.currentQueueObject.info objectForKey: @"Name"];
    aNewName = [self.currentQueueObject.info objectForKey: @"NewName"];

    // If the folder was open, we change its name and recache its entry.
    aFolder = [_openFolders objectForKey: aName];

    if (aFolder)
    {
        RETAIN_VOID(aFolder);
        [aFolder setName: aNewName];
        [_openFolders removeObjectForKey: aName];
        [_openFolders setObject: aFolder  forKey: aNewName];
        RELEASE(aFolder);
    }

    // We then do the same thing for our list of folders / suscribed folders
    aFolderInformation = RETAIN([_folders objectForKey: aName]);
    [_folders removeObjectForKey: aName];

    if (aFolderInformation)
    {
        [_folders setObject: aFolderInformation  forKey: aNewName];
        RELEASE(aFolderInformation);
    }

    if ([_subscribedFolders containsObject: aName])
    {
        [_subscribedFolders removeObject: aName];
        [_subscribedFolders addObject: aNewName];
    }
}

//
// This method parses a IMAP_UID_FETCH_UIDS response in order to decode
// all UIDs in the result.
//
// Examples:
// "* 170 FETCH (UID 95516)"
//
- (NSArray<NSNumber*> *)_uniqueIdentifiersFromFetchUidsResponseData:(NSData *)response
{
    NSString *searchResponsePrefix = @"* X FETCH";
    return [self _uniqueIdentifiersFromData: response
                 skippingFirstNumberOfChars: searchResponsePrefix.length];
}

//
// This method parses a SEARCH response in order to decode
// all UIDs in the result.
//
// Examples of theData:
//
// "* SEARCH 1 4 59 81"
// "* SEARCH"
//
- (NSArray<NSNumber*> *)_uniqueIdentifiersFromSearchResponseData:(NSData *)response
{
    NSString *searchResponsePrefix = @"* SEARCH";
    return [self _uniqueIdentifiersFromData: response
                 skippingFirstNumberOfChars: searchResponsePrefix.length];
}


- (NSArray<NSNumber*> *)_uniqueIdentifiersFromData:(NSData *)theData
                        skippingFirstNumberOfChars:(NSUInteger)numSkipPre
{
    NSMutableArray<NSNumber*> *results = [NSMutableArray new];
    if (numSkipPre >= theData.length) {
        // Nothing to scan.
        return results;
    }
    theData = [theData subdataFromIndex: numSkipPre];
    if (![theData length]) {
        // Nothing to scan.
        return results;
    }

    // We scan all our UIDs.
    NSScanner *scanner = [[NSScanner alloc] initWithString: [theData asciiString]];
    NSUInteger value = 0;
    while (![scanner isAtEnd]) {
        [scanner scanUnsignedInt: &value];
        if (value != 0) {
            [results addObject: [NSNumber numberWithInteger: value]];
        }
    }

    return results;
}


//
//
//
- (void) _parseAUTHENTICATE_CRAM_MD5
{
    NSData *aData;

    aData = [_responsesFromServer lastObject];

    //
    // We first verify if we got our challenge response from the IMAP server.
    // If so, we use it and send back a response to proceed with the authentication.
    //
    if ([aData hasCPrefix: "+"])
    {
        NSString *aString;
        CWMD5 *aMD5;

        // We trim the "+ " and we keep the challenge phrase
        aData = [aData subdataFromIndex: 2];

        //LogInfo(@"Challenge phrase = |%@|", [aData asciiString]);
        aMD5 = [[CWMD5 alloc] initWithData: [aData decodeBase64]];
        [aMD5 computeDigest];

        aString = [NSString stringWithFormat: @"%@ %@", _username, [aMD5 hmacAsStringUsingPassword: _password]];
        aString = [[NSString alloc] initWithData: [[aString dataUsingEncoding: NSASCIIStringEncoding] encodeBase64WithLineLength: 0]
                                        encoding: NSASCIIStringEncoding];

        [self bulkWriteData:@[[aString dataUsingEncoding: _defaultStringEncoding],
                                 _crlf]];
        RELEASE(aMD5);
        RELEASE(aString);
    }
}


//
// LOGIN is a very lame authentication method but we support it anyway. We basically
// wait for a challenge, send the username (in base64), wait for an other challenge
// and finally send the password (in base64). The challenges aren't even used.
//
- (void) _parseAUTHENTICATE_LOGIN
{
    NSData *aData;

    aData = [_responsesFromServer lastObject];

    //
    // We first verify if we got our challenge response from the IMAP server.
    // If so, we use it and send back a response to proceed with the authentication.
    // Based on what we sent before, we can either send the username or the password.
    //
    if ([aData hasCPrefix: "+"])
    {
        NSData *aResponse;

        // Have we read the initial challenge? If not, we must send the username!
        if (self.currentQueueObject && ![self.currentQueueObject.info
                                         objectForKey: @"Challenge"])
        {
            aResponse =  [[_username dataUsingEncoding: NSASCIIStringEncoding]
                          encodeBase64WithLineLength: 0];
            [self.currentQueueObject.info setObject: aData  forKey: @"Challenge"];
        }
        else
        {
            aResponse = [[_password dataUsingEncoding: NSASCIIStringEncoding]
                         encodeBase64WithLineLength: 0];
        }

        [self bulkWriteData:@[aResponse, _crlf]];
    }
}


//
//
//
- (void) _parseBAD
{
    // Synchronize all methods that alter the _queue
    @synchronized(self) {
        NSData *aData;

        aData = [_responsesFromServer lastObject];

        LogError(@"IN _parseBAD: |%@| %d", [aData asciiString], _lastCommand);

        switch (_lastCommand)
        {
            case IMAP_LOGIN:
                // This can happen if we got an empty username or password.
                AUTHENTICATION_FAILED(_delegate, _mechanism);
                break;
            case IMAP_AUTHENTICATE_CRAM_MD5:
            case IMAP_AUTHENTICATE_XOAUTH2: // Only added for completenes. In reality XOAuth2 never responds with BAD (only Gmail tested so far)
            case IMAP_AUTHENTICATE_LOGIN:
                // Probably wrong credentials.
                // Example case: 0003 BAD [AUTHENTICATIONFAILED] AUTHENTICATE Invalid credentials
                AUTHENTICATION_FAILED(_delegate, _mechanism);
                break;
            case IMAP_SELECT: {
                [_queue removeLastObject];
                [_responsesFromServer removeAllObjects];

                if ([_selectedFolder.name isEqualToString:PantomimeFolderNameToIgnore]) {
                    // PantomimeFolderNameToIgnore is used as a workaround to close a mailbox (aka. folder)
                    // without calling CLOSE.
                    // see RFC4549-4.2.5
                    _selectedFolder = nil;
                    PERFORM_SELECTOR_2([self delegate], @selector(folderCloseCompleted:), PantomimeFolderCloseCompleted, self, @"Folder");
                    return;
                }

                NSDictionary *userInfo = @{PantomimeBadResponseInfoKey:[aData asciiString]};
                PERFORM_SELECTOR_2(_delegate, @selector(folderOpenFailed:),
                                   PantomimeFolderOpenFailed, userInfo,
                                   PantomimeErrorInfo);
            }
                break;
            case IMAP_UID_MOVE:
            default:
                // We got a BAD response that we could not handle. Inform the delegate,
                // post a notification and remove the command that caused this from the queue.
                [_queue removeLastObject];
                [_responsesFromServer removeAllObjects];

                NSDictionary *userInfo = @{PantomimeBadResponseInfoKey: [aData asciiString]};
                PERFORM_SELECTOR_2(_delegate, @selector(badResponse:),
                                   PantomimeBadResponse, userInfo,
                                   PantomimeErrorInfo);
        }

        if (![aData hasCPrefix: "*"])
        {
            [_queue removeLastObject];
            [self sendCommand: IMAP_EMPTY_QUEUE  info: nil  arguments: @""];
        }

        [_responsesFromServer removeAllObjects];
    }
}


//
//
//
- (void) _parseBYE
{
    //
    // We check if we sent the IMAP_LOGOUT command.
    //
    // If we got an untagged BYE response, it means
    // that the server disconnected us. We will
    // handle that in CWService: -updateRead.
    //
    if (_lastCommand == IMAP_LOGOUT)
    {
        return;
    }
}


//
// This method parses an * CAPABILITY IMAP4 IMAP4rev1 ACL AUTH=LOGIN NAMESPACE ..
// untagged response (6.1.1)
- (void) _parseCAPABILITY
{
    NSString *aString;
    NSData *aData;

    aData = [_responsesFromServer objectAtIndex: 0];
    aString = [[NSString alloc] initWithData: aData  encoding: _defaultStringEncoding];

    [_capabilities addObjectsFromArray: [[aString substringFromIndex: 13] componentsSeparatedByString: @" "]];
    RELEASE(aString);

    if (_connection_state.reconnecting)
    {
        [self authenticate: _username  password: _password  mechanism: _mechanism];
    }
    else
    {
        PERFORM_SELECTOR_1(_delegate, @selector(serviceInitialized:),  PantomimeServiceInitialized);
    }
}


//
// This method parses an * 23 EXISTS untagged response. (7.3.1)
//
// If we were NOT issueing a SELECT command, it informs the folder's delegate that
// new messages have arrived.
//
- (void) _parseEXISTS
{
    NSData *aData;
    int n;

    aData = [_responsesFromServer lastObject];
    sscanf([aData cString], "* %d EXISTS", &n);
    _selectedFolder.existsCount = n;
    LogInfo(@"EXISTS %d", n);
    if (_lastCommand == IMAP_IDLE) {
        PERFORM_SELECTOR_1(_delegate, @selector(idleNewMessages:), PantomimeIdleNewMessages);
    }
}

#pragma mark - --

//
// Example: * 44 EXPUNGE
//
- (void)_parseEXPUNGE
{
    if (_lastCommand == IMAP_UID_STORE) {
        // Calling IMAP_UID_STORE to set a \deleted flag on Gmail server, the server moves those
        // messages to "All Messages", expunges it from the folder it has been deleted in and
        // reports it here.
        // The client has to take care to delete the original msg currently.
        return;
    }

    int msn;
    NSData *aData = [_responsesFromServer lastObject];
    sscanf([aData cString], "* %d EXPUNGE", &msn);

    // It looks like some servers send untagged expunge reponses
    // _after_ the selected folder has been closed.
    if (!_selectedFolder) {
        LogInfo(@"EXPUNGE %d on already closed folder", msn);
        return;
    }
    // The conditions for being able to react safely to expunges have to be verified.
    // In the case of IDLE, it's probably safe.
    if (_lastCommand != IMAP_IDLE && _lastCommand != IMAP_UID_MOVE) {
        return;
    }

    //LogInfo(@"EXPUNGE %d", msn);

    // Messages CAN be expunged before we really had time to FETCH them.
    // We simply proceed by skipping over MSN that are bigger than we
    // we have so far. It should be safe since the view hasn't even
    // had the chance to display them.
    if (msn > [_selectedFolder lastMSN]) {
        return;
    }

    CWIMAPMessage *aMessage = (CWIMAPMessage *) [_selectedFolder messageAtIndex: msn];

    //!!!: The following is a complete mess. Inconsistant. Wrong.
    //!!!: Please rethink, rewrite and remove.

    // We do NOT use  [_selectedFolder removeMessage: aMessage] since it'll
    // thread the messages everytime we invoke it. We rather thread messages
    // if:
    // * We got an untagged EXPUNGE response but the last command was NOT
    //   an EXPUNGE one (see below, near the end of the method)
    // * We sent an EXPUNGE command - we'll do the threading of the
    //   messages in _parseOK:
    [_selectedFolder removeMessage: aMessage]; // responsible for also shifting following MSNs
    [_selectedFolder updateCache];

    // We remove its entry in our cache
    if ([_selectedFolder cacheManager]) {
        [(CWIMAPCacheManager *)[_selectedFolder cacheManager] removeMessageWithUID: [aMessage UID]]; //This doubles remove Message above. Cleanup cacheManager mess.
    }

    // Keep exist count up to date.
    _selectedFolder.existsCount = _selectedFolder.existsCount - 1;

    // If our previous command is NOT the EXPUNGE command, we must inform our
    // delegate that messages have been expunged. The delegate SHOULD refresh
    // its view and does NOT have to issue any command to update the state
    // of the messages (since it has been done).
    if (_lastCommand != IMAP_EXPUNGE) {
        PERFORM_SELECTOR_1(_delegate, @selector(messageExpunged:), PantomimeMessageExpunged);
    }
    LogInfo(@"Expunged %d", msn);
}

/**
 @Return: The UID extracted from a list of NSData (as part of a fetch request), or
 0 if none could be identified.
 */
- (NSUInteger)extractUIDFromDataArray:(NSArray *)datas
{
    for (NSData *data in datas) {
        NSString *aString = [data asciiString];
        NSTextCheckingResult *match = [self.uidRegex
                                       firstMatchInString:aString options:0
                                       range:NSMakeRange(0, aString.length)];
        if (match) {
            NSRange r = [match rangeAtIndex:1];
            if (r.location != NSNotFound) {
                NSString *uidString = [aString substringWithRange:r];
                return uidString.integerValue;
            }
        }
    }
    /*
     for (NSData *data in datas) {
     NSString *aString = [data asciiString];
     LogInfo("extractUID: '%@'", aString);
     }
     */
    return 0;
}


/**
 Examples:
 "* 170 FETCH (UID 95516)"
 */
- (void) _parseFETCH_UIDS
{
    NSArray<NSNumber*> *uidsFromResponse =
    [self _uniqueIdentifiersFromFetchUidsResponseData:[_responsesFromServer lastObject]];

    LogInfo(@"[_responsesFromServer lastObject]: %@",
            [[_responsesFromServer lastObject] asciiString]);

    NSArray *alreadyParsedUids = self.currentQueueObject.info[@"Uids"];
    if (!alreadyParsedUids) {
        alreadyParsedUids = uidsFromResponse;
    } else {
        alreadyParsedUids = [alreadyParsedUids arrayByAddingObjectsFromArray:uidsFromResponse];
    }
    // Store/update the results in our command queue.
    [self.currentQueueObject.info setObject:alreadyParsedUids forKey:@"Uids"];
}

//
//
// Examples of FETCH responses:
//
// * 50 FETCH (UID 50 RFC822 {6718}
// Return-Path: <...
// )
//
//
// * 418 FETCH (FLAGS (\Seen) UID 418 RFC822.SIZE 3565452 BODY[HEADER.FIELDS (From To Cc Subject Date Message-ID
// References In-Reply-To MIME-Version)] {666}
// Subject: abc
// ...
// )
//
//
// * 50 FETCH (UID 50 BODY[HEADER.FIELDS.NOT (From To Cc Subject Date Message-ID References In-Reply-To MIME-Version)] {1412}
// Return-Path: <...
// )
//
// * 50 FETCH (BODY[TEXT] {5009}
// Hi, ...
// )
//
//
// "Twisted" response from Microsoft Exchange 2000:
//
// * 549 FETCH (FLAGS (\Recent) RFC822.SIZE 970 BODY[HEADER.FIELDS (From To Cc Subject Date Message-ID References In-Reply-To MIME-Version)] {196}
// From: <aaaaaa@bbbbbbbbbbbbbbb.com>
// To: aaaaaa@bbbbbbbbbbbbbbb.com
// Subject: Test mail
// Date: Tue, 16 Dec 2003 15:52:23 GMT
// Message-Id: <200312161552.PAA07523@aaaaaaa.bbb.ccccccccccccccc.com>
//
//  UID 29905)
//
//
// Yet an other "twisted" response, likely coming from UW IMAP Server (2001.315rh)
//
// * 741 FETCH (UID 23628 BODY[TEXT] {818}
// f00bar baz
// ...
// )
// * 741 FETCH (FLAGS (\Seen) UID 23628)
// 000b OK UID FETCH completed
//
//
// Other examples:
//
// * 1 FETCH (FLAGS (\Seen) UID 97 RFC822.SIZE 19123 BODY[HEADER.FIELDS (From To Cc Subject Date
// Message-ID References In-Reply-To MIME-Version)] {216}
//
// This method can be called more than on times for a message. For example, Exchange sends
// answers like this one:
//
// * 9 FETCH (BODY[HEADER.FIELDS.NOT (From To Cc Subject Date Message-ID References In-Reply-To MIME-Version)] {408}
// Received: by nt1.inverse.qc.ca
// .id <01C34ADC.D13E2A20@nt1.inverse.qc.ca>; Tue, 15 Jul 2003 09:24:36 -0500
// content-class: urn:content-classes:message
// Content-Type: multipart/mixed;
// .boundary="----_=_NextPart_001_01C34ADC.D13E2A20"
// X-MS-Has-Attach: yes
// X-MS-TNEF-Correlator:
// Thread-Topic: test5
// X-MimeOLE: Produced By Microsoft Exchange V6.0.6249.0
// Thread-Index: AcNK3NDIIAS/1aRKSYC4x2N4Zj3GGg==
//
// UID 9)
//
// And we MUST parse the UID correctly.
//
- (void) _parseFETCH: (NSInteger) theMSN
{
    NSMutableString *aMutableString;
    NSCharacterSet *aCharacterSet;
    CWIMAPMessage *aMessage;
    NSScanner *aScanner;

    NSMutableArray *aMutableArray;
    NSString *aWord, *aString;
    NSRange aRange;

    BOOL done, seen_fetch, must_flush_record;
    // Indicates whether we are creating a new mail or are updating an existing one
    BOOL isMessageUpdate = NO;
    NSInteger i, j, count, len;
    CWCacheRecord *cacheRecord = [[CWCacheRecord alloc] init];

    //
    // The folder might have been closed so we must not try to
    // update it for no good reason.
    //
    if (!_selectedFolder) return;

    if (!_selectedFolder.selected) {
        [NSException raise: PantomimeProtocolException
                    format: @"Unable to fetch message content from unselected mailbox."];
    }

    count = [_responsesFromServer count]-1;

    //LogInfo(@"RESPONSES FROM SERVER: %d", count);

    aMutableString = [[NSMutableString alloc] init];
    aMutableArray = [[NSMutableArray alloc] init];

    //
    // Note:
    //
    // We must be careful here to NOT consider all responses from the server. For example,
    // UW IMAP might send us:
    // 1 UID SEARCH ANSWERED
    // * SEARCH
    // * 1 FETCH (FLAGS (\Recent \Seen) UID 1)
    // 1 OK UID SEARCH completed
    //
    // In such response, we must NOT consider the "* SEARCH" response.
    //
    must_flush_record = seen_fetch = NO;

    // Extract the UID from anywhere in the response
    NSUInteger theUID = [self extractUIDFromDataArray:_responsesFromServer.array];

    if (theUID == 0) {
        // If there is no UID in this response, try to deduce it from the mapping
        theUID = [_selectedFolder uidForMSN:theMSN];
    }

    LogInfo(@"parseFETCH theMSN %lu, UID %lu", (unsigned long) theMSN, (unsigned long)theUID);

    // Try to retrieve the message by UID
    if (theUID > 0) {
        LogInfo(@"Trying existing message for UID %lu", (unsigned long)theUID);
        aMessage = (CWIMAPMessage *) [_selectedFolder.cacheManager messageWithUID:theUID];
    }

    if (aMessage == nil) {
        LogInfo(@"New message");
        aMessage = [[CWIMAPMessage alloc] init];
        // We set some initial properties to our message;
        [aMessage setInitialized: NO];
        [aMessage setFolder: _selectedFolder];
        [_selectedFolder appendMessage: aMessage];
    } else {
        isMessageUpdate = YES;
    }
    
    CWMessageUpdate *messageUpdate = [CWMessageUpdate new];

    if (!isMessageUpdate) {
        // A UID must never change for an existing mail
        [aMessage setUID:theUID];
        messageUpdate.uid = YES;
    }

    // We add the new message to our cache.
    if ([_selectedFolder cacheManager]) {
        if (must_flush_record)
        {
            [[_selectedFolder cacheManager] writeRecord: cacheRecord  message: aMessage]; //This can never be reached afaics. Check, remove.
        }

        CLEAR_CACHE_RECORD(cacheRecord);
        must_flush_record = YES;
        //[[_selectedFolder cacheManager] addObject: aMessage];
    }

    for (i = 0; i <= count; i++) {
        aString = [[_responsesFromServer objectAtIndex: i] asciiString];

        //LogInfo(@"%i: %@", i, aString);
        if (!seen_fetch && [aString hasCaseInsensitivePrefix: [NSString stringWithFormat: @"* %ld FETCH", (long)theMSN]])
        {
            seen_fetch = YES;
        }

        if (seen_fetch) {
            [aMutableArray addObject: [_responsesFromServer objectAtIndex: i]];
            [aMutableString appendString: aString];
            if (i < count-1) {
                [aMutableString appendString: @" "];
            }
        }
    }

    //LogInfo(@"GOT TO PARSE: |%@|", aMutableString);

    aCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    len = [aMutableString length];
    i = j = 0;

    aScanner = [[NSScanner alloc] initWithString: aMutableString];
    [aScanner setScanLocation: i];

    done = ![aScanner scanUpToCharactersFromSet: aCharacterSet  intoString: NULL];

    //
    // We tokenize our string into words
    //
    while (!done) {
        j = [aScanner scanLocation];
        aWord = [[aMutableString substringWithRange: NSMakeRange(i,j-i)] stringByTrimmingWhiteSpaces];

        //LogInfo(@"WORD |%@|", aWord);

        if ([aWord characterAtIndex: 0] == '(') {
            aWord = [aWord substringFromIndex: 1];
        }

        //
        // We read the MSN
        //
        if ([aWord characterAtIndex: 0] == '*') {
            int msn;

            [aScanner scanInt: &msn];
            //LogInfo(@"*** msn = %d", msn);
            if (aMessage.messageNumber != msn) {
                [aMessage setMessageNumber: msn];
                messageUpdate.msn = YES;
            }

            // Store any mapping MSN -> UID that came from the server
            [_selectedFolder matchUID:theUID withMSN:theMSN];
        }
        // end of reading MSN

        //
        // We read our UID
        //
        if ([aWord caseInsensitiveCompare: @"UID"] == NSOrderedSame)
        {
            NSUInteger uid;

            [aScanner scanUnsignedInt: &uid];
            //LogInfo(@"uid %d j = %d, scanLoc = %d", uid, j, [aScanner scanLocation]);

            if ([aMessage UID] == 0)
            {
                [aMessage setUID: uid];
                cacheRecord.imap_uid = uid;
                messageUpdate.uid = YES;
            }

            j = [aScanner scanLocation];
        }
        //
        // We read our flags. We usually get something like FLAGS (\Seen)
        //
        else if ([aWord caseInsensitiveCompare: @"FLAGS"] == NSOrderedSame) {
            // We get the substring inside our ( )
            aRange = [aMutableString rangeOfString: @")"  options: 0  range: NSMakeRange(j,len-j)];
            //LogInfo(@"Flags = |%@|", [aMutableString substringWithRange: NSMakeRange(j+2, aRange.location-j-2)]);
            CWFlags *flagsBefore = aMessage.flags.copy;
            [self _parseFlags: [aMutableString substringWithRange: NSMakeRange(j+2, aRange.location-j-2)]
                      message: aMessage
                       record: cacheRecord];
            j = aRange.location + 1;
            [aScanner setScanLocation: j];
            if (!isMessageUpdate) {
                messageUpdate.flags = YES;
            } else if (aMessage.flags.rawFlagsAsShort != flagsBefore.rawFlagsAsShort) {
                // For an existing message: trigger update only if the flags did actually change
                messageUpdate.flags = YES;
            }
        }
        //
        // We read the RFC822 message size
        //
        else if ([aWord caseInsensitiveCompare: @"RFC822.SIZE"] == NSOrderedSame&& !isMessageUpdate) {
            int size;

            [aScanner scanInt: &size];
            //LogInfo(@"size = %d", size);
            [aMessage setSize: size];
            cacheRecord.size = size;

            j = [aScanner scanLocation];

            messageUpdate.rfc822Size = YES;
        }
        //
        // We must not break immediately after parsing this information. It's very important
        // since servers like Exchange might send us responses like:
        //
        // * 1 FETCH (FLAGS (\Seen) RFC822.SIZE 4491 BODY[HEADER.FIELDS (From To Cc Subject Date Message-ID References In-Reply-To Content-Type)] {337} UID 614348)
        //
        // If we break right away, we'll skip the size and more importantly, the UID.
        //
        else if ([aWord caseInsensitiveCompare: @"BODY[HEADER]"] == NSOrderedSame && !isMessageUpdate) {
            [[self.currentQueueObject.info objectForKey: @"NSData"] replaceCRLFWithLF];
            [aMessage setHeadersFromData: [self.currentQueueObject.info objectForKey: @"NSData"]  record: cacheRecord];
            messageUpdate.bodyHeader = YES;
        }
        //
        //
        //
        else if ([aWord caseInsensitiveCompare: @"BODY[TEXT]"] == NSOrderedSame && !isMessageUpdate) {
            [[self.currentQueueObject.info objectForKey: @"NSData"] replaceCRLFWithLF];
            if (![aMessage content]) {
                NSData *aData;

                //
                // We do an initial check for the message body. If we haven't read a literal,
                // [self.currentQueueObject.info objectForKey: @"NSData"] returns nil. This can
                // happen with messages having a totally emtpy body. For those messages,
                // we simply set a default content, being an empty NSData instance.
                //
                aData = [self.currentQueueObject.info objectForKey: @"NSData"];

                if (!aData) aData = [NSData data];

                [CWMIMEUtility setContentFromRawSource: aData  inPart: aMessage];
                [aMessage setInitialized: YES];

                [self.currentQueueObject.info setObject: aMessage  forKey: @"Message"];

                messageUpdate.bodyText = YES;
                [[_selectedFolder cacheManager] writeRecord: cacheRecord  message: aMessage
                                              messageUpdate: messageUpdate];

                PERFORM_SELECTOR_2(_delegate, @selector(messagePrefetchCompleted:), PantomimeMessagePrefetchCompleted, aMessage, @"Message");
            }
            break;
        }
        //
        //
        //
        else if (([aWord caseInsensitiveCompare: @"RFC822"] == NSOrderedSame ||
                 [aWord caseInsensitiveCompare: @"BODY[]"] == NSOrderedSame)
                 && !isMessageUpdate) {
            [[self.currentQueueObject.info objectForKey: @"NSData"] replaceCRLFWithLF];

            NSData *aData = [self.currentQueueObject.info objectForKey: @"NSData"];
            if (!aData) aData = [NSData data];

            [aMessage setHeadersFromData: aData record: cacheRecord];

            NSRange aRange = [aData rangeOfCString: "\n\n"];
            if (aRange.location != NSNotFound) {
                [CWMIMEUtility setContentFromRawSource:
                 [aData subdataWithRange: NSMakeRange(aRange.location + 2,
                                                      [aData length] - (aRange.location + 2))]
                                                inPart: aMessage];
            }

            [aMessage setRawSource: aData];

            [aMessage setInitialized: YES];

            [self.currentQueueObject.info setObject: aMessage  forKey: @"Message"];

            messageUpdate.rfc822 = YES;
            [[_selectedFolder cacheManager] writeRecord: cacheRecord  message: aMessage
                                          messageUpdate: messageUpdate];

            PERFORM_SELECTOR_2(_delegate, @selector(messagePrefetchCompleted:),
                               PantomimeMessagePrefetchCompleted, aMessage, @"Message");

            break;
        }

        i = j;
        done = ![aScanner scanUpToCharactersFromSet: aCharacterSet  intoString: NULL];

        if (done && must_flush_record) {
            if (isMessageUpdate && !messageUpdate.isNoChange) {
                // If the message existed locally before (is update), bother the cache manager only
                // if something has changed on server.
                [[_selectedFolder cacheManager] writeRecord: cacheRecord  message: aMessage
                                              messageUpdate: messageUpdate];
            }
        }
    }

    RELEASE(aScanner);
    RELEASE(aMutableString);

    //
    // It is important that we remove the responses we have processed. This is particularly
    // useful if we are caching an IMAP mailbox. We could receive thousands of untagged
    // FETCH responses and we don't want to go over them again and again everytime
    // this method is invoked.
    //
    [_responsesFromServer removeObjectsInArray: aMutableArray];
    RELEASE(aMutableArray);
    RELEASE(cacheRecord);
}


//
// This command parses the result of a LIST command. See 7.2.2 for the complete
// description of the LIST response.
//
// Rationale:
//
// In IMAP, all mailboxes can hold messages and folders. Thus, the HOLDS_MESSAGES
// flag is ALWAYS set for a mailbox that has been parsed.
//
// We also support RFC3348 \HasChildren and \HasNoChildren flags. In fact, we
// directly map \HasChildren to HOLDS_FOLDERS.
//
// We support the following standard flags (from RFC3501):
//
//      \Noinferiors
//         It is not possible for any child levels of hierarchy to exist
//         under this name; no child levels exist now and none can be
//         created in the future.
//
//      \Noselect
//         It is not possible to use this name as a selectable mailbox.
//
//      \Marked
//         The mailbox has been marked "interesting" by the server; the
//         mailbox probably contains messages that have been added since
//         the last time the mailbox was selected.
//
//      \Unmarked
//         The mailbox does not contain any additional messages since the
//         last time the mailbox was selected.
//
- (void) _parseLIST
{
    NSString *aFolderName, *aString, *theString;
    NSRange r1, r2;
    NSUInteger len;

    theString = [[_responsesFromServer lastObject] imapUtf7String];
    //
    // We verify if we got the number of bytes to read instead of the real mailbox name.
    // That happens if we couldn't get the ASCII string of what we read.
    //
    // Some servers seem to send that when the mailbox name is 8-bit. Those 8-bit mailbox
    // names were undefined in earlier versions of the IMAP protocol (now deprecated).
    // See section 5.1. (Mailbox Naming) of RFC3051.
    //
    // The RFC says we SHOULD interpret that as UTF-8.
    //
    // If we got a 8-bit string, we rollback to get the previous answer in order
    // to also decode the mailbox attribute.
    //
    if (!theString)
    {
        aFolderName = AUTORELEASE([[NSString alloc] initWithData: [_responsesFromServer lastObject]  encoding: NSUTF8StringEncoding]);

        // We get the "previous" line which contains our mailbox attributes
        theString = [[_responsesFromServer objectAtIndex: [_responsesFromServer count]-2] asciiString];
    }
    else
    {
        // We get the folder name and the mailbox name attributes
        aFolderName = [self _folderNameFromString: theString];
    }

    //
    // If the folder name starts/ends with {}, that means it was "wrongly" encoded using
    // 8-bit characters which are not allowed. We just return since we'll re-enter in
    // _parseLIST whenever the real mailbox name will be read.
    //
    len = [aFolderName length];
    if (len > 0 && [aFolderName characterAtIndex: 0] == '{' && [aFolderName characterAtIndex: len-1] == '}')
    {
        return;
    }

    // We try to get our name attributes.
    r1 = [theString rangeOfString: @"("];

    if (r1.location == NSNotFound)
    {
        return;
    }

    r2 = [theString rangeOfString: @")"  options: 0  range: NSMakeRange(r1.location+1, [theString length]-r1.location-1)];

    if (r2.location == NSNotFound)
    {
        return;
    }

    aString = [theString substringWithRange: NSMakeRange(r1.location+1, r2.location-r1.location-1)];

    // We get all the supported flags
    PantomimeFolderAttribute folderAttributes = [self _folderAttributesForServerResponse:aString];

    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:
                                     @{PantomimeFolderNameKey: aFolderName,
                                       PantomimeFolderFlagsKey: [NSNumber numberWithInteger: folderAttributes],
                                       PantomimeFolderSeparatorKey: [NSString stringWithFormat:@"%c",
                                                                     [self folderSeparator]]}
                                     ];
    /* Get Special-Use attributes
     According to RFC 6154 servers supporting spacial-use mailboxes send the CREATE-SPECIAL-USE capatibility.
     We alway check for those attributes even the server does not mention "CREATE-SPECIAL-USE"
     in the capabilities, as not all server promote this (for instance Yahoo!).
     */
    PantomimeSpecialUseMailboxType specialUse = [self _specialUseTypeForServerResponse:aString];
    if (specialUse != PantomimeSpecialUseMailboxNormal)
    {
        // A special-use mailbox purpose has been reported by the server.
        userInfo[PantomimeFolderSpecialUseKey] = [NSNumber numberWithInteger: specialUse];
    }

    // Inform client about potential new folder, so it can be saved.
    PERFORM_SELECTOR_2(_delegate, @selector(folderNameParsed:),
                       PantomimeFolderNameParsed, userInfo, PantomimeFolderInfo);

    [_folders setObject: [NSNumber numberWithInteger: folderAttributes]  forKey: aFolderName];
}

/**
 Parses mailbox/folder attributes from a \LIST response.
 @param listResponse server response for \LIST command for one folder
 @return folder types
 */
- (PantomimeFolderAttribute)_folderAttributesForServerResponse:(NSString *)listResponse
{
    PantomimeFolderAttribute type = PantomimeHoldsMessages;

    // We get all the supported flags, starting with the flags of RFC3348
    if ([listResponse length])
    {
        if ([listResponse rangeOfString: @"\\HasChildren" options: NSCaseInsensitiveSearch].length)
        {
            type |= PantomimeHoldsFolders;
        }

        if ([listResponse rangeOfString: @"\\NoInferiors" options: NSCaseInsensitiveSearch].length)
        {
            type |= PantomimeNoInferiors;
        }

        if ([listResponse rangeOfString: @"\\NoSelect" options: NSCaseInsensitiveSearch].length)
        {
            type |= PantomimeNoSelect;
        }

        if ([listResponse rangeOfString: @"\\Marked" options: NSCaseInsensitiveSearch].length)
        {
            type |= PantomimeMarked;
        }

        if ([listResponse rangeOfString: @"\\Unmarked" options: NSCaseInsensitiveSearch].length)
        {
            type |= PantomimeUnmarked;
        }
    }

    return type;
}

/**
 Parses Special-Use attributes for one mailbox/folder from a \LIST response. RFC 6154.

 @param listResponse server response for \LIST command for one folder
 @return special-use attribute
 */
- (PantomimeSpecialUseMailboxType)_specialUseTypeForServerResponse:(NSString *)listResponse
{
    PantomimeSpecialUseMailboxType specialUse = PantomimeSpecialUseMailboxNormal;
    // We get all the special-use attributes (RFC3348)
    specialUse = PantomimeSpecialUseMailboxNormal;

    if ([listResponse length])
    {
        if ([listResponse rangeOfString: @"\\All" options: NSCaseInsensitiveSearch].length)
        {
            specialUse = PantomimeSpecialUseMailboxAll;
        }
        if ([listResponse rangeOfString: @"\\Archive" options: NSCaseInsensitiveSearch].length)
        {
            specialUse = PantomimeSpecialUseMailboxArchive;
        }
        if ([listResponse rangeOfString: @"\\Drafts" options: NSCaseInsensitiveSearch].length)
        {
            specialUse = PantomimeSpecialUseMailboxDrafts;
        }
        if ([listResponse rangeOfString: @"\\Flagged" options: NSCaseInsensitiveSearch].length)
        {
            specialUse = PantomimeSpecialUseMailboxFlagged;
        }
        if ([listResponse rangeOfString: @"\\Junk" options: NSCaseInsensitiveSearch].length)
        {
            specialUse = PantomimeSpecialUseMailboxJunk;
        }
        if ([listResponse rangeOfString: @"\\Sent" options: NSCaseInsensitiveSearch].length)
        {
            specialUse = PantomimeSpecialUseMailboxSent;
        }
        if ([listResponse rangeOfString: @"\\Trash" options: NSCaseInsensitiveSearch].length)
        {
            specialUse = PantomimeSpecialUseMailboxTrash;
        }
    }

    return specialUse;
}


//
//
//
- (void) _parseLSUB
{
    NSString *aString, *aFolderName;
    NSUInteger len;

    aString = [[NSString alloc] initWithData: [_responsesFromServer lastObject]
                                    encoding: _defaultStringEncoding];

    if (!aString)
    {
        aFolderName = AUTORELEASE([[NSString alloc] initWithData: [_responsesFromServer lastObject]
                                                        encoding: NSUTF8StringEncoding]);
    }
    else
    {
        aFolderName = [self _folderNameFromString: aString];
        RELEASE(aString);
    }


    // Check the rationale in _parseLIST.
    len = [aFolderName length];
    if (len > 0 && [aFolderName characterAtIndex: 0] == '{' && [aFolderName characterAtIndex: len-1] == '}')
    {
        RELEASE(aString);
        return;
    }

    [_subscribedFolders addObject: aFolderName];
    RELEASE(aString);
}

//
//
//
- (void) _parseNO
{
    // Synchronize all methods that alter the _queue
    @synchronized(self) {
        NSData *aData;

        aData = [_responsesFromServer lastObject];

        LogInfo(@"IN _parseNO: |%@| %d", [aData asciiString], _lastCommand);

        switch (_lastCommand)
        {
            case IMAP_APPEND:
                PERFORM_SELECTOR_3(_delegate, @selector(folderAppendFailed:), PantomimeFolderAppendFailed, self.currentQueueObject.info);
                break;

            case IMAP_AUTHENTICATE_CRAM_MD5:
            case IMAP_AUTHENTICATE_LOGIN:
            case IMAP_AUTHENTICATE_XOAUTH2:
            case IMAP_LOGIN:
                AUTHENTICATION_FAILED(_delegate, _mechanism);
                break;

            case IMAP_CREATE:
                PERFORM_SELECTOR_1(_delegate, @selector(folderCreateFailed:), PantomimeFolderCreateFailed);
                break;

            case IMAP_DELETE:
                PERFORM_SELECTOR_1(_delegate, @selector(folderDeleteFailed:), PantomimeFolderDeleteFailed);
                break;

            case IMAP_EXPUNGE:
                PERFORM_SELECTOR_2(_delegate, @selector(folderExpungeFailed:), PantomimeFolderExpungeFailed, _selectedFolder, @"Folder");
                break;

            case IMAP_RENAME:
                PERFORM_SELECTOR_1(_delegate, @selector(folderRenameFailed:), PantomimeFolderRenameFailed);
                break;

            case IMAP_SELECT:
                _connection_state.opening_mailbox = NO;
                if (!_selectedFolder) {
                    PERFORM_SELECTOR_1(_delegate, @selector(folderOpenFailed:), PantomimeFolderOpenFailed);
                    return;
                }
                if ([_selectedFolder.name isEqualToString:PantomimeFolderNameToIgnore]) {
                    // PantomimeFolderNameToIgnore is used as a workaround to close a mailbox (aka. folder)
                    // without calling CLOSE.
                    // see RFC4549-4.2.5
                    _selectedFolder = nil;
                    PERFORM_SELECTOR_2([self delegate], @selector(folderCloseCompleted:), PantomimeFolderCloseCompleted, self, @"Folder");
                    return;
                }
                PERFORM_SELECTOR_2(_delegate, @selector(folderOpenFailed:), PantomimeFolderOpenFailed, _selectedFolder, @"Folder");
                [_openFolders removeObjectForKey: [_selectedFolder name]];
                _selectedFolder = nil;
                break;

            case IMAP_SUBSCRIBE:
                PERFORM_SELECTOR_2(_delegate, @selector(folderSubscribeFailed:), PantomimeFolderSubscribeFailed, [self.currentQueueObject.info objectForKey: @"Name"], @"Name");
                break;

            case IMAP_UID_COPY:
                PERFORM_SELECTOR_3(_delegate, @selector(messagesCopyFailed:), PantomimeMessagesCopyFailed, self.currentQueueObject.info);
                break;

            case IMAP_UID_MOVE:
                PERFORM_SELECTOR_3(_delegate, @selector(messagesCopyFailed:), PantomimeMessageUidMoveFailed, self.currentQueueObject.info);
                break;

            case IMAP_UID_SEARCH_ALL:
                PERFORM_SELECTOR_1(_delegate, @selector(folderSearchFailed:), PantomimeFolderSearchFailed);
                break;

            case IMAP_STATUS:
                PERFORM_SELECTOR_2(_delegate, @selector(folderStatusFailed:), PantomimeFolderStatusFailed, [self.currentQueueObject.info objectForKey: @"Name"], @"Name");
                break;

            case IMAP_UID_STORE:
                PERFORM_SELECTOR_3(_delegate, @selector(messageStoreFailed:), PantomimeMessageStoreFailed, self.currentQueueObject.info);
                break;

            case IMAP_UNSUBSCRIBE:
                PERFORM_SELECTOR_2(_delegate, @selector(folderUnsubscribeFailed:), PantomimeFolderUnsubscribeFailed, [self.currentQueueObject.info objectForKey: @"Name"], @"Name");
                break;

            case IMAP_AUTHORIZATION:
            case IMAP_CAPABILITY:
            case IMAP_CLOSE:
            case IMAP_EXAMINE:
            case IMAP_LIST:
            case IMAP_LOGOUT:
            case IMAP_LSUB:
            case IMAP_NOOP:
            case IMAP_STARTTLS:
            case IMAP_UID_FETCH_BODY_TEXT:
            case IMAP_UID_FETCH_HEADER_FIELDS:
            case IMAP_UID_FETCH_FLAGS:
            case IMAP_UID_FETCH_HEADER_FIELDS_NOT:
            case IMAP_UID_FETCH_RFC822:
            case IMAP_UID_SEARCH:
            case IMAP_UID_SEARCH_ANSWERED:
            case IMAP_UID_SEARCH_FLAGGED:
            case IMAP_UID_SEARCH_UNSEEN:
            case IMAP_SEARCH_NEW_MAILS:
            case IMAP_EMPTY_QUEUE: {
                id nameValue = [[[self currentQueueObject] info] objectForKey:@"Name"];
                if (nameValue) {
                    PERFORM_SELECTOR_2(_delegate, @selector(actionFailed:), PantomimeActionFailed,
                                       nameValue, @"Name");
                } else {
                    // Not all of the above commands have a name set, so fall back.
                    PERFORM_SELECTOR_1(_delegate, @selector(actionFailed:), PantomimeActionFailed);
                }
            }
                break;
            default:
                LogInfo(@"Unhandled \"NO\" response!");
                NSAssert(false, @"");
                break;
        }

        //
        // If the NO response is tagged response, we remove the current
        // queued object from the queue since it reached completion.
        //
        if (![aData hasCPrefix: "*"])//|| _lastCommand == IMAP_AUTHORIZATION)
        {
            //LogInfo(@"REMOVING QUEUE OBJECT");

            [self.currentQueueObject.info setObject: [NSNumber numberWithInt: _lastCommand]  forKey: @"Command"];
            PERFORM_SELECTOR_3(_delegate, @selector(commandCompleted:), @"PantomimeCommandCompleted", self.currentQueueObject.info);

            [_queue removeLastObject];
            [self sendCommand: IMAP_EMPTY_QUEUE  info: nil  arguments: @""];
        }

        [_responsesFromServer removeAllObjects];
    }
}


//
// After sending a NOOP to the IMAP server, we might read untagged
// responses like * 5 RECENT that will eventually be processed.
//
- (void) _parseNOOP
{
    //LogInfo(@"Parsing noop responses...");
    //!
}

//
//
//
- (void) _parseOK
{
    // Synchronize all methods that alter the _queue
    @synchronized(self) {
        NSData *aData;
        aData = [_responsesFromServer lastObject];

        //LogInfo(@"IN _parseOK: |%@|", [aData asciiString]);

        switch (_lastCommand)
        {
            case IMAP_APPEND:
                //
                // No need to do add the newly append messages to our internal messages holder as
                // we will get an untagged * EXISTS response that will trigger the new FETCH
                // RFC3501 says:
                //
                // If the mailbox is currently selected, the normal new message
                // actions SHOULD occur.  Specifically, the server SHOULD notify the
                // client immediately via an untagged EXISTS response.  If the server
                // does not do so, the client MAY issue a NOOP command (or failing
                // that, a CHECK command) after one or more APPEND commands.
                //
                PERFORM_SELECTOR_3(_delegate, @selector(folderAppendCompleted:), PantomimeFolderAppendCompleted, self.currentQueueObject.info);
                break;

            case IMAP_AUTHENTICATE_CRAM_MD5:
            case IMAP_AUTHENTICATE_LOGIN:
            case IMAP_AUTHENTICATE_XOAUTH2:
            case IMAP_LOGIN:
                if (_connection_state.reconnecting)
                {
                    if (_selectedFolder)
                    {
                        if ([_selectedFolder mode] == PantomimeReadOnlyMode)
                        {
                            [self sendCommand: IMAP_EXAMINE  info: nil  arguments: @"EXAMINE \"%@\"", [[_selectedFolder name] modifiedUTF7String]];
                        }
                        else
                        {
                            [self sendCommand: IMAP_SELECT  info: nil  arguments: @"SELECT \"%@\"", [[_selectedFolder name] modifiedUTF7String]];
                        }

                        if (_connection_state.opening_mailbox) [_selectedFolder fetch];
                    }
                    else
                    {
                        [self _restoreQueue];
                    }
                }
                else
                {
                    AUTHENTICATION_COMPLETED(_delegate, _mechanism);
                }
                break;

            case IMAP_AUTHORIZATION:
                if ([aData hasCPrefix: "* OK"])
                {
                    [self sendCommand: IMAP_CAPABILITY  info: nil  arguments: @"CAPABILITY"];
                }
                else
                {
                    //! 
                    // connectionLost? or should we call [self close]?
                }
                break;

            case IMAP_CLOSE:
                PERFORM_SELECTOR_3(_delegate, @selector(folderCloseCompleted:), PantomimeFolderCloseCompleted, self.currentQueueObject.info);
                break;

            case IMAP_CREATE:
                [_folders setObject: [NSNumber numberWithInt: 0]  forKey: [self.currentQueueObject.info objectForKey: @"Name"]];
                PERFORM_SELECTOR_1(_delegate, @selector(folderCreateCompleted:), PantomimeFolderCreateCompleted);
                break;

            case IMAP_DELETE:
                [_folders removeObjectForKey: [self.currentQueueObject.info objectForKey: @"Name"]];
                PERFORM_SELECTOR_1(_delegate, @selector(folderDeleteCompleted:), PantomimeFolderDeleteCompleted);
                break;

            case IMAP_EXPUNGE:
                PERFORM_SELECTOR_2(_delegate, @selector(folderExpungeCompleted:), PantomimeFolderExpungeCompleted, _selectedFolder, @"Folder");
                break;

            case IMAP_LIST:
                PERFORM_SELECTOR_2(_delegate, @selector(folderListCompleted:), PantomimeFolderListCompleted, [_folders keyEnumerator], @"NSEnumerator");
                break;

            case IMAP_LOGOUT:
                //!  What should we do here?
                [super close];
                break;

            case IMAP_LSUB:
                PERFORM_SELECTOR_2(_delegate, @selector(folderListSubscribedCompleted:), PantomimeFolderListSubscribedCompleted, [_subscribedFolders objectEnumerator], @"NSEnumerator");
                break;

            case IMAP_RENAME:
                [self _renameFolder];
                PERFORM_SELECTOR_1(_delegate, @selector(folderRenameCompleted:), PantomimeFolderRenameCompleted);
                break;

            case IMAP_SELECT:
                [self _parseSELECT];
                break;

            case IMAP_STARTTLS:
                [self _parseSTARTTLS];
                break;

            case IMAP_SUBSCRIBE:
                // We must add the folder to our list of subscribed folders.
                [_subscribedFolders addObject: [self.currentQueueObject.info objectForKey: @"Name"]];
                PERFORM_SELECTOR_2(_delegate, @selector(folderSubscribeCompleted:), PantomimeFolderSubscribeCompleted, [self.currentQueueObject.info objectForKey: @"Name"], @"Name");
                break;

            case IMAP_UID_COPY:
                PERFORM_SELECTOR_3(_delegate, @selector(messagesCopyCompleted:), PantomimeMessagesCopyCompleted, self.currentQueueObject.info);
                break;

            case IMAP_UID_MOVE:
                PERFORM_SELECTOR_3(_delegate, @selector(messageUidMoveCompleted:), PantomimeMessageUidMoveCompleted, self.currentQueueObject.info);
                break;

            case IMAP_UID_FETCH_RFC822:
                // fetchOlder() fetches the message for the oldest local UID to update its
                // MSN before it actually fetches older messages.
                // Thus it has to be called again after sucessfully updating the MSN.
                if ([_selectedFolder fetchOlderNeedsReCall]) {
                    [_selectedFolder fetchOlderProtected];
                    break;
                }
                // Since we download mail all in one, we signal the
                // end of fetch when all new mails have been downloadad.
                _connection_state.opening_mailbox = NO;
                if ([_selectedFolder cacheManager])
                {
                    [[_selectedFolder cacheManager] synchronize];
                }
                //LogInfo(@"DONE FETCHING FOLDER");
                PERFORM_SELECTOR_2(_delegate, @selector(folderFetchCompleted:), PantomimeFolderFetchCompleted, _selectedFolder, @"Folder");
                break;

            case IMAP_UID_FETCH_FLAGS: {
                _connection_state.opening_mailbox = NO;
                PERFORM_SELECTOR_2(_delegate, @selector(folderSyncCompleted:), PantomimeFolderSyncCompleted, _selectedFolder, @"Folder");
                break;
            }

            case IMAP_UID_FETCH_UIDS:
            case IMAP_SEARCH_NEW_MAILS: {
                _connection_state.opening_mailbox = NO;
                NSMutableDictionary *info = [NSMutableDictionary new];
                if (_selectedFolder) {
                    info[@"Folder"] = _selectedFolder;
                }
                if (self.currentQueueObject.info[@"Uids"]) {
                    info[@"Uids"] = self.currentQueueObject.info[@"Uids"];
                }
                PERFORM_SELECTOR_3(_delegate, @selector(folderFetchCompleted:), PantomimeFolderFetchCompleted, info);
                break;
            }

            case IMAP_UID_SEARCH_ALL:
                //
                // Before assuming we got a result and initialized everything in _parseSEARCH,
                // we do a basic check. This is to prevent a rather weird behavior from
                // UW IMAP Server, like this:
                //
                // . UID SEARCH ALL FROM "collaboration-world"
                // * OK [PARSE] Unexpected characters at end of address: <>, Aix.p4@itii-paca.net...
                // * SEARCH
                // 000d OK UID SEARCH completed^
                //
                if ([self.currentQueueObject.info objectForKey: @"Results"])
                {
                    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys: _selectedFolder, @"Folder", [self.currentQueueObject.info objectForKey: @"Results"], @"Results", nil];
                    PERFORM_SELECTOR_3(_delegate, @selector(folderSearchCompleted:), PantomimeFolderSearchCompleted, userInfo);
                }
                break;

            case IMAP_UID_STORE:
            {
                // Once STORE has completed, we update the messages.
                NSArray *theMessages;
                CWFlags *theFlags;
                NSUInteger i, count;

                theMessages = [self.currentQueueObject.info objectForKey: PantomimeMessagesKey];
                theFlags = [self.currentQueueObject.info objectForKey: PantomimeFlagsKey];
                count = [theMessages count];

                for (i = 0; i < count; i++)
                {
                    [[(CWMessage *) [theMessages objectAtIndex: i] flags] replaceWithFlags: theFlags];
                }

                PERFORM_SELECTOR_3(_delegate, @selector(messageStoreCompleted:), PantomimeMessageStoreCompleted, self.currentQueueObject.info);
                break;
            }

            case IMAP_UNSUBSCRIBE:
                // We must remove the folder from our list of subscribed folders.
                [_subscribedFolders removeObject: [self.currentQueueObject.info objectForKey: @"Name"]];
                PERFORM_SELECTOR_2(_delegate, @selector(folderUnsubscribeCompleted:), PantomimeFolderUnsubscribeCompleted, [self.currentQueueObject.info objectForKey: @"Name"], @"Name");
                break;

            case IMAP_IDLE_DONE:
                PERFORM_SELECTOR_1(_delegate, @selector(idleFinished:), PantomimeIdleFinished);
                break;

            default:
                break;
        }

        //
        // If the OK response is tagged response, we remove the current
        // queued object from the queue since it reached completion.
        //
        if (![aData hasCPrefix: "*"])// || _lastCommand == IMAP_AUTHORIZATION)
        {
            //LogInfo(@"REMOVING QUEUE OBJECT");
            if (self.currentQueueObject && self.currentQueueObject.info) {
                [self.currentQueueObject.info
                 setObject: [NSNumber numberWithInt: _lastCommand]  forKey: @"Command"];
                PERFORM_SELECTOR_3(_delegate, @selector(commandCompleted:), @"PantomimeCommandCompleted", self.currentQueueObject.info);
            } else {
                LogInfo(@"self.currentQueueObject == nil");
            }

            [_queue removeLastObject];
            [self sendCommand: IMAP_EMPTY_QUEUE  info: nil  arguments: @""];
        }

        [_responsesFromServer removeAllObjects];
    }
}


//
// This method receives a * 5 RECENT parameter and parses it.
//
- (void) _parseRECENT
{
    // Do nothing for now. This breaks 7.3.2 since the response
    // is not recorded.
}


//
//
//
- (void) _parseSEARCH_NewMails
{
    // Note: The method call implies UID, but it doesn't really care if it's UIDs or sequence IDs.
    NSArray *allResults = [self _uniqueIdentifiersFromSearchResponseData:[_responsesFromServer lastObject]];

    // We store the results in our command queue (ie., in the current queue object).
    if (self.currentQueueObject)
        [self.currentQueueObject.info setObject: allResults  forKey: @"Uids"];
}

//
//
//
- (void) _parseSEARCH
{
    NSMutableArray *aMutableArray;
    CWIMAPMessage *aMessage;
    NSArray *allResults;
    NSUInteger i, count;

    allResults = [self _uniqueIdentifiersFromSearchResponseData:[_responsesFromServer lastObject]];
    count = [allResults count];

    aMutableArray = [NSMutableArray array];


    for (i = 0; i < count; i++)
    {
        aMessage = [[_selectedFolder cacheManager] messageWithUID:
                    [[allResults objectAtIndex: i] unsignedIntValue]];

        if (aMessage)
        {
            [aMutableArray addObject: aMessage];
        }
        else
        {
            //LogInfo(@"Message with UID = %u not found in cache.",
            //[[allResults objectAtIndex: i] unsignedIntValue]);
        }
    }

    // We store the results in our command queue (ie., in the current queue object).
    // aMutableArray may be empty if no result was found
    if (self.currentQueueObject)
        [self.currentQueueObject.info setObject: aMutableArray  forKey: @"Results"];
}


//
// This methods updates all FLAGS and MSNs for messages in the cache.
//
// It also purges the messages that have been deleted on the IMAP server
// but that are still present in the folder cache.
//
// Nota bene: We can safely assume our cacheManager exists since this method
//            wouldn't otherwise have been invoked.
//
//
- (void) _parseSEARCH_CACHE
{
    CWIMAPMessage *aMessage;
    NSArray *allResults;
    NSInteger i, count;
    BOOL b;

    allResults =
    [self _uniqueIdentifiersFromSearchResponseData:[_responsesFromServer objectAtIndex: 0]];
    count = [allResults count];

    switch (_lastCommand)
    {
        case IMAP_UID_SEARCH:
            //
            // We can now read our SEARCH results from our IMAP store. The result contains
            // all MSN->UID mappings. New messages weren't added to the search result as
            // we couldn't find them in IMAPStore: -_parseSearch:.
            //
            for (i = 0; i < count; i++)
            {
                aMessage = [[_selectedFolder cacheManager] messageWithUID: [[allResults objectAtIndex: i] unsignedIntValue]];

                if (aMessage)
                {
                    [aMessage setFolder: _selectedFolder];
                    [aMessage setMessageNumber: (i+1)];
                }
            }

            //
            // We purge our cache from all deleted messages and we keep the
            // good ones to our folder.
            //
            //for (i = ([theCache count]-1); i >= 0; i--)
            //LogInfo(@"Folder count (to remove UID) = %d", [_selectedFolder->allMessages count]);
            b = NO;

            for (i = ([_selectedFolder count]-1); i >= 0; i--)
            {
                aMessage = (CWIMAPMessage *) [_selectedFolder messageAtIndex: i];
                //aMessage = [theCache objectAtIndex: i];

                if ([aMessage folder] == nil)
                {
                    [[_selectedFolder cacheManager] removeMessageWithUID: [aMessage UID]];
                    //LogInfo(@"Removed message |%@| UID = %d", [aMessage subject], [aMessage UID]);
                    [_selectedFolder removeMessage: aMessage];
                    b = YES;
                }

            }

            // We check to see if we must expunge deleted messages from our cache.
            // It's important to do this here. Otherwise, calling -synchronize on
            // our cache manager could lead to offset problems as the number of
            // records in our cache would be greater than the amount of entries
            // in our _selectedFolder->allMessages ivar.
            if (b && [_selectedFolder cacheManager])
            {
                [[_selectedFolder cacheManager] expunge];
            }

            [_selectedFolder updateCache];
            [self sendCommand: IMAP_UID_SEARCH_ANSWERED  info: nil  arguments: @"UID SEARCH ANSWERED"];
            break;

        case IMAP_UID_SEARCH_ANSWERED:
            //
            // We now update our \Answered flag, for all messages.
            //
            for (i = 0; i < count; i++)
            {
                [[[[_selectedFolder cacheManager] messageWithUID: [[allResults objectAtIndex: i] unsignedIntValue]] flags] add: PantomimeFlagAnswered];
            }
            [self sendCommand: IMAP_UID_SEARCH_FLAGGED  info: nil  arguments: @"UID SEARCH FLAGGED"];
            break;

        case IMAP_UID_SEARCH_FLAGGED:
            //
            // We now update our \Flagged flag, for all messages.
            //
            for (i = 0; i < count; i++)
            {
                [[[[_selectedFolder cacheManager] messageWithUID: [[allResults objectAtIndex: i] unsignedIntValue]] flags] add: PantomimeFlagFlagged];
            }
            [self sendCommand: IMAP_UID_SEARCH_UNSEEN  info: nil  arguments: @"UID SEARCH UNSEEN"];
            break;

        case IMAP_UID_SEARCH_UNSEEN:
            //
            // We now update our \Seen flag, for all messages.
            //
            for (i = 0; i < count; i++)
            {
                //LogInfo(@"removing for UID %d", [[allResults objectAtIndex: i] unsignedIntValue]);
                [[[[_selectedFolder cacheManager] messageWithUID: [[allResults objectAtIndex: i] unsignedIntValue]] flags] remove: PantomimeFlagSeen];
            }
            break;

        default:
            //LogInfo(@"Unknown command for updating the cache file. Ignored.");
            break;
    }
}


//
//
//
- (void) _parseSELECT
{
    NSData *aData;
    NSUInteger i, count;

    if ([_selectedFolder.name isEqualToString:PantomimeFolderNameToIgnore]) {
        // PantomimeFolderNameToIgnore is used as a workaround to close a mailbox (aka. folder)
        // without calling CLOSE.
        // see RFC4549-4.2.5
        _selectedFolder = nil;
        PERFORM_SELECTOR_2([self delegate], @selector(folderCloseCompleted:), PantomimeFolderCloseCompleted, self, @"Folder");
        return;
    }

    // The last object in _responsesFromServer is a tagged OK response.
    // We need to parse it here.
    count = [_responsesFromServer count];

    for (i = 0; i < count; i++)
    {
        aData = [[_responsesFromServer objectAtIndex: i] dataByTrimmingWhiteSpaces];

        //LogInfo(@"|%@|", [aData asciiString]);
        // * OK [UIDVALIDITY 1052146864]
        if ([aData hasCPrefix: "* OK [UIDVALIDITY"])
        {
            [self _parseUIDVALIDITY: [aData cString]];
        }

        // S: * OK [UIDNEXT 4392] Predicted next UID
        if ([aData hasCPrefix: "* OK [UIDNEXT"])
        {
            [self _parseUIDNEXT: [aData cString]];
        }

        // 3c4d OK [READ-ONLY] Completed
        if ([aData rangeOfCString: "OK [READ-ONLY]"].length)
        {
            [_selectedFolder setMode: PantomimeReadOnlyMode];
        }

        // 1a2b OK [READ-WRITE] Completed
        if ([aData rangeOfCString: "OK [READ-WRITE]"].length)
        {
            [_selectedFolder setMode: PantomimeReadWriteMode];
        }
    }

    if (_connection_state.reconnecting)
    {
        [self _restoreQueue];
    }
    else
    {
        [_selectedFolder setSelected: YES];
        if (_selectedFolder) {
            PERFORM_SELECTOR_2(_delegate, @selector(folderOpenCompleted:), PantomimeFolderOpenCompleted, _selectedFolder, @"Folder");
        } else {
            PERFORM_SELECTOR_1(_delegate, @selector(folderOpenCompleted:), PantomimeFolderOpenCompleted);
        }
    }
}


//
//
//
- (void) _parseSTARTTLS
{
    [(id<CWConnection>)_connection startTLS];
    PERFORM_SELECTOR_1(_delegate, @selector(serviceInitialized:),  PantomimeServiceInitialized);
}

//
//
// This method receives a * STATUS blurdybloop (MESSAGES 231 UIDNEXT 44292)
// parameter and parses it. It then put the decoded values in the
// folderStatus dictionary.
//
//
- (void) _parseSTATUS
{
    CWFolderInformation *aFolderInformation;
    NSString *aFolderName;
    NSDictionary *info;
    NSData *aData;

    NSRange aRange;
    int messages, unseen;

    aData = [_responsesFromServer lastObject];

    aRange = [aData rangeOfCString: "("  options: NSBackwardsSearch];
    aFolderName = [[[aData subdataToIndex: (aRange.location-1)] subdataFromIndex: 9] asciiString];

    sscanf([[aData subdataFromIndex: aRange.location] cString], "(MESSAGES %d UNSEEN %d)", &messages, &unseen);

    aFolderInformation = [[CWFolderInformation alloc] init];
    [aFolderInformation setNbOfMessages: messages];
    [aFolderInformation setNbOfUnreadMessages: unseen];
    
    // Before putting the folder in our dictionary, we unquote it.
    aFolderName = [aFolderName stringFromQuotedString];
    [_folderStatus setObject: aFolderInformation  forKey: aFolderName];
    
    info = [NSDictionary dictionaryWithObjectsAndKeys: aFolderInformation, @"FolderInformation", aFolderName, @"FolderName", nil];
    
    if (_delegate && [_delegate respondsToSelector: @selector(folderStatusCompleted:)]) 
    {
        [_delegate performSelector: @selector(folderStatusCompleted:)
                        withObject: [NSNotification notificationWithName: PantomimeFolderStatusCompleted
                                                                  object: self
                                                                userInfo: info]];
    }
    
    RELEASE(aFolderInformation);
}


//
// Example: * OK [UIDVALIDITY 948394385]
//
- (void) _parseUIDVALIDITY: (const char *) theString
{
    unsigned int n;
    sscanf(theString, "* OK [UIDVALIDITY %u]", &n);
    [_selectedFolder setUIDValidity: n];
}

- (void) _parseUIDNEXT: (const char *) theString
{
    unsigned int n;
    sscanf(theString, "* OK [UIDNEXT %u]", &n);
    [_selectedFolder setNextUID:n];
}


//
//
//
- (void) _restoreQueue
{
    // Synchronize all methods that alter the _queue
    @synchronized(self) {
        // We restore our list of pending commands
        [_queue addObjectsFromArray: _connection_state.previous_queue];

        // We clean the state
        [_connection_state.previous_queue removeAllObjects];
        _connection_state.reconnecting = NO;

        PERFORM_SELECTOR_1(_delegate, @selector(serviceReconnected:), PantomimeServiceReconnected);
    }
}

@end

@implementation CWMessageUpdate

+ (instancetype _Nonnull)newComplete
{
    CWMessageUpdate *msgUpdate = [CWMessageUpdate new];
    
    msgUpdate.bodyHeader = true;
    msgUpdate.bodyText = true;
    msgUpdate.flags = true;
    msgUpdate.rfc822 = true;
    msgUpdate.rfc822Size = true;
    msgUpdate.uid = true;
    msgUpdate.msn = true;
    
    return msgUpdate;
}

- (BOOL)isMsnOnly
{
    // intentionally ignores UID changes
    return self.msn && !self.flags && !self.bodyHeader && !self.bodyText &&
    !self.rfc822 && !self.rfc822Size;
}

- (BOOL)isFlagsOnly
{
    // intentionally ignores UID and MSN changes
    return self.flags && !self.bodyHeader && !self.bodyText &&
    !self.rfc822 && !self.rfc822Size;
}

- (BOOL)isNoChange
{
    // intentionally ignores UID
    return !self.flags && !self.bodyHeader && !self.bodyText &&
    !self.rfc822 && !self.rfc822Size && !self.msn;
}

- (NSString *)description
{
    return [NSString stringWithFormat:
            @"<CWMessageUpdate: 0x%x flags %d bodyHeader %d bodyText %d rfc822 %d rfc822Size %d uid %d msn %d>",
            (uint) self, self.flags, self.bodyHeader, self.bodyText, self.rfc822, self.rfc822Size,
            self.uid, self.msn];
}

@end
