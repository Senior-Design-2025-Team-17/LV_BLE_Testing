import UIKit
import CoreBluetooth

class ViewController: UIViewController {
    
    // MARK: - UI Elements
    
    private let peripheralToggle = UISwitch()
    private let centralToggle = UISwitch()
    private let bluetoothToggle = UISwitch()
    private let uploadButton = UIButton(type: .system)
    private let openFileButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    
    // MARK: - Managers
    
    private var centralManager: BLECentralManager!
    private var peripheralManager: BLEPeripheralManager!
    private var fileManager: BLEFileManager!
    
    // MARK: - Properties
    
    private var receivedFileURL: URL?
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        // initialization of managers
        
        centralManager = BLECentralManager()
        centralManager.delegate = self
        
        peripheralManager = BLEPeripheralManager()
        peripheralManager.delegate = self
        
        fileManager = BLEFileManager(parentViewController: self)
        fileManager.delegate = self
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = .white
        
        // labels
        
        let peripheralLabel = UILabel()
        peripheralLabel.text = "Peripheral Mode"
        peripheralLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let centralLabel = UILabel()
        centralLabel.text = "Central Mode"
        centralLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let bluetoothLabel = UILabel()
        bluetoothLabel.text = "Bluetooth"
        bluetoothLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // toggles
        
