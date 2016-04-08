//
//  TCPConnection.swift
//  PantomimeMailOSX
//
//  Created by Dirk Zimmermann on 06/04/16.
//  Copyright © 2016 pEp Security S.A. All rights reserved.
//

import Foundation

@objc public class TCPConnection: NSObject {
    let comp = "tcp"

    var connected = false
    let name: String
    let port: UInt32
    var readStream: NSInputStream? = nil
    var writeStream: NSOutputStream? = nil
    var openConnections = Set<NSStream>()

    /** Required from CWConnection */
    public var delegate: CWConnectionDelegate?

    /** Required from CWConnection */
    public var ssl_handshaking: Bool = false

    /** Required from CWConnection */
    public required init(name theName: String,
                      port thePort: UInt32, background theBOOL: Bool) {
        assert(theBOOL == true, "Only asynchronous connections in background are supported")
        name = theName
        port = thePort
        super.init()
    }

    /** Required from CWConnection */
    public required init(name theName: String, port thePort: UInt32,
                               connectionTimeout: UInt32, readTimeout: UInt32, writeTimeout: UInt32,
                               background theBOOL: Bool) {
        assert(theBOOL == true, "Only asynchronous connections in background are supported")
        name = theName
        port = thePort
        super.init()
    }
    
    func connect(name theName: String, port thePort: UInt32) {
        var readStream:  Unmanaged<CFReadStream>? = nil
        var writeStream: Unmanaged<CFWriteStream>? = nil
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, theName, thePort, &readStream,
                                           &writeStream)

        assert(readStream != nil, "Could not create reading stream")
        assert(writeStream != nil, "Could not create writing stream")

        if readStream != nil || writeStream != nil {
            self.readStream = readStream?.takeRetainedValue()
            self.writeStream = writeStream?.takeRetainedValue()
            self.setupStream(self.readStream)
            self.setupStream(self.writeStream)
        }
    }

    func setupStream(stream: NSStream?) {
        stream?.delegate = self
        stream?.setProperty(NSStreamSocketSecurityLevelNegotiatedSSL,
                            forKey: NSStreamSocketSecurityLevelKey)
        stream?.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        stream?.open()
    }

    func closeAndRemoveStream(stream: NSStream?) {
        if let theStream = stream {
            theStream.close()
            openConnections.remove(theStream)
            if theStream == readStream {
                readStream = nil
            } else if theStream == writeStream {
                writeStream = nil
            }
        }
    }

    func writeOutBuffer() -> Int {
        return 0
    }
}

extension TCPConnection: CWConnection {
    public func isConnected() -> Bool {
        return connected
    }

    public func close() {
        closeAndRemoveStream(readStream)
        closeAndRemoveStream(writeStream)
        connected = false
        delegate?.receivedEvent(nil, type: ET_EDESC, extra: nil, forMode: nil)
    }

    func uint8BytesToString(bytes: UnsafeMutablePointer<UInt8>, length: Int) -> String {
        let data = NSData(bytes: bytes, length: Int(length))
        let string = NSString(data: data, encoding: NSUTF8StringEncoding)
        return string as! String
    }

    public func read(buf: UnsafeMutablePointer<UInt8>, length: Int) -> Int {
        if readStream?.hasBytesAvailable == false {
            return -1
        }
        let count = readStream!.read(buf, maxLength: length)
        Log.info(comp, content: "read \(count): \"\(uint8BytesToString(buf, length: count))\"")
        return count
    }

    public func write(buf: UnsafeMutablePointer<UInt8>, length: Int) -> Int {
        if writeStream?.hasSpaceAvailable == false {
            return -1
        }
        let count = writeStream!.write(buf, maxLength: length)
        Log.info(comp, content: "wrote \"\(count): \(uint8BytesToString(buf, length: count))\"")
        return count
    }

    public func connect() {
        connect(name: name, port: port)
    }

    public func canWrite() -> Bool {
        return writeStream!.hasSpaceAvailable
    }

}

extension TCPConnection: NSStreamDelegate {
    public func stream(aStream: NSStream,
                       handleEvent eventCode: NSStreamEvent) {
        switch eventCode {
        case NSStreamEvent.None:
            Log.info(comp, content: "\(aStream) None")
        case NSStreamEvent.OpenCompleted:
            openConnections.insert(aStream)
            Log.info(comp, content: "\(aStream) OpenCompleted")
            if openConnections.count == 2 {
                connected = true
                Log.info(comp, content: "connectionEstablished")
                delegate?.connectionEstablished()
            }
        case NSStreamEvent.HasBytesAvailable:
            Log.info(comp, content: "HasBytesAvailable")
            delegate?.receivedEvent(nil, type: ET_RDESC, extra: nil, forMode: nil)
        case NSStreamEvent.HasSpaceAvailable:
            Log.info(comp, content: "HasSpaceAvailable")
            delegate?.receivedEvent(nil, type: ET_WDESC, extra: nil, forMode: nil)
        case NSStreamEvent.ErrorOccurred:
            Log.info(comp, content: "ErrorOccurred")
            delegate?.receivedEvent(nil, type: ET_EDESC, extra: nil, forMode: nil)
        case NSStreamEvent.EndEncountered:
            Log.info(comp, content: "EndEncountered")
            delegate?.receivedEvent(nil, type: ET_EDESC, extra: nil, forMode: nil)
        default:
            Log.info(comp, content: "eventCode \(eventCode)")
            delegate?.receivedEvent(nil, type: ET_EDESC, extra: nil, forMode: nil)
        }
    }

}
