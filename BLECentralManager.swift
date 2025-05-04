//
//  BLECentralManager.swift
//  LV_BLE_testing
//
//  Created by Sydney Chang on 3/23/25.
//

import CoreBluetooth
import Foundation

protocol BLECentralManagerDelegate: AnyObject {
    func centralManagerDidUpdateState(_ state: CBManagerState)
    func centralManagerDidDiscover(peripheral: CBPeripheral)
    func centralManagerDidConnect(to peripheral: CBPeripheral)
    func centralManagerDidDisconnect(from peripheral: CBPeripheral)
    func centralManagerDidFailToConnect(to peripheral: CBPeripheral, error: Error?)
    func centralManager(didReceiveData data: Data)
    func centralManager(didUpdateStatus status: String)
}

class BLECentralManager: NSObject {
    // MARK: - Properties
    
    private var centralManager: CBCentralManager?
    private var discoveredPeripherals = [CBPeripheral]()
    private var connectedPeripheral: CBPeripheral?
    private var transferCharacteristic: CBCharacteristic?
    
    private var scanTimer: Timer?
    private var fileData: Data?
    private var sendDataIndex: Int = 0
    
    weak var delegate: BLECentralManagerDelegate?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Public Methods
    
    func startScanning() {
        guard let centralManager = centralManager, centralManager.state == .poweredOn else {
            delegate?.centralManager(didUpdateStatus: "Bluetooth is not available")
            return
        }
        
        // peripheral scan
        
        centralManager.scanForPeripherals(withServices: [BLEConstants.serviceUUID], options: nil)
        delegate?.centralManager(didUpdateStatus: "Central mode started. Scanning...")
        
        // timeout
        
        scanTimer = Timer.scheduledTimer(timeInterval: BLEConstants.timeoutInterval, target: self, selector: #selector(scanTimeout), userInfo: nil, repeats: false)
    }
    
    func stopScanning() {
        centralManager?.stopScan()
        if let connectedPeripheral = connectedPeripheral {
            centralManager?.cancelPeripheralConnection(connectedPeripheral)
        }
        discoveredPeripherals.removeAll()
        scanTimer?.invalidate()
        delegate?.centralManager(didUpdateStatus: "Central mode stopped")
    }
    
    func sendFile(data: Data) {
        self.fileData = data
        self.sendDataIndex = 0
        
        if transferCharacteristic != nil && connectedPeripheral != nil {
            sendData()
        } else {
            delegate?.centralManager(didUpdateStatus: "No connected device to send data to")
        }
    }
    
    // MARK: - Private Methods
    
    @objc private func scanTimeout() {
        if discoveredPeripherals.isEmpty {
            centralManager?.stopScan()
            delegate?.centralManager(didUpdateStatus: "Scan timed out. No devices found.")
        }
    }
    
    private func sendData() {
        guard let fileData = fileData,
              let transferCharacteristic = transferCharacteristic,
              let connectedPeripheral = connectedPeripheral else {
            delegate?.centralManager(didUpdateStatus: "No file or connection ready")
            return
        }
        
        // sent or not?
        
        if sendDataIndex >= fileData.count {
            delegate?.centralManager(didUpdateStatus: "File sent successfully")
            sendDataIndex = 0
            return
        }
        

        let endIndex = min(sendDataIndex + BLEConstants.chunkSize, fileData.count)
        let chunk = fileData.subdata(in: sendDataIndex..<endIndex)
        

        connectedPeripheral.writeValue(chunk, for: transferCharacteristic, type: .withResponse)
        sendDataIndex = endIndex
    }
}

// MARK: - CBCentralManagerDelegate

extension BLECentralManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        delegate?.centralManagerDidUpdateState(central.state)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        scanTimer?.invalidate()
        
        if !discoveredPeripherals.contains(peripheral) {
            discoveredPeripherals.append(peripheral)
            delegate?.centralManagerDidDiscover(peripheral: peripheral)
            
            // peripheral connecting
            
            central.connect(peripheral, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        delegate?.centralManagerDidConnect(to: peripheral)
        connectedPeripheral = peripheral
        connectedPeripheral?.delegate = self
        
        // service discovery
        connectedPeripheral?.discoverServices([BLEConstants.serviceUUID])
        
        // prevent scan
        central.stopScan()
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        delegate?.centralManagerDidFailToConnect(to: peripheral, error: error)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        delegate?.centralManagerDidDisconnect(from: peripheral)
        connectedPeripheral = nil
        transferCharacteristic = nil
    }
}

// MARK: - CBPeripheralDelegate

extension BLECentralManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            delegate?.centralManager(didUpdateStatus: "Error discovering services: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else { return }
        
        for service in services {
            peripheral.discoverCharacteristics([BLEConstants.characteristicUUID], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            delegate?.centralManager(didUpdateStatus: "Error discovering characteristics: \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.uuid == BLEConstants.characteristicUUID {
                transferCharacteristic = characteristic
                
                // Subscribe to the characteristic
                
                peripheral.setNotifyValue(true, for: characteristic)
                
                delegate?.centralManager(didUpdateStatus: "Ready to transfer data")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            delegate?.centralManager(didUpdateStatus: "Error receiving data: \(error.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value else { return }
        
        // data delegation
        
        delegate?.centralManager(didReceiveData: data)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            delegate?.centralManager(didUpdateStatus: "Error sending data: \(error.localizedDescription)")
            return
        }
        
        // Continue sending
        sendData()
    }
}
