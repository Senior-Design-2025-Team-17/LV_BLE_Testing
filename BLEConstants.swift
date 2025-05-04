//
//  BLEConstants.swift
//  LV_BLE_testing
//
//  Created by Sydney Chang on 3/23/25.
//

import CoreBluetooth

struct BLEConstants {
    // service and characteristic UUIDs
    
    static let serviceUUID = CBUUID(string: "E20A39F4-73F5-4BC4-A12F-17D1AD07A961")
    static let characteristicUUID = CBUUID(string: "08590F7E-DB05-467E-8757-72F6FAEB13D4")
    
    static let chunkSize = 20
    
    static let timeoutInterval: TimeInterval = 10.0
    
    static let advertisingName = "BLE File Transfer"
}
