//
//  File.swift
//  
//
//  Created by Timmy on 2023/7/7.
//

import Foundation

enum StunMessageError: Error {
    case IllegalArgumentException(msg: String)
}

postfix operator ++
postfix func ++(lhs: inout Int) -> Int {
    let temp = lhs
    lhs += 1
    return temp
}
 
prefix operator ++
prefix func ++(lhs: inout Int) -> Int {
    lhs += 1
    return lhs
}

public class StunMessage {
 
    private(set) var transactionId: [UInt8]
    private(set) var type: StunMessageType = .BindingRequest
    private(set) var magicCookie: Int = 0
 
    private(set) var mappedAddress: SocketAddress?
    private(set) var responseAddress: SocketAddress?
    private(set) var sourceAddress: SocketAddress?
    private(set) var changedAddress: SocketAddress?
    private(set) var changeRequest: StunChangeRequest?
    private(set) var errorCode: StunErrorCode?
    
    private enum AttributeType: UInt {
        
        case MappedAddress = 0x0001
        case ResponseAddress = 0x0002
        case ChangeRequest = 0x0003
        case SourceAddress = 0x0004
        case ChangedAddress = 0x0005
        case Username = 0x0006
        case Password = 0x0007
        case MessageIntegrity = 0x0008
        case ErrorCode = 0x0009
        case UnknownAttribute = 0x000A
        case ReflectedFrom = 0x000B
        case XorMappedAddress = 0x8020
        case XorOnly = 0x0021
        case ServerName = 0x8022
        
    }
    
    init(transactionId: [UInt8], type: StunMessageType, magicCookie: Int) {
        self.transactionId = transactionId
        self.type = type
        self.magicCookie = magicCookie
    }
    
    init() {
        self.transactionId = [UInt8](repeating: 0, count: 12)
        for (index, _) in self.transactionId.enumerated() {
            self.transactionId[index] = UInt8.random(in: UInt8.min...UInt8.max)
        }
    }
    
    convenience init(type: StunMessageType) {
        self.init()
        self.type = type
    }
    
    convenience init(type: StunMessageType, changeRequest: StunChangeRequest) {
        self.init()
        self.type = type
        self.changeRequest = changeRequest
    }
    
