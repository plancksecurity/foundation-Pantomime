//
//  ConnectInfo
//  PantomimeMailOSX
//
//  Created by Dirk Zimmermann on 08/04/16.
//  Copyright © 2016 pEp Security S.A. All rights reserved.
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
    let imapServerPort: UInt32
    let smtpServerName: String
    let smtpServerPort: UInt32

    init(email: String,
         imapUsername: String?, smtpUsername: String?,
         imapPassword: String, smtpPassword: String?,
         imapAuthMethod: String, smtpAuthMethod: String,
         imapServerName: String, imapServerPort: UInt32,
         smtpServerName: String, smtpServerPort: UInt32) {
        self.email = email
        self.imapUsername = imapUsername
        self.smtpUsername = smtpUsername
        self.imapPassword = imapPassword
        self.smtpPassword = smtpPassword
        self.imapAuthMethod = imapAuthMethod
        self.smtpAuthMethod = smtpAuthMethod
        self.imapServerName = imapServerName
        self.imapServerPort = imapServerPort
        self.smtpServerName = smtpServerName
        self.smtpServerPort = smtpServerPort
    }

    convenience init(email: String,
                     imapPassword: String,
                     imapAuthMethod: String, smtpAuthMethod: String,
                     imapServerName: String, imapServerPort: UInt32,
                     smtpServerName: String, smtpServerPort: UInt32) {
        self.init(email: email, imapUsername: nil, smtpUsername: nil,
                  imapPassword: imapPassword, smtpPassword: nil,
                  imapAuthMethod: imapAuthMethod, smtpAuthMethod: smtpAuthMethod,
                  imapServerName: imapServerName, imapServerPort: imapServerPort,
                  smtpServerName: smtpServerName, smtpServerPort: smtpServerPort)
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