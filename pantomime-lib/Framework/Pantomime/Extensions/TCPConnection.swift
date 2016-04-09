//
//  TCPConnection.swift
//  PantomimeMailOSX
//
//  Created by Dirk Zimmermann on 06/04/16.
//  Copyright © 2016 pEp Security S.A. All rights reserved.
//

import Foundation

@objc public class TCPConnection: NSObject {
    let comp = "TCPConnection"

    var connected = false
    let name: String
    let port: UInt32
    let transport: ConnectionTransport
    var readStream: NSInputStream? = nil
    var writeStream: NSOutputStream? = nil
    var openConnections = Set<NSStream>()

    /** Required from CWConnection */
    public var delegate: CWConnectionDelegate?

    /** Required from CWConnection */
    public required init(name: String, port: UInt32,
                         transport: ConnectionTransport,
                         background theBOOL: Bool) {
        assert(theBOOL == true, "Only asynchronous connections in background are supported")
        self.name = name
        self.port = port
        self.transport = transport
        super.init()
    }

    public func startTLS() {
        readStream!.setProperty(NSStreamSocketSecurityLevelNone,
                                forKey: NSStreamSocketSecurityLevelKey)
        writeStream!.setProperty(NSStreamSocketSecurityLevelNone,
                                 forKey: NSStreamSocketSecurityLevelKey)
        readStream?.open()
        writeStream?.open()
    }

    func setupStream(stream: NSStream?) {
        stream?.delegate = self
        switch transport {
        case .Plain:
            stream?.setProperty(NSStreamSocketSecurityLevelNone,
                                forKey: NSStreamSocketSecurityLevelKey)
        case .StartTLS:
            stream?.setProperty(NSStreamSocketSecurityLevelNone,
                                forKey: NSStreamSocketSecurityLevelKey)
        case .TLS:
            stream?.setProperty(NSStreamSocketSecurityLevelNegotiatedSSL,
                                forKey: NSStreamSocketSecurityLevelKey)
        }
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
        if length >= 0 {
            let data = NSData(bytes: bytes, length: Int(length))
            let string = NSString(data: data, encoding: NSUTF8StringEncoding)
            return string as! String
        } else {
            return ""
        }
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
        var readStream:  Unmanaged<CFReadStream>? = nil
        var writeStream: Unmanaged<CFWriteStream>? = nil
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, name, port, &readStream,
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
            delegate?.receivedEvent(nil, type: ET_RDESC, extra: nil, forMode: nil)
        case NSStreamEvent.EndEncountered:
            Log.info(comp, content: "EndEncountered")
            delegate?.receivedEvent(nil, type: ET_RDESC, extra: nil, forMode: nil)
        default:
            Log.info(comp, content: "eventCode \(eventCode)")
            delegate?.receivedEvent(nil, type: ET_EDESC, extra: nil, forMode: nil)
        }
    }

}