    public func parse(_ data: [UInt8]) throws {
        /* RFC 5389 6.
            All STUN messages MUST start with a 20-byte header followed by zero
            or more Attributes.  The STUN header contains a STUN message type,
            magic cookie, transaction ID, and message length.

             0                   1                   2                   3
             0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
             +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
             |0 0|     STUN Message Type     |         Message Length        |
             +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
             |                         Magic Cookie                          |
             +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
             |                                                               |
             |                     Transaction ID (96 bits)                  |
             |                                                               |
             +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

           The message length is the count, in bytes, of the size of the
           message, not including the 20 byte header.
        */
        if (data.count < 20) {
            print("Invalid STUN message value !")
            throw StunMessageError.IllegalArgumentException(msg: "Invalid STUN message value !")
        }
        
        var offset: Int = 0
        
        //--- message header --------------------------------------------------
        
        // STUN Message Type
        let messageType = UInt(exactly: Int(data[offset++]) << 8 | Int(data[offset++]))!
//        print("messageType")
//        print(StunMessageType(rawValue: messageType))
        switch messageType {
        case StunMessageType.BindingErrorResponse.rawValue:
            self.type = StunMessageType.BindingErrorResponse
            
        case StunMessageType.BindingRequest.rawValue:
            self.type = StunMessageType.BindingRequest
            
        case StunMessageType.BindingResponse.rawValue:
            self.type = StunMessageType.BindingResponse
            
        case StunMessageType.SharedSecretErrorResponse.rawValue:
            self.type = StunMessageType.SharedSecretErrorResponse
            
        case StunMessageType.SharedSecretRequest.rawValue:
            self.type = StunMessageType.SharedSecretRequest
            
        case StunMessageType.SharedSecretResponse.rawValue:
            self.type = StunMessageType.SharedSecretResponse
            
            
        default:
            print("Invalid STUN message type value !")
            throw StunMessageError.IllegalArgumentException(msg: "Invalid STUN message type value !")
        }
        
        // Message Length
        let messageLength = Int(data[offset++]) << 8 | Int(data[offset++])
        print("messageLength \(messageLength)")
        
        // Magic Cookie
        self.magicCookie = Int(data[offset++]) << 24 | Int(data[offset++]) << 16 | Int(data[offset++]) << 8 | Int(data[offset++])
        
        // Transaction ID
        self.transactionId = [UInt8](data[offset..<(offset+12)])
//        for item in data[offset..<(offset+12)] {
//            self.transactionId.append(item)
//        }
        offset += 12
        
        //--- Message attributes ---------------------------------------------
        while (offset - 20 < messageLength) {
            /* RFC 3489 11.2.
                Each attribute is TLV encoded, with a 16 bit type, 16 bit length, and variable value:

                0                   1                   2                   3
                0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
               +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
               |         Type                  |            Length             |
               +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
               |                             Value                             ....
               +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            */

            // Type
            let attributeTypeValue = UInt(exactly: Int(data[offset++]) << 8 | Int(data[offset++]))!
//            print("attributeTypeValue \(String(attributeTypeValue, radix: 16))")
            guard let attributetype = AttributeType.init(rawValue: attributeTypeValue) else {
//                print("Invalid STUN message type value !!")
                throw StunMessageError.IllegalArgumentException(msg: "Invalid STUN message type value !")
            }
            
            // Length
            let length = Int(data[offset++]) << 8 | Int(data[offset++])
//            print("length \(length)")
//            print("attributetype \(attributetype)")
            
            // MAPPED-ADDRESS
            switch attributetype {
            case AttributeType.MappedAddress:
                self.mappedAddress = StunMessage.parseIPAddr(data: data, offset: &offset)
            // RESPONSE-ADDRESS
            case AttributeType.ResponseAddress:
                self.responseAddress = StunMessage.parseIPAddr(data: data, offset: &offset)
            // CHANGE-REQUEST
            case AttributeType.ChangeRequest: do {
                /*
                    The CHANGE-REQUEST attribute is used by the client to request that
                    the server use a different address and/or port when sending the
                    response.  The attribute is 32 bits long, although only two bits (A
                    and B) are used:

                     0                   1                   2                   3
                     0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
                    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
                    |0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 A B 0|
                    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

                    The meaning of the flags is:

                    A: This is the "change IP" flag.  If true, it requests the server
                       to send the Binding Response with a different IP address than the
                       one the Binding Request was received on.

                    B: This is the "change port" flag.  If true, it requests the
                       server to send the Binding Response with a different port than the
                       one the Binding Request was received on.
                */
                // Skip 3 bytes
                offset += 3
                self.changeRequest = StunChangeRequest(changeIp: (data[offset] & 4) != 0, changePort: (data[offset] & 2) != 0)
                offset += 1
            }
            // SOURCE-ADDRESS
            case AttributeType.SourceAddress:
                self.sourceAddress = StunMessage.parseIPAddr(data: data, offset: &offset)
            // CHANGED-ADDRESS
            case AttributeType.ChangedAddress:
                self.changedAddress = StunMessage.parseIPAddr(data: data, offset: &offset)
            // MESSAGE-INTEGRITY
            case AttributeType.MessageIntegrity:
                offset += length
            // ERROR-CODE
            case AttributeType.ErrorCode: do {
                /* 3489 11.2.9.
                    0                   1                   2                   3
                    0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
                    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
                    |                   0                     |Class|     Number    |
                    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
                    |      Reason Phrase (variable)                                ..
                    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
                */
                let code = Int((data[offset + 2] & 0x7) * 100 + (data[offset + 3] & 0xFF))
                var respText: String = "Unknown"
                if let str = String(bytes: data[(offset + 4)..<(offset+length)], encoding: .utf8) {
                    respText = str
                }
                self.errorCode = StunErrorCode(code: code, reasonText: respText)
                offset += length
            }
            // UNKNOWN-ATTRIBUTES
            case AttributeType.UnknownAttribute:
                offset += length
            // Unknown
            default:
                offset += length
            }
        }
    }
    
