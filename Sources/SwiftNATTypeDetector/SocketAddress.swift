//
//  File.swift
//  
//
//  Created by timmy on 2023/7/6.
//

import Foundation

public struct SocketAddress {
    public private(set) var ip: String
    public private(set) var port: Int
    
    init(ip: String, port: Int) {
        self.ip = ip
        self.port = port
    }
}

public extension String {
    func toUint8Array() -> [UInt8] {
        var result: [UInt8] = [UInt8]()
        for part in self.split(separator: ".") {
            result.append(UInt8(part)!)
        }
        return result
}
}

extension UInt32 {

    public func IPv4String() -> String {

        let ip = self

        let byte1 = UInt8(ip & 0xff)
        let byte2 = UInt8((ip>>8) & 0xff)
        let byte3 = UInt8((ip>>16) & 0xff)
        let byte4 = UInt8((ip>>24) & 0xff)

        return "\(byte1).\(byte2).\(byte3).\(byte4)"
    }
}
