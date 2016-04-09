//
//  TestData.swift
//  PantomimeMailOSX
//
//  Created by Dirk Zimmermann on 07/04/16.
//  Copyright © 2016 pEp Security S.A. All rights reserved.
//

import Foundation

class TestData: ConnectInfo {

    init() {
        super.init(email: "test001@pemail.com",
                   imapUsername: nil,
                   smtpUsername: nil,
                   imapPassword: "somePassword",
                   smtpPassword: nil,
                   imapAuthMethod: "LOGIN", smtpAuthMethod: "PLAIN",
                   imapServerName: "mail.server.com", imapServerPort: 993,
                   imapTransport: .TLS,
                   smtpServerName: "mail.server.com", smtpServerPort: 587,
                   smtpTransport: .StartTLS)
    }

}