    public func toByteData() -> [UInt8] {
        /* RFC 5389 6.
                All STUN messages MUST start with a 20-byte header followed by zero
                or more Attributes.  The STUN header contains a STUN message type,
                magic cookie, transaction ID, and message length.

                 0                   1                   2                   3
                 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
                 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
                 |0 0|     STUN Message Type     |         Message Length        |
                 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
                 |                         Magic Cookie                          |
                 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
                 |                                                               |
                 |                     Transaction ID (96 bits)                  |
                 |                                                               |
                 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

               The message length is the count, in bytes, of the size of the
               message, not including the 20 byte header.
            */

        // We allocate 512 for header, that should be more than enough.
        var msg: [UInt8] = [UInt8](repeating: 0, count: 512)
        var offset: Int = 0
        //--- message header -------------------------------------

        // STUN Message Type (2 bytes)
        msg[offset++] = UInt8((type.rawValue >> 8) & 0x3F)
        msg[offset++] = UInt8(type.rawValue & 0xFF)
        
        // Message Length (2 bytes) will be assigned at last.
        msg[offset++] = 0
        msg[offset++] = 0
        
        // Magic Cookie
        msg[offset++] = UInt8((magicCookie >> 24) & 0xFF)
        msg[offset++] = UInt8((magicCookie >> 16) & 0xFF)
        msg[offset++] = UInt8((magicCookie >> 8) & 0xFF)
        msg[offset++] = UInt8(magicCookie & 0xFF)
        
        // Transaction ID (16 bytes)
        for (index, item) in transactionId[0..<12].enumerated() {
           msg[offset+index] = item
        }
        offset += 12
        
        //--- Message attributes ------------------------------------

        /* RFC 3489 11.2.
            After the header are 0 or more attributes.  Each attribute is TLV
            encoded, with a 16 bit type, 16 bit length, and variable value:

            0                   1                   2                   3
            0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
           +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
           |         Type                  |            Length             |
           +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
           |                             Value                             ....
           +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        */
        if (mappedAddress != nil) {
            StunMessage.storeEndPoint(type: AttributeType.MappedAddress, endPoint: mappedAddress!, message: &msg, offset: &offset)
        } else if (responseAddress != nil) {
            StunMessage.storeEndPoint(type: AttributeType.ResponseAddress, endPoint: responseAddress!, message: &msg, offset: &offset)
        } else if (changeRequest != nil) {
            /*
                The CHANGE-REQUEST attribute is used by the client to request that
                the server use a different address and/or port when sending the
                response.  The attribute is 32 bits long, although only two bits (A
                and B) are used:

                 0                   1                   2                   3
                 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
                +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
                |0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 A B 0|
                +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

                The meaning of the flags is:

                A: This is the "change IP" flag.  If true, it requests the server
                   to send the Binding Response with a different IP address than the
                   one the Binding Request was received on.

                B: This is the "change port" flag.  If true, it requests the
                   server to send the Binding Response with a different port than the
                   one the Binding Request was received on.
            */
            // Attribute header
            msg[offset++] = UInt8(AttributeType.ChangeRequest.rawValue >> 8)
            msg[offset++] = UInt8(AttributeType.ChangeRequest.rawValue & 0xFF)
            msg[offset++] = 0;
            msg[offset++] = 4
            
            msg[offset++] = 0
            msg[offset++] = 0
            msg[offset++] = 0
            msg[offset++] = UInt8((changeRequest!.changeIp ? 1 : 0) << 2 | (changeRequest!.changePort ? 1 : 0) << 1)
        } else if (sourceAddress != nil) {
            StunMessage.storeEndPoint(type: AttributeType.SourceAddress, endPoint: sourceAddress!, message: &msg, offset: &offset)
        } else if (changedAddress != nil) {
            StunMessage.storeEndPoint(type: AttributeType.ChangedAddress, endPoint: changedAddress!, message: &msg, offset: &offset)
        } else if (errorCode != nil) {
            /* 3489 11.2.9.
                0                   1                   2                   3
                0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
                +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
                |                   0                     |Class|     Number    |
                +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
                |      Reason Phrase (variable)                                ..
                +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            */
            let reasonBytes: [UInt8] = Array((errorCode?.reasonText.utf8)!)
            // Header
            msg[offset++] = 0;
            msg[offset++] = UInt8(AttributeType.ErrorCode.rawValue)
            msg[offset++] = 0
            msg[offset++] = UInt8(4 + reasonBytes.count);

            // Empty
            msg[offset++] = 0
            msg[offset++] = 0
            // Class
            msg[offset++] = UInt8(floor(Double(errorCode!.code) / 100.0))
            // Number
            msg[offset++] = UInt8(errorCode!.code & 0xFF)
            // ReasonPhrase
            for (index, item) in reasonBytes.enumerated() {
               msg[offset+index] = item
            }
            offset += reasonBytes.count
        }
        // Update Message Length. NOTE: 20 bytes header not included.
        msg[2] = UInt8((offset - 20) >> 8);
        msg[3] = UInt8((offset - 20) & 0xFF);

        // Make retVal with actual size.
        var retVal: [UInt8] = [UInt8](msg[0..<offset]);
//        for (index, _) in retVal.enumerated() {
//            retVal[index] = msg[index]
//        }
        return retVal
    }
    
    private static func parseIPAddr(data: [UInt8], offset: inout Int) -> SocketAddress {
        /*
            It consists of an eight bit address family, and a sixteen bit
            port, followed by a fixed length value representing the IP address.

            0                   1                   2                   3
            0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            |x x x x x x x x|    Family     |           Port                |
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            |                             Address                           |
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        */
        
        // Skip family
        offset+=1
        offset+=1
        
        // Port
        let port = Int(data[offset++])<<8 | Int(data[offset++])
                                                    
        // Address
        let ip = "\(data[offset++]).\(data[offset++]).\(data[offset++]).\(data[offset++])"
                                                       
        return SocketAddress(ip: ip, port: port)
        
    }
    
    private static func storeEndPoint(type: AttributeType, endPoint: SocketAddress, message: inout [UInt8], offset: inout Int) {
        /*
            It consists of an eight bit address family, and a sixteen bit
            port, followed by a fixed length value representing the IP address.

            0                   1                   2                   3
            0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            |x x x x x x x x|    Family     |           Port                |
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            |                             Address                           |
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        */
        
        // Header
        message[offset++] = UInt8(type.rawValue >> 8)
        message[offset++] = UInt8(type.rawValue & 0xFF)
        message[offset++] = 0
        message[offset++] = 8
        
        // Unused
        message[offset++] = 0
        // Family
        message[offset++] = 0x01
        // Port
        message[offset++] = UInt8(endPoint.port >> 8)
        message[offset++] = UInt8(endPoint.port & 0xFF)
        // Address
        let ipBytes = endPoint.ip.toUint8Array()
        message[offset++] = ipBytes[0]
        message[offset++] = ipBytes[1]
        message[offset++] = ipBytes[2]
        message[offset++] = ipBytes[3]
    }
    
}
