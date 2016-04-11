//
//  CacheManager.swift
//  PantomimeMailOSX
//
//  Created by Dirk Zimmermann on 07/04/16.
//  Copyright © 2016 pEp Security S.A. All rights reserved.
//

import Foundation

@objc public class CacheManager: NSObject, CWCache, CWIMAPCache {

    public func invalidate() {
    }

    public func synchronize() -> Bool {
        return true
    }

    public func count() -> UInt {
        return 0
    }

    public func removeMessageWithUID(theUID: UInt) {
    }

    public func UIDValidity() -> UInt {
        return 0
    }

    public func setUIDValidity(theUIDValidity: UInt) {
    }

    public func messageWithUID(theUID: UInt) -> CWIMAPMessage! {
        return nil
    }

    func dumpMessage(msg: CWMessage) {
        print("CWMessage: contentType(\(msg.contentType()))",
              " isInitialized(\(msg.isInitialized()))\n",
              " content(\(msg.content()))")
    }

    public func writeRecord(theRecord: CacheRecord!, message: CWIMAPMessage!) {
        let folder = message.folder()
        print("write UID(\(message.UID())) folder(\(folder.name()))")
        dumpMessage(message)
    }

}