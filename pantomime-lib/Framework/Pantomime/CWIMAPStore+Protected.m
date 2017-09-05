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

@implementation CWIMAPStore (Protected)

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


- (void) sendCommand: (IMAPCommand) theCommand  info: (NSDictionary *) theInfo  arguments: (NSString *) theFormat, ...
{
    va_list args;

    va_start(args, theFormat);
    NSString *aString = [[NSString alloc] initWithFormat: theFormat  arguments: args];
    [self sendCommand:theCommand info:theInfo string:aString];
}

- (void)signalFolderSyncError
{
    POST_NOTIFICATION(PantomimeFolderSyncFailed, self,
                      [NSDictionary dictionaryWithObject: _selectedFolder  forKey: @"Folder"]);
    PERFORM_SELECTOR_2(_delegate, @selector(folderSyncFailed:),
                       PantomimeFolderSyncFailed, _selectedFolder, @"Folder");
}

@end
