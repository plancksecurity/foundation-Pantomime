//
//  Pantomime.swift
//  PantomimeMailOSX
//
//  Created by Dirk Zimmermann on 05/04/16.
//  Copyright © 2016 pEp Security S.A. All rights reserved.
//

import Foundation

class Pantomime {

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
        let store = CWIMAPStore.init(name: serverName, port: serverPort)
        store.setDelegate(self)
        store.connectInBackgroundAndNotify()
    }

    func authenticationCompleted(notification: NSNotification) {

    }

}