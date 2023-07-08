//
//  File.swift
//  
//
//  Created by timmy on 2023/7/6.
//

import Foundation

public struct StunErrorCode {
    private(set) var code: Int
    private(set) var reasonText: String
    
    init(code: Int, reasonText: String) {
        self.code = code
        self.reasonText = reasonText
    }
}
