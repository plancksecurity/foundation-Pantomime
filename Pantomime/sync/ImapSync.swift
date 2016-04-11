//
//  ImapSync
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

public class ImapSync {
    let comp = "ImapSync"

    let connectInfo: ConnectInfo
    var imapStore: CWIMAPStore
    var imapState = ImapState()
    var cache = CacheManager()

    init(connectInfo: ConnectInfo) {
        self.connectInfo = connectInfo
        imapStore = CWIMAPStore.init(name: connectInfo.imapServerName,
                                     port: connectInfo.imapServerPort,
                                     transport: connectInfo.imapTransport)
        imapStore.setDelegate(self)
    }

    deinit {
    }

    func start() {
        imapStore.connectInBackgroundAndNotify()
    }

    func prefetchFolderByName(folderName: String) {
        if let folder = (imapStore.folderForName(folderName, mode: PantomimeReadWriteMode,
            prefetch: false)) {
            Log.info(comp, content: "prefetchFolderByName \(folder.name())")
            folder.setCacheManager(cache)
            folder.prefetch()
        }
    }

    func listMessages(folderName: String) {
        Log.info(comp, content: "listMessages: \(folderName)")
        let folder = imapStore.folderForName(folderName) as! CWFolder
        let messages = folder.allMessages() as! [CWMessage]
        for msg in messages {
            Log.info(comp, content: "\(folderName): \(msg)")
        }

    }

    func checkPrefetchNextFolderAndMarkAsFetched(folder: CWFolder?) {
        if let name = folder?.name() {
            imapState.folderNamesPrefetched.insert(name)
        }
        if imapState.haveFoldersToPrefetch() {
            prefetchNextFolder()
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

    @objc func handleFolders(timer: NSTimer?) {
        if let folderEnum = imapStore.folderEnumerator() {
            timer?.invalidate()
            imapState.folderNames = []
            imapState.folderNamesPrefetched = []
            for folder in folderEnum {
                let folderName = folder as! String
                imapState.folderNames.append(folderName)
            }
            Log.info(comp, content: "IMAP folders: \(imapState.folderNames)")
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

    func dumpMethodName(methodName: String, notification: NSNotification) {
        Log.info(comp, content: "\(methodName): \(notification)")
    }
}

extension ImapSync: CWServiceClient {
    @objc public func authenticationCompleted(notification: NSNotification) {
        dumpMethodName("authenticationCompleted", notification: notification)
        imapState.authenticationCompleted = true
        waitForFolders()
    }

    @objc public func authenticationFailed(notification: NSNotification) {
        dumpMethodName("authenticationFailed", notification: notification)
    }

    @objc public func connectionEstablished(notification: NSNotification) {
        dumpMethodName("connectionEstablished", notification: notification)
    }

    @objc public func connectionLost(notification: NSNotification) {
        dumpMethodName("connectionLost", notification: notification)
    }

    @objc public func connectionTerminated(notification: NSNotification) {
        dumpMethodName("connectionTerminated", notification: notification)
    }

    @objc public func connectionTimedOut(notification: NSNotification) {
        dumpMethodName("connectionTimedOut", notification: notification)
    }

    @objc public func folderPrefetchCompleted(notification: NSNotification) {
        dumpMethodName("folderPrefetchCompleted", notification: notification)
        if let folder: CWFolder = (notification.userInfo?["Folder"] as! CWFolder) {
            Log.info(comp, content: "prefetched folder: \(folder.name())")
            dispatch_async(dispatch_get_main_queue(), {
                self.checkPrefetchNextFolderAndMarkAsFetched(folder)
            })
        } else {
            Log.info(comp, content: "folderPrefetchCompleted: \(notification)")
        }
    }

    @objc public func messagePrefetchCompleted(notification: NSNotification) {
        dumpMethodName("messagePrefetchCompleted", notification: notification)
    }

    @objc public func serviceInitialized(notification: NSNotification) {
        dumpMethodName("serviceInitialized", notification: notification)
        imapStore.authenticate(connectInfo.getImapUsername(),
                               password: connectInfo.imapPassword,
                               mechanism: connectInfo.imapAuthMethod)
    }

    @objc public func serviceReconnected(theNotification: NSNotification!) {
        dumpMethodName("serviceReconnected", notification: theNotification)
    }

    @objc public func service(theService: CWService!, sentData theData: NSData!) {
    }

    @objc public func service(theService: CWService!, receivedData theData: NSData!) {
    }

    @objc public func messageChanged(notification: NSNotification) {
        dumpMethodName("messageChanged", notification: notification)
    }
}

extension ImapSync: PantomimeFolderDelegate {
    @objc public func folderOpenCompleted(notification: NSNotification!) {
        if let folder: CWFolder = (notification.userInfo?["Folder"] as! CWFolder) {
            Log.info(comp, content: "folderOpenCompleted: \(folder.name())")
        } else {
            Log.info(comp, content: "folderOpenCompleted: \(notification)")
        }
    }

    @objc public func folderOpenFailed(notification: NSNotification!) {
        if let folder: CWFolder = (notification.userInfo?["Folder"] as! CWFolder) {
            Log.info(comp, content: "folderOpenFailed: \(folder.name())")
        } else {
            Log.info(comp, content: "folderOpenFailed: \(notification)")
        }
    }
}
