//
//  UserInfo.swift
//  DcmSwift
//
//  Created by Rafael Warnault, OPALE on 02/05/2019.
//  Copyright © 2019 OPALE. All rights reserved.
//

import Foundation

/**
 User Information Item Structure
 
 TODO: rewrite with OffsetInputStream
 
 User Information consists of:
 - item type
 - 1 reserved byte
 - 2 item length
 - user data
 
 http://dicom.nema.org/dicom/2013/output/chtml/part08/sect_9.3.html#sect_9.3.3.3
 */
public class UserInfo {
    public var implementationUID:String = DicomConstants.implementationUID
    public var implementationVersion:String = DicomConstants.implementationVersion
    public var maxPDULength:Int = 16384
    
    public init(implementationVersion:String = DicomConstants.implementationVersion, implementationUID:String = DicomConstants.implementationUID, maxPDULength:Int = 16384) {
        self.implementationVersion = implementationVersion
        self.implementationUID = implementationUID
        self.maxPDULength = maxPDULength
    }
    
    /**
     - Remark: Why read max pdu length ? it's only a sub field in user info
     */
    public init?(data:Data) {
        let uiItemData = data
        
        var offset = 0
        while offset < uiItemData.count-1 {
            // read type
            let uiItemType = uiItemData.subdata(in: offset..<offset+1).toInt8(byteOrder: .BigEndian)
            let uiItemLength = uiItemData.subdata(in: offset+2..<offset+4).toInt16(byteOrder: .BigEndian)
            offset += 4
            
            if uiItemType == ItemType.maxPduLength.rawValue {
                let maxPDU = uiItemData.subdata(in: offset..<offset+Int(uiItemLength)).toInt32(byteOrder: .BigEndian)
                self.maxPDULength = Int(maxPDU)
                Logger.verbose("    -> Local  Max PDU: \(DicomConstants.maxPDULength)", "UserInfo")
                Logger.verbose("    -> Remote Max PDU: \(self.maxPDULength)", "UserInfo")
            }
            else if uiItemType == ItemType.implClassUID.rawValue {
                let impClasslUID = uiItemData.subdata(in: offset..<offset+Int(uiItemLength)).toString()
                self.implementationUID = impClasslUID
                //Logger.info("    -> Implementation class UID: \(self.association!.remoteImplementationUID ?? "")")
            }
            else if uiItemType == ItemType.implVersionName.rawValue {
                let impVersion = uiItemData.subdata(in: offset..<offset+Int(uiItemLength)).toString()
                self.implementationVersion = impVersion
                //Logger.info("    -> Implementation version: \(self.association!.remoteImplementationVersion ?? "")")
                
            }
            
            offset += Int(uiItemLength)
        }
    }
    
    
    public func data() -> Data {
        var data = Data()
        
        // Max PDU length item
        var pduData = Data()
        var itemLength = UInt16(4).bigEndian
        var pduLength = UInt32(self.maxPDULength).bigEndian
        pduData.append(Data(repeating: ItemType.maxPduLength.rawValue, count: 1)) // 51H (Max PDU Length)
        pduData.append(Data(repeating: 0x00, count: 1)) // 00H
        pduData.append(UnsafeBufferPointer(start: &itemLength, count: 1)) // Length
        pduData.append(UnsafeBufferPointer(start: &pduLength, count: 1)) // PDU Length
        
        // TODO: Application UID and version
        // Items
        var length = UInt16(pduData.count).bigEndian
        data.append(Data(repeating: ItemType.userInfo.rawValue, count: 1)) // 50H
        data.append(Data(repeating: 0x00, count: 1)) // 00H
        data.append(UnsafeBufferPointer(start: &length, count: 1)) // Length
        data.append(pduData) // Items
        
        return data
    }
}
