//
//  ConnectInfo
//  PantomimeMailOSX
//
//  Created by Dirk Zimmermann on 08/04/16.
//  Copyright © 2016 pEp Security S.A. All rights reserved.
//

import Foundation

class ConnectInfo {
    let username: String
    let email: String
    let password: String
    let authMethod: String
    let serverName: String
    let serverPort: UInt32

    init(username: String, email: String, password: String, authMethod: String,
         serverName: String, serverPort: UInt32) {
        self.username = username
        self.email = email
        self.authMethod = authMethod
        self.password = password
        self.serverName = serverName
        self.serverPort = serverPort
    }

}