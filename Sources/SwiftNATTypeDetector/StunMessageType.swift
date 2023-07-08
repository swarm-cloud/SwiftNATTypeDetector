//
//  File.swift
//  
//
//  Created by timmy on 2023/7/6.
//

enum StunMessageType: UInt {
    
    // STUN message is binding request.
    case BindingRequest = 0x0001

    // STUN message is binding request response.
    case BindingResponse = 0x0101

    // STUN message is binding request error response.
    case BindingErrorResponse = 0x0111
//
//    // STUN message is "shared secret" request.
    case  SharedSecretRequest = 0x0002
//
//    // STUN message is "shared secret" request response.
    case SharedSecretResponse = 0x0102
//
//    // STUN message is "shared secret" request error response.
    case SharedSecretErrorResponse = 0x0112
    
}