        peripheralToggle.translatesAutoresizingMaskIntoConstraints = false
        peripheralToggle.addTarget(self, action: #selector(peripheralToggleChanged), for: .valueChanged)
        
        centralToggle.translatesAutoresizingMaskIntoConstraints = false
        centralToggle.addTarget(self, action: #selector(centralToggleChanged), for: .valueChanged)
        
        bluetoothToggle.translatesAutoresizingMaskIntoConstraints = false
        bluetoothToggle.addTarget(self, action: #selector(bluetoothToggleChanged), for: .valueChanged)
        
        // buttons
        
        uploadButton.setTitle("Upload & Send File", for: .normal)
        uploadButton.translatesAutoresizingMaskIntoConstraints = false
        uploadButton.addTarget(self, action: #selector(uploadButtonTapped), for: .touchUpInside)
        
        openFileButton.setTitle("Open Received File", for: .normal)
        openFileButton.translatesAutoresizingMaskIntoConstraints = false
        openFileButton.addTarget(self, action: #selector(openFileButtonTapped), for: .touchUpInside)
        openFileButton.isEnabled = false
        
        // status labels
        
        statusLabel.text = "Ready"
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // activity indicator
        
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        
        // subviews
        
        view.addSubview(peripheralLabel)
        view.addSubview(peripheralToggle)
        view.addSubview(centralLabel)
        view.addSubview(centralToggle)
        view.addSubview(bluetoothLabel)
        view.addSubview(bluetoothToggle)
        view.addSubview(uploadButton)
        view.addSubview(openFileButton)
        view.addSubview(statusLabel)
        view.addSubview(activityIndicator)
        
        // constraints
        
        NSLayoutConstraint.activate([
            // MODES
            // peripheral
            
            peripheralLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            peripheralLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            peripheralToggle.centerYAnchor.constraint(equalTo: peripheralLabel.centerYAnchor),
            peripheralToggle.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // central
            
            centralLabel.topAnchor.constraint(equalTo: peripheralLabel.bottomAnchor, constant: 30),
            centralLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            centralToggle.centerYAnchor.constraint(equalTo: centralLabel.centerYAnchor),
            centralToggle.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Bluetooth
            
            bluetoothLabel.topAnchor.constraint(equalTo: centralLabel.bottomAnchor, constant: 30),
            bluetoothLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            bluetoothToggle.centerYAnchor.constraint(equalTo: bluetoothLabel.centerYAnchor),
            bluetoothToggle.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // buttons
            
            uploadButton.topAnchor.constraint(equalTo: bluetoothLabel.bottomAnchor, constant: 50),
            uploadButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            uploadButton.widthAnchor.constraint(equalToConstant: 200),
            uploadButton.heightAnchor.constraint(equalToConstant: 44),
            
            openFileButton.topAnchor.constraint(equalTo: uploadButton.bottomAnchor, constant: 20),
            openFileButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            openFileButton.widthAnchor.constraint(equalToConstant: 200),
            openFileButton.heightAnchor.constraint(equalToConstant: 44),
            
            // status type
            
            statusLabel.topAnchor.constraint(equalTo: openFileButton.bottomAnchor, constant: 40),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // activity indicator
            
            activityIndicator.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 20),
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    // MARK: - UI Actions
    
    @objc private func peripheralToggleChanged() {
        if peripheralToggle.isOn {
            centralToggle.isOn = false
            peripheralManager.startAdvertising()
        } else {
            peripheralManager.stopAdvertising()
        }
        updateStatus("Mode changed: Peripheral \(peripheralToggle.isOn ? "ON" : "OFF")")
    }
    
    @objc private func centralToggleChanged() {
        if centralToggle.isOn {
            peripheralToggle.isOn = false
            centralManager.startScanning()
            activityIndicator.startAnimating()
        } else {
            centralManager.stopScanning()
            activityIndicator.stopAnimating()
        }
        updateStatus("Mode changed: Central \(centralToggle.isOn ? "ON" : "OFF")")
    }
    
    @objc private func bluetoothToggleChanged() {
        // enable/disable functionality
        
        if !bluetoothToggle.isOn {
            peripheralToggle.isOn = false
            centralToggle.isOn = false
            peripheralToggle.isEnabled = false
            centralToggle.isEnabled = false
            uploadButton.isEnabled = false
            peripheralManager.stopAdvertising()
            centralManager.stopScanning()
            activityIndicator.stopAnimating()
            updateStatus("Bluetooth disabled. Please turn on Bluetooth to use the app.")
        } else {
            peripheralToggle.isEnabled = true
            centralToggle.isEnabled = true
            uploadButton.isEnabled = true
            updateStatus("Bluetooth enabled. Select mode to begin.")
        }
    }
    
    @objc private func uploadButtonTapped() {
        if peripheralToggle.isOn || centralToggle.isOn {
            fileManager.selectFile()
        } else {
            updateStatus("Please select either Peripheral or Central mode first")
        }
    }
    
    @objc private func openFileButtonTapped() {
        guard let receivedFileURL = fileManager.saveReceivedData() else {
            updateStatus("No file to open")
            return
        }
        
        self.receivedFileURL = receivedFileURL
        fileManager.openFile(receivedFileURL)
    }
    
    // MARK: - Helper Methods
    
    private func updateStatus(_ message: String) {
        DispatchQueue.main.async {
            self.statusLabel.text = message
            print(message)
        }
    }
}

// MARK: - BLECentralManagerDelegate

extension ViewController: BLECentralManagerDelegate {
    func centralManagerDidUpdateState(_ state: CBManagerState) {
        switch state {
        case .poweredOn:
            if centralToggle.isOn {
                centralManager.startScanning()
                activityIndicator.startAnimating()
            }
        case .poweredOff:
            updateStatus("Bluetooth is powered off")
            bluetoothToggle.isOn = false
            activityIndicator.stopAnimating()
        case .unsupported:
            updateStatus("Bluetooth is not supported on this device")
            activityIndicator.stopAnimating()
        default:
            updateStatus("Bluetooth state: \(state.rawValue)")
        }
    }
    
    func centralManagerDidDiscover(peripheral: CBPeripheral) {
        updateStatus("Discovered peripheral: \(peripheral.name ?? "Unknown")")
    }
    
    func centralManagerDidConnect(to peripheral: CBPeripheral) {
        updateStatus("Connected to: \(peripheral.name ?? "Unknown")")
        activityIndicator.stopAnimating()
    }
    
    func centralManagerDidDisconnect(from peripheral: CBPeripheral) {
        updateStatus("Disconnected from peripheral")
    }
    
    func centralManagerDidFailToConnect(to peripheral: CBPeripheral, error: Error?) {
        updateStatus("Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
        activityIndicator.stopAnimating()
    }
    
    func centralManager(didReceiveData data: Data) {
        fileManager.appendReceivedData(data)
        openFileButton.isEnabled = true
    }
    
    func centralManager(didUpdateStatus status: String) {
        updateStatus(status)
    }
}

// MARK: - BLEPeripheralManagerDelegate

extension ViewController: BLEPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ state: CBManagerState) {
        switch state {
        case .poweredOn:
            if peripheralToggle.isOn {
                peripheralManager.startAdvertising()
            }
        case .poweredOff:
            updateStatus("Bluetooth is powered off")
            bluetoothToggle.isOn = false
        case .unsupported:
            updateStatus("Bluetooth is not supported on this device")
        default:
            updateStatus("Bluetooth state: \(state.rawValue)")
        }
    }
    
    func peripheralManagerDidReceiveData(_ data: Data) {
        fileManager.appendReceivedData(data)
        openFileButton.isEnabled = true
    }
    
    func peripheralManager(didUpdateStatus status: String) {
        updateStatus(status)
    }
}

// MARK: - FileManagerDelegate

extension ViewController: FileManagerDelegate {
    func fileManager(didSelectFile url: URL, data: Data) {
        updateStatus("File selected: \(url.lastPathComponent), size: \(data.count) bytes")
        
        if peripheralToggle.isOn {
            peripheralManager.sendFile(data: data)
        } else if centralToggle.isOn {
            centralManager.sendFile(data: data)
        }
    }
    
    func fileManager(didSaveFile url: URL) {
        self.receivedFileURL = url
        updateStatus("File saved successfully")
    }
    
    func fileManager(didUpdateStatus status: String) {
        updateStatus(status)
    }
}
