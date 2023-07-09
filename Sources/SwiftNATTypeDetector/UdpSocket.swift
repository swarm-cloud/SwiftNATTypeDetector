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
    var ready: Bool = false
    
    init(_ host: String, _ port: Int) {
        // Transmited message:
        let sema = DispatchSemaphore(value: 0)
        self.connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port("\(port)")!, using: .udp)
        self.connection?.stateUpdateHandler = { (newState) in
            switch (newState) {
            case .ready: do {
                self.ready = true
                sema.signal()
            }
//            case .setup:
//                print("State: Setup\n")
//            case .cancelled:
//                print("State: Cancelled\n")
//            case .preparing:
//                print("State: Preparing\n")
//            case .waiting(let error):
//                print(error.localizedDescription)
            default:
                print("ERROR! State not defined!\n")
                sema.signal()
            }
        }
        self.connection?.start(queue: .global())
        sema.wait()
    }
    
    func sendUDP(_ data: Data, _ timeout: DispatchTimeInterval = .seconds(3)) -> Data? {
        guard ready == true else {
            return nil
        }
        let sema = DispatchSemaphore(value: 0)
        var result: Data?
        self.connection?.send(content: data, completion: NWConnection.SendCompletion.contentProcessed(({ (NWError) in
            if NWError == nil {
                self.timer = SwiftTimer(interval: timeout, queue: .global()) {_ in
                    sema.signal()
                }
                self.timer?.start()
            } else {
                print("ERROR! Error when data (Type: Data) sending. NWError: \n \(NWError!)")
            }
        })))
        self.connection?.receiveMessage { (data, context, isComplete, error) in
            self.timer?.suspend()
            if isComplete {
                result = data
                sema.signal()
            }
        }
        sema.wait()
        return result
    }
    
}
