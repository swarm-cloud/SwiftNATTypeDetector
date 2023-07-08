//
//  File.swift
//  
//
//  Created by timmy on 2023/7/6.
//

import Foundation

public struct StunChangeRequest {
    private(set) var changeIp: Bool
    private(set) var changePort: Bool
    
    init(changeIp: Bool, changePort: Bool) {
        self.changeIp = changeIp
        self.changePort = changePort
    }
}
