//
//  File.swift
//  
//
//  Created by Timmy on 2023/7/7.
//

import Foundation

enum TransactionError: Error {
    case transactionIdNotMatch
    case transactionException(msg: String)
}

@available(iOS 12.0, macOS 10.14, tvOS 12.0, *)
public class StunClient {
    private static let UDP_SEND_COUNT: Int = 2
    private static let TRANSACTION_TIMEOUT: Int = 1000
    private static let DEFAULT_STUN_HOST: String = "stun.cdnbye.com"
    private static let DEFAULT_STUN_PORT: Int = 3478
    
    
    public static func query(localIP: String) -> StunResult {
        return query(stunHost: DEFAULT_STUN_HOST, stunPort: DEFAULT_STUN_PORT, localIP: localIP)
    }
    
    public static func query(stunHost: String, stunPort: Int, localIP: String) -> StunResult {
        
        let remoteEndPoint = SocketAddress(ip: stunHost, port: stunPort)
        
        /*
            In test I, the client sends a STUN Binding Request to a server, without any flags set in the
            CHANGE-REQUEST attribute, and without the RESPONSE-ADDRESS attribute. This causes the server
            to send the response back to the address and port that the request came from.

            In test II, the client sends a Binding Request with both the "change IP" and "change port" flags
            from the CHANGE-REQUEST attribute set.

            In test III, the client sends a Binding Request with only the "change port" flag set.

                                +--------+
                                |  Test  |
                                |   I    |
                                +--------+
                                     |
                                     |
                                     V
                                    /\              /\
                                 N /  \ Y          /  \ Y             +--------+
                  UDP     <-------/Resp\--------->/ IP \------------->|  Test  |
                  Blocked         \ ?  /          \Same/              |   II   |
                                   \  /            \? /               +--------+
                                    \/              \/                    |
                                                     | N                  |
                                                     |                    V
                                                     V                    /\
                                                 +--------+  Sym.      N /  \
                                                 |  Test  |  UDP    <---/Resp\
                                                 |   II   |  Firewall   \ ?  /
                                                 +--------+              \  /
                                                     |                    \/
                                                     V                     |Y
                          /\                         /\                    |
           Symmetric  N  /  \       +--------+   N  /  \                   V
              NAT  <--- / IP \<-----|  Test  |<--- /Resp\               Open
                        \Same/      |   I    |     \ ?  /               Internet
                         \? /       +--------+      \  /
                          \/                         \/
                          |                           |Y
                          |                           |
                          |                           V
                          |                           Full
                          |                           Cone
                          V              /\
                      +--------+        /  \ Y
                      |  Test  |------>/Resp\---->Restricted
                      |   III  |       \ ?  /
                      +--------+        \  /
                                         \/
                                          |N
                                          |       Port
                                          +------>Restricted

        */
        do {
            // Test I
            let test1 = StunMessage(type: StunMessageType.BindingRequest);
            let test1Response = try doTransaction(request: test1, remoteEndPoint: remoteEndPoint, timeout: .milliseconds(TRANSACTION_TIMEOUT))
            // UDP blocked.
            guard let test1Resp = test1Response else {
                return StunResult(natType: .UdpBlocked)
            }

            guard let test1ResponseMapedAddress = test1Resp.mappedAddress else {
                return StunResult(natType: .Unknown)
            }
            
            // Test II
            let test2 = StunMessage(type: StunMessageType.BindingRequest, changeRequest: StunChangeRequest(changeIp: true, changePort: true))
            
            // No NAT.
            if localIP.toUint8Array().elementsEqual(test1ResponseMapedAddress.ip.toUint8Array()) {
                // IP相同
                let test2Response = try doTransaction(request: test2, remoteEndPoint: remoteEndPoint, timeout: .milliseconds(TRANSACTION_TIMEOUT))
                // Open Internet.
                if test2Response != nil {
                    return StunResult(natType: .OpenInternet, ipAddr: test1ResponseMapedAddress)
                }
                // Symmetric UDP firewall.
                return StunResult(natType: .SymmetricUdpFirewall, ipAddr: test1ResponseMapedAddress)
            } else {
                // NAT
                let test2Response = try doTransaction(request: test2, remoteEndPoint: remoteEndPoint, timeout: .milliseconds(TRANSACTION_TIMEOUT))
                // Full cone NAT.
                if test2Response != nil {
                    return StunResult(natType: .FullCone, ipAddr: test1ResponseMapedAddress)
                }
                /*
                        If no response is received, it performs test I again, but this time, does so to
                        the address and port from the CHANGED-ADDRESS attribute from the response to test I.
                    */
                guard let test1ResponseChangedAddress = test1Resp.changedAddress else {
                    return StunResult(natType: .Unknown)
                }

                // Test I(II)
                let test12 = StunMessage(type: StunMessageType.BindingRequest)
                let test12Response = try doTransaction(request: test12, remoteEndPoint: test1ResponseChangedAddress, timeout: .milliseconds(TRANSACTION_TIMEOUT))
                
                guard let test12Resp = test12Response else {
                    throw TransactionError.transactionException(msg: "STUN Test I(II) didn't get response !")
                }
                
                guard let test12ResponseMappedAddress = test12Resp.mappedAddress else {
                    return StunResult(natType: .Unknown)
                }
                
                // Symmetric NAT
                if !(test12ResponseMappedAddress.ip.toUint8Array().elementsEqual(test1ResponseMapedAddress.ip.toUint8Array())
                      && test12ResponseMappedAddress.port == test1ResponseMapedAddress.port) {
                    return StunResult(natType: .Symmetric, ipAddr: test1ResponseMapedAddress)
                }
                // Test III
                let test3 = StunMessage(type: StunMessageType.BindingRequest, changeRequest: StunChangeRequest(changeIp: false, changePort: true))
                let test3Response = try doTransaction(request: test3, remoteEndPoint: test1ResponseChangedAddress, timeout: .milliseconds(TRANSACTION_TIMEOUT))
                // Restricted
                if test3Response != nil {
                    return StunResult(natType: .RestrictedCone, ipAddr: test1ResponseMapedAddress)
                }
                // Port restricted
                return StunResult(natType: .PortRestrictedCone, ipAddr: test1ResponseMapedAddress)
            }
        } catch _ {
            return StunResult(natType: .Unknown)
        }
        
    }
    
    // Does STUN transaction. Returns transaction response or null if transaction failed.
    // Returns transaction response or null if transaction failed.
    private static func doTransaction(request: StunMessage, remoteEndPoint: SocketAddress, timeout: DispatchTimeInterval) throws -> StunMessage? {
        let requestBytes: [UInt8] = request.toByteData()
        var revResponse = false
        var receiveCount: Int = 0
        let response = StunMessage()
        while (!revResponse && receiveCount < UDP_SEND_COUNT) {
            defer {
                receiveCount += 1
            }
            let socket = UdpSocket(remoteEndPoint.ip, remoteEndPoint.port)
            let receiveBuffer = socket.sendUDP(Data(bytes: requestBytes, count: requestBytes.count))
            guard let buf = receiveBuffer else {
                continue
            }
            
            try response.parse([UInt8](buf))
            
            if response.transactionId.elementsEqual(request.transactionId) {
                revResponse = true
            } else {
                throw TransactionError.transactionIdNotMatch
            }
        }

        return revResponse ? response : nil
    }
}
