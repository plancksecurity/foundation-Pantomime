//
//  CWIMAPStore+Protected.m
//  Pantomime
//
//  Created by Andreas Buff on 05.09.17.
//  Copyright © 2017 pEp Security S.A. All rights reserved.
//

#import "CWIMAPStore+Protected.h"

#import "CWIMAPFolder.h"
#import "Pantomime/NSString+Extensions.h"
#import "CWThreadSafeArray.h"

#import <pEpIOSToolboxForExtensions/PEPLogger.h>

@implementation CWIMAPStore (Protected)

//
//
//
- (CWIMAPQueueObject * _Nullable)currentQueueObject
{
    @synchronized (self) {
        return _currentQueueObject;
    }
}


//
//
//
- (void)setCurrentQueueObject:(CWIMAPQueueObject * _Nullable)currentQueueObject
{
    @synchronized (self) {
        if (_currentQueueObject != currentQueueObject) {
            _currentQueueObject = currentQueueObject;
        }
    }
}


//
//
//
- (NSData *) nextTag
{
    _tag++;
    return [self lastTag];
}


//
//
//
- (NSData *) lastTag
{
    char str[5];
    sprintf(str, "%04x", _tag);
    return [NSData dataWithBytes: str  length: 4];
}


//
//
//
- (void) subscribeToFolderWithName: (NSString *) theName
{
    [self sendCommand: IMAP_SUBSCRIBE
                 info: [NSDictionary dictionaryWithObject: theName  forKey: @"Name"]
            arguments: @"SUBSCRIBE \"%@\"", [theName modifiedUTF7String]];
}


//
//
//
- (void) unsubscribeToFolderWithName: (NSString *) theName
{
    [self sendCommand: IMAP_UNSUBSCRIBE
                 info: [NSDictionary dictionaryWithObject: theName  forKey: @"Name"]
            arguments: @"UNSUBSCRIBE \"%@\"", [theName modifiedUTF7String]];
}


//
//
//
- (NSDictionary *) folderStatus: (NSArray *) theArray
{
    int i;

    [_folderStatus removeAllObjects];

    // C: A042 STATUS blurdybloop (UIDNEXT MESSAGES)
    // S: * STATUS blurdybloop (MESSAGES 231 UIDNEXT 44292)
    // S: A042 OK STATUS completed
    //
    // We send: MESSAGES UNSEEN
    for (i = 0; i < [theArray count]; i++)
    {
        // RFC3501 says we SHOULD NOT call STATUS on the selected mailbox - so we won't do it.
        if (_selectedFolder && [[_selectedFolder name] isEqualToString: [theArray objectAtIndex: i]])
        {
            continue;
        }

        [self sendCommand: IMAP_STATUS
                     info: [NSDictionary dictionaryWithObject: [theArray objectAtIndex: i]  forKey: @"Name"]
                arguments: @"STATUS \"%@\" (MESSAGES UNSEEN)", [[theArray objectAtIndex: i] modifiedUTF7String]];
    }

    return _folderStatus;
}


//
//
//
- (void) sendCommand: (IMAPCommand) theCommand  info: (NSDictionary *) theInfo  arguments: (NSString *) theFormat, ...
{
    va_list args;

    va_start(args, theFormat);
    NSString *aString = [[NSString alloc] initWithFormat: theFormat  arguments: args];
    [self sendCommandInternal:theCommand info:theInfo string:aString];
}


//
//
//
- (void) sendCommandInternal: (IMAPCommand) theCommand  info: (NSDictionary * _Nullable) theInfo
                      string:(NSString * _Nonnull)theString
{
    // If two calls to this method happen concurrently, one might empty the queue the other is
    // currenly using (causes |SENDING null|).
    @synchronized(self) {
        if (theCommand == IMAP_EMPTY_QUEUE)
        {
            if ([_queue count])
            {
                // We dequeue the first inserted command from the queue.
                self.currentQueueObject = [_queue lastObject];
            }
            else
            {
                // The queue is empty, we have nothing more to do...
                LogInfo(@"sendCommand currentQueueObject = nil");
                self.currentQueueObject = nil;
                return;
            }
        }
        else
        {
            //
            // We must check in the queue if we aren't trying to add a command that is already there.
            // This could happend if -rawSource is called in IMAPMessage multiple times before
            // PantomimeMessageFetchCompleted is sent.
            //
            // We skip this verification for the IMAP_APPEND command as a messages with the same size
            // could be quickly appended to the folder and we do NOT want to skip the second one.
            //
            for (CWIMAPQueueObject *aQueueObject in _queue) {
                if (aQueueObject.command == theCommand && theCommand != IMAP_APPEND &&
                    [aQueueObject.arguments isEqualToString: theString])
                {
                    //LogInfo(@"A COMMAND ALREADY EXIST!!!!");
                    return;
                }
            }
            
            CWIMAPQueueObject *aQueueObject = [[CWIMAPQueueObject alloc]
                                               initWithCommand: theCommand  arguments: theString
                                               tag: [self nextTag]  info: theInfo];
            
            [_queue insertObject: aQueueObject  atIndex: 0];
            RELEASE(aQueueObject);
            
            LogInfo(@"%p queue size = %lul", self, (unsigned long) [_queue count]);
            
            // If we had queued commands, we return since we'll eventually
            // dequeue them one by one. Otherwise, we run it immediately.
            if ([_queue count] > 1)
            {
                //LogInfo(@"%p QUEUED |%@|", self, theString);
                return;
            }
            
            self.currentQueueObject = aQueueObject;
        }
        
        BOOL isPrivate = NO;
        if (self.currentQueueObject.command == IMAP_LOGIN) {
            isPrivate = YES;
        }
        
        if (isPrivate) {
            LogInfo(@"%p Sending private data |*******|", self);
        } else {
            LogInfo(@"%p Sending |%@|", self, self.currentQueueObject.arguments);
        }
        
        _lastCommand = self.currentQueueObject.command;
        
        [self bulkWriteData:@[self.currentQueueObject.tag,
                              [NSData dataWithBytes: " "  length: 1],
                              [self.currentQueueObject.arguments dataUsingEncoding: _defaultStringEncoding],
                              _crlf]];

        PERFORM_SELECTOR_2(_delegate, @selector(commandSent:), @"PantomimeCommandSent", [NSNumber numberWithInt: _lastCommand], @"Command");
    }
}

