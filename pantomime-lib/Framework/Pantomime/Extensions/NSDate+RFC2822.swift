//
//  NSDate+RFC2822.swift
//  Pantomime
//
//  Created by Dirk Zimmermann on 11/04/16.
//  Copyright © 2016 pEp Security S.A. All rights reserved.
//

import Foundation

extension NSDate {

    func rfc2822String() -> String {
        let formatter = NSDateFormatter.init()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        formatter.locale = NSLocale.init(localeIdentifier:"en_US_POSIX")
        return formatter.stringFromDate(self)
    }

}