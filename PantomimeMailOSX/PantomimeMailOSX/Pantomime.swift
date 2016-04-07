//
//  Pantomime.swift
//  PantomimeMailOSX
//
//  Created by Dirk Zimmermann on 05/04/16.
//  Copyright © 2016 pEp Security S.A. All rights reserved.
//

import Foundation

struct ImapState {
    var authenticationCompleted: Bool = false
    var folders: [String]?
}

public class Pantomime {

    let testData: TestData = TestData()
    var imapStore: CWIMAPStore
    var imapState = ImapState()
    var subscriptionObserver: NSObjectProtocol!

    init() {
        imapStore = CWIMAPStore.init(name: testData.imapServer, port: testData.imapPort)
        subscriptionObserver = NSNotificationCenter.defaultCenter()
            .addObserverForName(PantomimeFolderSubscribeCompleted,
                                object: imapStore, queue: nil,
                                usingBlock: { [weak self] notification in
                                    print("folder subscribed: \(notification)")
                                    if let strongSelf = self {
                                        if let folderName = notification.userInfo?["Name"] {
                                            strongSelf.prefetchFolder(folderName as! String)
                                        }
                                    }
            })
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(subscriptionObserver)
    }

    func startPantomime() {
        startIMAP()
    }

    func startIMAP() {
        imapStore.setDelegate(self)
        imapStore.connectInBackgroundAndNotify()
    }

    func prefetchFolder(folderName: String) {
        if let folder = (imapStore.folderForName(folderName) as! CWIMAPFolder?) {
            folder.prefetch()
        }
    }

    func listMessages(folderName: String) {
        print("lisMessages: \(folderName)")
        let folder = imapStore.folderForName(folderName) as! CWFolder
        let messages = folder.allMessages() as! [CWMessage]
        for msg in messages {
            print("\(folderName): \(msg)")
        }

    }

    @objc func listAndSubscribeFolders(timer: NSTimer) {
        if let folderEnum = imapStore.folderEnumerator() {
            timer.invalidate()
            imapState.folders = []
            for folder in folderEnum {
                imapState.folders?.append(folder as! String)
            }
            print("IMAP folders: \(imapState.folders)")
            subscribeFolderNames(imapState.folders!)
        }
    }

    func subscribeFolderNames(folders: [String]) {
        for folderName in folders {
            imapStore.subscribeToFolderWithName(folderName)
        }
    }

    func waitForFolders() {
        let timer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self,
                                                           selector: #selector(listAndSubscribeFolders),
                                                           userInfo: nil, repeats: true)
        timer.fire()
    }
}

extension Pantomime: CWServiceClient {
    @objc public func authenticationCompleted(notification: NSNotification) {
        imapState.authenticationCompleted = true
        print("authenticationCompleted")
        if let capabilities = imapStore.capabilities() {
            print("capabilities: \(capabilities)")
        }
        waitForFolders()
    }

    @objc public func authenticationFailed(notification: NSNotification) {
    }

    @objc public func connectionEstablished(notification: NSNotification) {
    }

    @objc public func connectionLost(notification: NSNotification) {
    }

    @objc public func connectionTerminated(notification: NSNotification) {
    }

    @objc public func connectionTimedOut(notification: NSNotification) {
    }

    @objc public func folderPrefetchCompleted(notification: NSNotification) {
        if let folder: CWFolder = (notification.userInfo?["Folder"] as! CWFolder) {
            print("prefetched folder: \(folder.name())")
        } else {
            print("folderPrefetchCompleted: \(notification)")
        }
    }

    @objc public func messagePrefetchCompleted(notification: NSNotification) {
    }

    @objc public func serviceInitialized(notification: NSNotification) {
        imapStore.authenticate(testData.imapUser, password: testData.imapPassword,
                               mechanism: testData.imapAuthMethod)
    }

    @objc public func serviceReconnected(theNotification: NSNotification!) {
    }

    @objc public func service(theService: CWService!, sentData theData: NSData!) {
    }

    @objc public func service(theService: CWService!, receivedData theData: NSData!) {
    }

    @objc public func messageChanged(notification: NSNotification) {
    }
}
