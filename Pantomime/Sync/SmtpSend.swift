//
//  SmtpSend.swift
//  Pantomime
//
//  Created by Dirk Zimmermann on 08/04/16.
//  Copyright © 2016 pEp Security S.A. All rights reserved.
//

import Foundation

class SmtpSend {
    let comp = "SmtpSend"

    let connectInfo: ConnectInfo!
    let smtp: CWSMTP

    init(connectInfo: ConnectInfo) {
        self.connectInfo = connectInfo
        smtp = CWSMTP.init(name: connectInfo.smtpServerName, port: connectInfo.smtpServerPort,
                           transport: connectInfo.smtpTransport)
        smtp.setDelegate(self)
    }

    func start() {
        let msg = CWMessage()
        msg.setSubject("Subject")
        msg.setFrom(CWInternetAddress.init(personal: "Test 001", address: "test001@peptest.ch"))

        let to = CWInternetAddress.init(personal: "Test 002", address: "test002@peptest.ch")
        to.setType(PantomimeToRecipient)
        msg.addRecipient(to)

        msg.setContentType("text/plain")
        msg.setContentTransferEncoding(PantomimeEncodingNone)
        msg.setCharset("utf-8")
        msg.setContent("This was sent by pantomime".dataUsingEncoding(NSUTF8StringEncoding))

        smtp.setMessage(msg)
        smtp.connectInBackgroundAndNotify()
    }

    func dumpMethodName(methodName: String, notification: NSNotification) {
        Log.info(comp, content: "\(methodName): \(notification)")
    }
}

extension SmtpSend: TransportClient {

    @objc func messageSent(theNotification: NSNotification!) {
        dumpMethodName("messageSent", notification: theNotification)
    }

    @objc func messageNotSent(theNotification: NSNotification!) {
        dumpMethodName("messageNotSent", notification: theNotification)
    }
}

extension SmtpSend: SMTPClient {
    @objc func transactionInitiationCompleted(theNotification: NSNotification!) {
        dumpMethodName("transactionInitiationCompleted", notification: theNotification)
    }

    @objc func transactionInitiationFailed(theNotification: NSNotification!) {
        dumpMethodName("transactionInitiationFailed", notification: theNotification)
    }

    @objc func recipientIdentificationCompleted(theNotification: NSNotification!) {
        dumpMethodName("recipientIdentificationCompleted", notification: theNotification)
    }

    @objc func recipientIdentificationFailed(theNotification: NSNotification!) {
        dumpMethodName("recipientIdentificationFailed", notification: theNotification)
    }

    @objc func transactionResetCompleted(theNotification: NSNotification!) {
        dumpMethodName("transactionResetCompleted", notification: theNotification)
    }

    @objc func transactionResetFailed(theNotification: NSNotification!) {
        dumpMethodName("transactionResetFailed", notification: theNotification)
    }
}

extension SmtpSend: CWServiceClient {
    @objc func authenticationCompleted(theNotification: NSNotification!) {
        dumpMethodName("authenticationCompleted", notification: theNotification)
    }

    @objc func authenticationFailed(theNotification: NSNotification!) {
        dumpMethodName("authenticationFailed", notification: theNotification)
    }

    @objc func connectionEstablished(theNotification: NSNotification!) {
        dumpMethodName("connectionEstablished", notification: theNotification)
    }

    @objc func connectionLost(theNotification: NSNotification!) {
        dumpMethodName("connectionLost", notification: theNotification)
    }

    @objc func connectionTerminated(theNotification: NSNotification!) {
        dumpMethodName("connectionTerminated", notification: theNotification)
    }

    @objc func connectionTimedOut(theNotification: NSNotification!) {
        dumpMethodName("connectionTimedOut", notification: theNotification)
    }

    @objc func requestCancelled(theNotification: NSNotification!) {
        dumpMethodName("requestCancelled", notification: theNotification)
    }

    @objc func serviceInitialized(theNotification: NSNotification!) {
        dumpMethodName("serviceInitialized", notification: theNotification)
        dispatch_async(dispatch_get_main_queue(), {
            /*
            self.smtp.authenticate(self.connectInfo.getSmtpUsername(),
                password: self.connectInfo.getSmtpPassword(),
                mechanism: self.connectInfo.smtpAuthMethod)
             */
            //self.smtp.startTLS()
        })
    }

    @objc func serviceReconnected(theNotification: NSNotification!) {
        dumpMethodName("serviceReconnected", notification: theNotification)
    }

}