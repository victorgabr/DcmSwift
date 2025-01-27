//
//  PresentationContext.swift
//  DcmSwift
//
//  Created by Rafael Warnault, OPALE on 02/05/2019.
//  Copyright © 2019 OPALE. All rights reserved.
//

import Foundation

/**
 Presentation Context Item Structure
 
 TODO: rewrite with OffsetInputStream
 
 Presentation Context consists of:
 - item type
 - 1 reserved byte
 - 2 item length
 - presentation context id
 - 1 reserved byte
 - result/reason OR 1 reserved byte
 - 1 reserved byte
 - only 1 transfer syntax OR 1 abstract syntax and 1 or more transfer syntax
 
 http://dicom.nema.org/dicom/2013/output/chtml/part08/sect_9.3.html#sect_9.3.2.2
 */
public class PresentationContext {
    public var transferSyntaxes:[String] = []
    
    
    public var acceptedTransferSyntax:String?
    public var abstractSyntax:String!
    public var contextID:UInt8!
    public var result:UInt8!
    
    private var pcLength:Int16 = 0
    
    public init(abstractSyntax:String, transferSyntaxes:[String] = [], contextID:UInt8, result:UInt8? = nil) {
        self.transferSyntaxes = transferSyntaxes
        self.abstractSyntax = abstractSyntax
        self.contextID = contextID
        self.result = result
    }
    
    
    public func length() -> Int16 {
        return pcLength
    }
    
    public init?(data:Data) {
        let pcType = data.first
        
        if pcType != ItemType.acPresentationContext.rawValue && pcType != ItemType.rqPresentationContext.rawValue {
            return nil
        }
        
        // let length = data.subdata(in: 2..<4).toInt16(byteOrder: .BigEndian)
        let pcContextID = data.subdata(in: 4..<5).toUInt8(byteOrder: .BigEndian)
        
        // if we send the RQ ? :-\
        if pcType == ItemType.acPresentationContext.rawValue {
            self.result = UInt8(data.subdata(in: 6..<7).toInt8(byteOrder: .BigEndian))
        }
        
        var offset = 8
        
        self.contextID = pcContextID// pcContextID == -127 ?  UInt8(128) : UInt8(pcContextID)
        
        // if we receive the RQ
        if pcType == ItemType.rqPresentationContext.rawValue {
            // parse abstract syntax
            let d = data.subdata(in: offset..<offset+1).toInt8()
            if d == 0x30 {
                offset += 2
                
                let length = Int(data.subdata(in: offset..<offset+2).toInt16(byteOrder: .BigEndian))
                offset += 2
                
                let asData = data.subdata(in: offset..<offset+length)
                self.abstractSyntax = asData.toString().trimmingCharacters(in: .whitespaces)
                
                offset += length
            }
        }
        
        // parse transfer syntaxes
        var tsType = data.subdata(in: offset..<offset+1).toInt8(byteOrder: .BigEndian)
        // print("tsType: \(data.subdata(in: offset..<offset+1).toHex())")
        while tsType == 0x40 {
            offset += 2
            
            let tsLength = data.subdata(in: offset..<offset+2).toInt16(byteOrder: .BigEndian)
            offset += 2

            let transferSyntaxData = data.subdata(in: offset..<offset+Int(tsLength))
            if let acceptedTransferSyntax = String(bytes: transferSyntaxData, encoding: .utf8) {
                transferSyntaxes.append(acceptedTransferSyntax)
            }
            
            offset = offset+Int(tsLength)

            if offset <= data.count && offset+1 <= data.count {
                tsType = data.subdata(in: offset..<offset+1).toInt8(byteOrder: .BigEndian)
            } else {
                tsType = 0
            }
        }
    }
    
    
    /**
     - Parameter onlyAcceptedTS: setup Presentation Context with the given Transfer Syntax. Used
     by AssociationAC message to reply only with the Association accepted Transfer Syntax, where in AssociationRQ,
     the Presentation Context presents all the supported TS.
     */
    public func data(onlyAcceptedTS:String? = nil) -> Data {
        // ABSTRACT SYNTAX Data
        var asData = Data()
        
        if self.abstractSyntax != nil {
            let asLength = UInt16(self.abstractSyntax.data(using: .utf8)!.count)
            asData.append(uint8: ItemType.abstractSyntax.rawValue, bigEndian: true) // 30H
            asData.append(byte: 0x00)
            asData.append(uint16: asLength, bigEndian: true)
            asData.append(self.abstractSyntax.data(using: .utf8)!)
        }
        
        // TRANSFER SYNTAXES Data
        var tsData = Data()        
        if onlyAcceptedTS != nil {
            let tsLength = UInt16(onlyAcceptedTS!.data(using: .utf8)!.count)
            tsData.append(uint8: ItemType.transferSyntax.rawValue, bigEndian: true)
            tsData.append(byte: 0x00) // RESERVED
            tsData.append(uint16: tsLength, bigEndian: true)
            tsData.append(onlyAcceptedTS!.data(using: .utf8)!)
        } else {
            for ts in self.transferSyntaxes {
                let tsLength = UInt16(ts.data(using: .utf8)!.count)
                tsData.append(uint8: ItemType.transferSyntax.rawValue, bigEndian: true)
                tsData.append(byte: 0x00) // RESERVED
                tsData.append(uint16: tsLength, bigEndian: true)
                tsData.append(ts.data(using: .utf8)!)
            }
        }
        
        // Presentation Context
        var pcData = Data()
        if self.abstractSyntax == nil {
            pcData.append(uint8: ItemType.acPresentationContext.rawValue, bigEndian: true)
        }else {
            pcData.append(uint8: ItemType.rqPresentationContext.rawValue, bigEndian: true)
        }
        pcData.append(byte: 0x00) // RESERVED
        
        let pcLength = UInt16(4 + asData.count + tsData.count)
        pcData.append(uint16: pcLength, bigEndian: true)
        
        pcData.append(uint8: self.contextID, bigEndian: true) // Presentation Context ID
        pcData.append(byte: 0x00)
        
        if let r = self.result {
            pcData.append(uint8: r)
        } else {
            pcData.append(byte: 0x00)
        }
        
        pcData.append(byte: 0x00)
        pcData.append(asData)
        pcData.append(tsData)
        
        return pcData
    }
}
