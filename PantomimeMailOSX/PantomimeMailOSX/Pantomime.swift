//
//  Pantomime.swift
//  PantomimeMailOSX
//
//  Created by Dirk Zimmermann on 05/04/16.
//  Copyright © 2016 pEp Security S.A. All rights reserved.
//

import Foundation

public class Pantomime {

    let testData: TestData = TestData()
    var imapStore: CWIMAPStore

    init() {
        imapStore = CWIMAPStore.init(name: testData.imapServer, port: testData.imapPort)
    }

    func startPantomime() {
        startIMAP()
    }

    func startIMAP() {
        imapStore.setDelegate(self)
        imapStore.connectInBackgroundAndNotify()
    }
}

extension Pantomime: CWServiceClient {
    @objc public func authenticationCompleted(notification: NSNotification) {
        print("authenticationCompleted")
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
    }

    @objc public func messagePrefetchCompleted(notification: NSNotification) {
    }

    @objc public func serviceInitialized(notification: NSNotification) {
        imapStore.authenticate(testData.imapUser, password: testData.imapPassword,
                               mechanism: testData.imapAuthMethod)
    }
}
