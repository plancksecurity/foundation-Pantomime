//
//  Pantomime.swift
//  PantomimeMailOSX
//
//  Created by Dirk Zimmermann on 05/04/16.
//  Copyright © 2016 pEp Security S.A. All rights reserved.
//

import Foundation

public class Pantomime {

    var imapStore: CWIMAPStore? = nil

    func startPantomime() {
        startIMAP()
    }

    func startPop3() {
        let serverName = "pop.gmail.com"
        let serverPort: UInt32 = 995
        let store = CWPOP3Store.init(name: serverName, port: serverPort)
        store.setDelegate(self)
        store.connectInBackgroundAndNotify()
    }

    func startIMAP() {
        let serverName = "mail.syhosting.ch"
        let serverPort: UInt32 = 993
        imapStore = CWIMAPStore.init(name: serverName, port: serverPort)
        imapStore?.setDelegate(self)
        imapStore?.connectInBackgroundAndNotify()
    }
}

extension Pantomime: CWServiceClient {
    @objc public func authenticationCompleted(notification: NSNotification) {
    }

    @objc public func authenticationFailed(notification: NSNotification) {
    }

    @objc public func connectionEstablished(notification: NSNotification) {
        imapStore?.startTLS()
    }

    @objc public func connectionLost(notification: NSNotification) {
        imapStore?.startTLS()
    }

    @objc public func connectionTerminated(notification: NSNotification) {
    }

    @objc public func connectionTimedOut(notification: NSNotification) {
    }

    @objc public func folderPrefetchCompleted(notification: NSNotification) {
    }

    @objc public func messagePrefetchCompleted(notification: NSNotification) {
    }

    @objc public func serviceInitialized(notification: NSNotification) {
    }
}
