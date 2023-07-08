//
//  File.swift
//  
//
//  Created by Timmy on 2023/7/7.
//

import Foundation
import Network

@available(macOS 10.14, *)
public class UdpSocket {
    private var timer: SwiftTimer?
    var connection: NWConnection?
    
    init(_ host: String, _ port: Int) {
        // Transmited message:
        let sema = DispatchSemaphore(value: 0)
        self.connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port("\(port)")!, using: .udp)
        self.connection?.stateUpdateHandler = { (newState) in
            switch (newState) {
            case .ready: do {
                print("State: Ready\n")
                sema.signal()
            }
            case .setup:
                print("State: Setup\n")
            case .cancelled:
                print("State: Cancelled\n")
            case .preparing:
                print("State: Preparing\n")
            default:
                print("ERROR! State not defined!\n")
            }
        }
        self.connection?.start(queue: .global())
        sema.wait()
    }
    
    func sendUDP(_ data: Data, _ timeout: DispatchTimeInterval = .seconds(3)) -> Data? {
        let sema = DispatchSemaphore(value: 0)
        var result: Data?
        self.connection?.send(content: data, completion: NWConnection.SendCompletion.contentProcessed(({ (NWError) in
            if (NWError == nil) {
                print("Data was sent to UDP")
                self.timer = SwiftTimer(interval: timeout, queue: .global()) {_ in
                    print("timeout")
                    sema.signal()
                }
                self.timer?.start()
            } else {
                print("ERROR! Error when data (Type: Data) sending. NWError: \n \(NWError!)")
            }
        })))
        self.connection?.receiveMessage { (data, context, isComplete, error) in
            print("timer?.suspend")
            self.timer?.suspend()
            if (isComplete) {
                print("Receive is complete")
                result = data
                sema.signal()
            }
        }
        sema.wait()
        return result
    }
    
}