- (CWIMAPFolder *)folderForNameInternal:(NSString *)name
                                   mode:(PantomimeFolderMode)mode
                      updateExistsCount:(BOOL)updateExistsCount
{
    CWIMAPFolder *folder = [_openFolders objectForKey:name];

    LogInfo(@"select folder %@", name);
    if (folder) {
        if ([_selectedFolder.name isEqualToString:name]) {
            // We have the folder already and it is already selected.
            if (!updateExistsCount) {
                // Return it in case exists count is not of interest ...
                return folder;
            }
            // ... otherwize update exists count by calling SELECT/EXAMINE.
        }
    } else {
        folder = [self folderWithName:name];
        [_openFolders setObject:folder  forKey:name];
    }

    [folder setStore:self];
    folder.mode = mode;

    //LogInfo(@"_connection_state.opening_mailbox = %d", _connection_state.opening_mailbox);

    // If we are already opening a mailbox, we must interrupt the process
    // and open the preferred one instead.
    if (_connection_state.opening_mailbox) {
        // Safety measure - in case close (so -removeFolderFromOpenFolders)
        // on the selected folder wasn't called.
        if (_selectedFolder) {
            [_openFolders removeObjectForKey:[_selectedFolder name]];
        }

        [super cancelRequest];
        [self reconnect];

        _selectedFolder = folder;
        return _selectedFolder;
    }

    _connection_state.opening_mailbox = YES;

    if (mode == PantomimeReadOnlyMode) {
        [self sendCommand:IMAP_EXAMINE  info:nil  arguments:@"EXAMINE \"%@\"", [name modifiedUTF7String]];
    } else {
        [self sendCommand:IMAP_SELECT  info:nil  arguments:@"SELECT \"%@\"", [name modifiedUTF7String]];
    }

    // This folder becomes the selected one. This will have to be improved in the future.
    _selectedFolder = folder;
    return _selectedFolder;
}


//
//
//
- (void)signalFolderSyncError
{
    PERFORM_SELECTOR_2(_delegate, @selector(folderSyncFailed:),
                       PantomimeFolderSyncFailed, _selectedFolder, @"Folder");
}


//
//
//
- (void)signalFolderFetchCompleted
{
    //LogInfo(@"DONE PREFETCHING FOLDER");
    NSMutableDictionary *info = [NSMutableDictionary new];
    if (_selectedFolder) {
        info[@"Folder"] = _selectedFolder;
    }
    PERFORM_SELECTOR_3(_delegate,
                       @selector(folderFetchCompleted:),
                       PantomimeFolderFetchCompleted,
                       info);
}

@end

@implementation CWIMAPQueueObject

//
//
//
- (id) initWithCommand: (IMAPCommand) theCommand
             arguments: (NSString *) theArguments
                   tag: (NSData *) theTag
                  info: (NSDictionary *) theInfo
{
    self = [super init];

    //LogInfo(@"CWIMAPQueueObject.init %@\n", self);
    _command = theCommand;
    _literal = 0;

    ASSIGN(_arguments, theArguments);
    ASSIGN(_tag, theTag);

    if (theInfo)
    {
        _info = [[NSMutableDictionary alloc] initWithDictionary: theInfo];
    }
    else
    {
        _info = [[NSMutableDictionary alloc] init];
    }

    return self;
}

//
//
//
- (NSString *) description
{
    if (self.command == IMAP_LOGIN || self.command == IMAP_AUTHENTICATE_LOGIN) {
        // Arguments might hold passwords.
        return [NSString stringWithFormat: @"%d (IMAP_LOGIN or IMAP_AUTHENTICATE_LOGIN)", self.command];
    }
    return [NSString stringWithFormat: @"%d %@", self.command, self.arguments];
}

@end
