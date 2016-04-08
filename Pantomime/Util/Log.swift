//
//  Log.swift
//  PantomimeMailOSX
//
//  Created by Dirk Zimmermann on 08/04/16.
//  Copyright © 2016 pEp Security S.A. All rights reserved.
//

import Foundation

/** Very primitive Logging class. */
class Log {

    static let allow: [String:Bool] = ["TCPConnection": true, "ImapSync": true,
                                       "SmtpSend": true]

    /** Somewhat verbose */
    static func info(component: String, content: String) {
        if allow[component] == true {
            print("\(component): \(content)")
        }
    }

    /** More important */
    static func warn(component: String, _ content: String) {
        if allow[component] == true {
            print("\(component): \(content)")
        }
    }
}