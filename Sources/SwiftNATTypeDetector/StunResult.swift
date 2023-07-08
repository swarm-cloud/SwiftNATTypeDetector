//
//  File.swift
//  
//
//  Created by timmy on 2023/7/6.
//

import Foundation

public struct StunResult {
    
    public private(set) var natType: NatType
    public private(set) var ipAddr: SocketAddress?
    
    init(natType: NatType, ipAddr: SocketAddress? = nil) {
        self.natType = natType
        self.ipAddr = ipAddr
    }
}
