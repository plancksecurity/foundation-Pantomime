//
//  ConnectInfo
//  PantomimeMailOSX
//
//  Created by Dirk Zimmermann on 08/04/16.
//  Copyright © 2016 p≡p Security S.A. All rights reserved.
//

import Foundation

class ConnectInfo {
    let email: String
    let imapUsername: String?
    let smtpUsername: String?
    let imapPassword: String
    let smtpPassword: String?
    let imapAuthMethod: String
    let smtpAuthMethod: String
    let imapServerName: String
    let imapServerPort: UInt16
    let smtpServerName: String
    let smtpServerPort: UInt16
    let imapTransport: ConnectionTransport
    let smtpTransport: ConnectionTransport

    init(email: String,
         imapUsername: String?, smtpUsername: String?,
         imapPassword: String, smtpPassword: String?,
         imapAuthMethod: String, smtpAuthMethod: String,
         imapServerName: String, imapServerPort: UInt16, imapTransport: ConnectionTransport,
         smtpServerName: String, smtpServerPort: UInt16, smtpTransport: ConnectionTransport) {
        self.email = email
        self.imapUsername = imapUsername
        self.smtpUsername = smtpUsername
        self.imapPassword = imapPassword
        self.smtpPassword = smtpPassword
        self.imapAuthMethod = imapAuthMethod
        self.smtpAuthMethod = smtpAuthMethod
        self.imapServerName = imapServerName
        self.imapServerPort = imapServerPort
        self.imapTransport = imapTransport
        self.smtpServerName = smtpServerName
        self.smtpServerPort = smtpServerPort
        self.smtpTransport = smtpTransport
    }

    convenience init(email: String,
                     imapPassword: String,
                     imapAuthMethod: String, smtpAuthMethod: String,
                     imapServerName: String, imapServerPort: UInt16,
                     imapTransport: ConnectionTransport,
                     smtpServerName: String, smtpServerPort: UInt16,
                     smtpTransport: ConnectionTransport) {
        self.init(email: email, imapUsername: nil, smtpUsername: nil,
                  imapPassword: imapPassword, smtpPassword: nil,
                  imapAuthMethod: imapAuthMethod, smtpAuthMethod: smtpAuthMethod,
                  imapServerName: imapServerName, imapServerPort: imapServerPort,
                  imapTransport: imapTransport,
                  smtpServerName: smtpServerName, smtpServerPort: smtpServerPort,
                  smtpTransport: smtpTransport)
    }

    func getSmtpUsername() -> String {
        if let username = smtpUsername {
            return username
        }
        return getImapUsername()
    }

    func getImapUsername() -> String {
        if let username = imapUsername {
            return username
        }
        return email
    }

    func getSmtpPassword() -> String {
        if let password = smtpPassword {
            return password
        }
        return imapPassword
    }

}