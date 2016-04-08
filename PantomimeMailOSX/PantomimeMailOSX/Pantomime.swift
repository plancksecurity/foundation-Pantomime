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
    var folderNames: [String] = []
    var folderNamesPrefetched: Set<String> = []

    func haveFoldersToPrefetch() -> Bool {
        return folderNamesPrefetched.count < folderNames.count
    }
}

public class Pantomime {

    let testData: TestData = TestData()
    var imapStore: CWIMAPStore
    var imapState = ImapState()
    var cache = CacheManager()

    init() {
        imapStore = CWIMAPStore.init(name: testData.imapServer, port: testData.imapPort)
    }

    deinit {
    }

    func startPantomime() {
        startIMAP()
    }

    func startIMAP() {
        imapStore.setDelegate(self)
        imapStore.connectInBackgroundAndNotify()
    }

    func prefetchFolderByName(folderName: String) {
        if let folder = (imapStore.folderForName(folderName, mode: PantomimeReadWriteMode,
            prefetch: false)) {
            print("prefetchFolderByName \(folder.name())")
            folder.setCacheManager(cache)
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

    func prefetchNextFolder() {
        for folderName in imapState.folderNames {
            if !imapState.folderNamesPrefetched.contains(folderName) {
                prefetchFolderByName(folderName)
                break
            }
        }
    }

    @objc func handleFolders(timer: NSTimer) {
        if let folderEnum = imapStore.folderEnumerator() {
            timer.invalidate()
            imapState.folderNames = []
            imapState.folderNamesPrefetched = []
            for folder in folderEnum {
                let folderName = folder as! String
                imapState.folderNames.append(folderName)
            }
            print("IMAP folders: \(imapState.folderNames)")
            prefetchNextFolder()
        }
    }

    /**
     Triggered by a time after authentication completes, have to wait
     for folders to appear.
     */
    func waitForFolders() {
        let timer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self,
                                                           selector: #selector(handleFolders),
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
            if imapState.haveFoldersToPrefetch() {
                imapState.folderNamesPrefetched.insert(folder.name())
                prefetchNextFolder()
            }
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

extension Pantomime: PantomimeFolderDelegate {
    @objc public func folderOpenCompleted(notification: NSNotification!) {
        if let folder: CWFolder = (notification.userInfo?["Folder"] as! CWFolder) {
            print("folderOpenCompleted: \(folder.name())")
            if imapState.haveFoldersToPrefetch() {
                imapState.folderNamesPrefetched.insert(folder.name())
                prefetchNextFolder()
            }
        } else {
            print("folderOpenCompleted: \(notification)")
        }
    }
}
