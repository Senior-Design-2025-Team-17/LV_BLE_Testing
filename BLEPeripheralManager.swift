//
//  BLEPeripheralManager.swift
//  LV_BLE_testing
//
//  Created by Sydney Chang on 3/23/25.
//

import CoreBluetooth
import Foundation

protocol BLEPeripheralManagerDelegate: AnyObject {
    func peripheralManagerDidUpdateState(_ state: CBManagerState)
    func peripheralManagerDidReceiveData(_ data: Data)
    func peripheralManager(didUpdateStatus status: String)
}

class BLEPeripheralManager: NSObject {
    // MARK: - Properties
    
    private var peripheralManager: CBPeripheralManager?
    private var fileData: Data?
    private var sendDataIndex: Int = 0
    private var transferCharacteristic: CBMutableCharacteristic?
    
    weak var delegate: BLEPeripheralManagerDelegate?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Public Methods
    
    func startAdvertising() {
        guard let peripheralManager = peripheralManager, peripheralManager.state == .poweredOn else {
            delegate?.peripheralManager(didUpdateStatus: "Bluetooth is not available")
            return
        }
        
        // creation (services, characteristics)
        
        let transferCharacteristic = CBMutableCharacteristic(
            type: BLEConstants.characteristicUUID,
            properties: [.notify, .writeWithoutResponse, .write],
            value: nil,
            permissions: [.readable, .writeable]
        )
        
        self.transferCharacteristic = transferCharacteristic
        
        let transferService = CBMutableService(type: BLEConstants.serviceUUID, primary: true)
        transferService.characteristics = [transferCharacteristic]
        
        peripheralManager.add(transferService)
        
        // begin advertisement
        
        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [BLEConstants.serviceUUID],
            CBAdvertisementDataLocalNameKey: BLEConstants.advertisingName
        ])
        
        delegate?.peripheralManager(didUpdateStatus: "Peripheral mode started. Advertising...")
    }
    
    func stopAdvertising() {
        peripheralManager?.stopAdvertising()
        delegate?.peripheralManager(didUpdateStatus: "Peripheral mode stopped")
    }
    
    func sendFile(data: Data) {
        self.fileData = data
        self.sendDataIndex = 0
        delegate?.peripheralManager(didUpdateStatus: "File loaded. Ready to send when central connects.")
    }
    
    // MARK: - Private Methods
    
    private func sendData() {
        guard let fileData = fileData,
              let peripheralManager = peripheralManager,
              let transferCharacteristic = transferCharacteristic else {
            delegate?.peripheralManager(didUpdateStatus: "No file selected or characteristic available")
            return
        }
        
        // sent?
        
        if sendDataIndex >= fileData.count {
            delegate?.peripheralManager(didUpdateStatus: "File sent successfully")
            sendDataIndex = 0
            return
        }
        

        let endIndex = min(sendDataIndex + BLEConstants.chunkSize, fileData.count)
        let chunk = fileData.subdata(in: sendDataIndex..<endIndex)
        

        let didSend = peripheralManager.updateValue(
            chunk,
            for: transferCharacteristic,
            onSubscribedCentrals: nil
        )
        
        if didSend {
            sendDataIndex = endIndex
            

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.sendData()
            }
        } else {
            // retry
            
        }
    }
}

// MARK: - CBPeripheralManagerDelegate

extension BLEPeripheralManager: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        delegate?.peripheralManagerDidUpdateState(peripheral.state)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if let value = request.value {
                delegate?.peripheralManagerDidReceiveData(value)
                
                // respond
                
                peripheral.respond(to: request, withResult: .success)
            }
        }
    }
    
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        sendData()
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        delegate?.peripheralManager(didUpdateStatus: "Central connected and subscribed")
        
        sendDataIndex = 0
        
        // begin sending
        
        if fileData != nil {
            sendData()
        }
    }
}
