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
- (CWIMAPFolder *) folderForName: (NSString *) theName
                          select: (BOOL) aBOOL
{
    if ([_openFolders objectForKey: theName])
    {
        return [_openFolders objectForKey: theName];
    }

    if (aBOOL)
    {
        return [self folderForName: theName];
    }
    else
    {
        CWIMAPFolder *aFolder;

        aFolder = [self folderWithName:theName];

        [aFolder setStore: self];
        [aFolder setSelected: NO];
        return AUTORELEASE(aFolder);
    }
}


//
//
//
- (CWIMAPFolder *)folderWithName:(NSString *)name
{
    if (self.folderBuilder) {
        CWFolder *folder = [self.folderBuilder folderWithName:name];
        return (CWIMAPFolder *) folder;
    } else {
        return [[CWIMAPFolder alloc] initWithName:name];
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
                INFO(NSStringFromClass([self class]), @"sendCommand currentQueueObject = nil");
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
                    //INFO(NSStringFromClass([self class]), @"A COMMAND ALREADY EXIST!!!!");
                    return;
                }
            }
            
            CWIMAPQueueObject *aQueueObject = [[CWIMAPQueueObject alloc]
                                               initWithCommand: theCommand  arguments: theString
                                               tag: [self nextTag]  info: theInfo];
            
            [_queue insertObject: aQueueObject  atIndex: 0];
            RELEASE(aQueueObject);
            
            INFO(NSStringFromClass([self class]), @"queue size = %lul", (unsigned long) [_queue count]);
            
            // If we had queued commands, we return since we'll eventually
            // dequeue them one by one. Otherwise, we run it immediately.
            if ([_queue count] > 1)
            {
                //INFO(NSStringFromClass([self class]), @"QUEUED |%@|", theString);
                return;
            }
            
            self.currentQueueObject = aQueueObject;
        }
        
        BOOL isPrivate = NO;
        if (self.currentQueueObject.command == IMAP_LOGIN) {
            isPrivate = YES;
        }
        
        if (isPrivate) {
            INFO(NSStringFromClass([self class]), @"Sending private data |*******|");
        } else {
            INFO(NSStringFromClass([self class]), @"Sending |%@|", self.currentQueueObject.arguments);
        }
        
        _lastCommand = self.currentQueueObject.command;
        
        [self bulkWriteData:@[self.currentQueueObject.tag,
                              [NSData dataWithBytes: " "  length: 1],
                              [self.currentQueueObject.arguments dataUsingEncoding: _defaultCStringEncoding],
                              _crlf]];
        
        POST_NOTIFICATION(@"PantomimeCommandSent", self, self.currentQueueObject.info);
        PERFORM_SELECTOR_2(_delegate, @selector(commandSent:), @"PantomimeCommandSent", [NSNumber numberWithInt: _lastCommand], @"Command");
    }
}


//
//
//
#warning VERIFY FOR NoSelect
- (CWIMAPFolder *) folderForNameInternal: (NSString *) theName
                                    mode: (PantomimeFolderMode) theMode
{
        CWIMAPFolder *aFolder = [_openFolders objectForKey: theName];

        if (aFolder) {
            if ([_selectedFolder.name isEqualToString:theName]) {
                return aFolder;
            }
        } else {
            aFolder = [self folderWithName:theName];
            [_openFolders setObject: aFolder  forKey: theName];
            RELEASE(aFolder);
        }

        [aFolder setStore: self];
        aFolder.mode = theMode;

        //INFO(NSStringFromClass([self class]), @"_connection_state.opening_mailbox = %d", _connection_state.opening_mailbox);

        // If we are already opening a mailbox, we must interrupt the process
        // and open the preferred one instead.
        if (_connection_state.opening_mailbox)
        {
            // Safety measure - in case close (so -removeFolderFromOpenFolders)
            // on the selected folder wasn't called.
            if (_selectedFolder)
            {
                [_openFolders removeObjectForKey: [_selectedFolder name]];
            }

            [super cancelRequest];
            [self reconnect];

            _selectedFolder = aFolder;
            return _selectedFolder;
        }

        _connection_state.opening_mailbox = YES;

        if (theMode == PantomimeReadOnlyMode)
        {
            [self sendCommand: IMAP_EXAMINE  info: nil  arguments: @"EXAMINE \"%@\"", [theName modifiedUTF7String]];
        }
        else
        {
            [self sendCommand: IMAP_SELECT  info: nil  arguments: @"SELECT \"%@\"", [theName modifiedUTF7String]];
        }

        // This folder becomes the selected one. This will have to be improved in the future.
        // No need to retain "aFolder" here. The "_openFolders" dictionary already retains it.
        _selectedFolder = aFolder;
        return _selectedFolder;
}


//
//
//
- (void)signalFolderSyncError
{
    POST_NOTIFICATION(PantomimeFolderSyncFailed, self,
                      [NSDictionary dictionaryWithObject: _selectedFolder  forKey: @"Folder"]);
    PERFORM_SELECTOR_2(_delegate, @selector(folderSyncFailed:),
                       PantomimeFolderSyncFailed, _selectedFolder, @"Folder");
}


//
//
//
- (void)signalFolderFetchCompleted
{
    //INFO(NSStringFromClass([self class]), @"DONE PREFETCHING FOLDER");
    POST_NOTIFICATION(PantomimeFolderFetchCompleted,
                      self,
                      [NSDictionary dictionaryWithObject: _selectedFolder  forKey: @"Folder"]);
    PERFORM_SELECTOR_2(_delegate,
                       @selector(folderFetchCompleted:),
                       PantomimeFolderFetchCompleted, _selectedFolder, @"Folder");
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
    INFO(NSStringFromClass([self class]), @"CWIMAPQueueObject.init %@\n", self);
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
- (void) dealloc
{
    INFO(NSStringFromClass([self class]), @"dealloc %@\n", self);
    INFO(NSStringFromClass([self class]), @"dealloc done");
    RELEASE(arguments);
    RELEASE(info);
    RELEASE(tag);
    //[super dealloc];
}


//
//
//
- (NSString *) description
{
    return [NSString stringWithFormat: @"%d %@", self.command, self.arguments];
}

@end
