//
//  TCPConnection.swift
//  PantomimeMailOSX
//
//  Created by Dirk Zimmermann on 06/04/16.
//  Copyright © 2016 pEp Security S.A. All rights reserved.
//

import Foundation

@objc public class TCPConnection: NSObject {

    public var connected = false
    var readStream: NSInputStream? = nil
    var writeStream: NSOutputStream? = nil
    var delegate: ConnectionDelegate? = nil
    var openConnections = Set<NSStream>()
    var outBuffer = NSMutableData.init()

    public required init!(name theName: String!,
                      port thePort: UInt32, connectionTimeout theConnectionTimeout: UInt32,
                           readTimeout theReadTimeout: UInt32,
                                       writeTimeout theWriteTimeout: UInt32,
                                                    background theBOOL: Bool,
                                                               delegate: ConnectionDelegate) {
        assert(theBOOL == true, "Only asynchronous connections in background are supported")

        self.delegate = delegate
        super.init()
        connect(name: theName, port: thePort, connectionTimeout: 0, readTimeout: 0,
                writeTimeout: 0, background: true)
    }

    func connect(name theName: String!, port thePort: UInt32,
                      connectionTimeout theConnectionTimeout: UInt32,
                                        readTimeout theReadTimeout: UInt32,
                                                    writeTimeout theWriteTimeout: UInt32,
                                                                 background theBOOL: Bool) {
        var readStream:  Unmanaged<CFReadStream>? = nil
        var writeStream: Unmanaged<CFWriteStream>? = nil
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, theName, thePort, &readStream,
                                           &writeStream)
        if readStream == nil || writeStream == nil {
            delegate?.connectionFailed(self)
        } else {
            self.readStream = readStream?.takeRetainedValue()
            self.writeStream = writeStream?.takeRetainedValue()
            self.setupStream(self.readStream)
            self.setupStream(self.writeStream)
        }
    }

    func setupStream(stream: NSStream?) {
        stream?.delegate = self
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
    public func fd() -> Int32 {
        return -1
    }

    public func isConnected() -> Bool {
        return connected
    }

    public func close() {
        closeAndRemoveStream(readStream)
        closeAndRemoveStream(writeStream)
        connected = false
        delegate?.connectionClosed(self)
    }

    public func read(buf: UnsafeMutablePointer<Int8>, length len: Int32) -> Int32 {
        return 0
    }

    public func write(buf: UnsafeMutablePointer<Int8>, length len: Int32) -> Int32 {
        outBuffer.appendBytes(buf, length: Int(len))
        return len
    }
}

extension TCPConnection: NSStreamDelegate {
    public func stream(aStream: NSStream,
                       handleEvent eventCode: NSStreamEvent) {
        switch eventCode {
        case NSStreamEvent.None:
            print("\(aStream) None")
        case NSStreamEvent.OpenCompleted:
            openConnections.insert(aStream)
            print("\(aStream) OpenCompleted")
            if openConnections.count == 2 {
                connected = true
                delegate?.connectionOpened(self)
            }
        case NSStreamEvent.HasBytesAvailable:
            print("\(aStream) HasBytesAvailable")
        case NSStreamEvent.HasSpaceAvailable:
            print("\(aStream) HasSpaceAvailable")
        case NSStreamEvent.ErrorOccurred:
            print("\(aStream) ErrorOccurred")
            close()
        case NSStreamEvent.EndEncountered:
            print("\(aStream) EndEncountered")
            close()
        default:
            print("\(aStream) eventCode \(eventCode)")
        }
    }

}
