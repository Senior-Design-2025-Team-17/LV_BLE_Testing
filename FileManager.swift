//
//  FileManager.swift
//  LV_BLE_testing
//
//  Created by Sydney Chang on 3/23/25.
//

import Foundation
import UIKit
import UniformTypeIdentifiers

protocol FileManagerDelegate: AnyObject {
    func fileManager(didSelectFile url: URL, data: Data)
    func fileManager(didSaveFile url: URL)
    func fileManager(didUpdateStatus status: String)
}

class BLEFileManager: NSObject {
    weak var delegate: FileManagerDelegate?
    private var parentViewController: UIViewController?
    private var receivedData = NSMutableData()
    
    init(parentViewController: UIViewController) {
        super.init()
        self.parentViewController = parentViewController
    }
    
    func selectFile() {
        guard let parentViewController = parentViewController else { return }
        
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.data, UTType.content, UTType.item, UTType.text], asCopy: true)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        parentViewController.present(documentPicker, animated: true)
    }
    
    func appendReceivedData(_ data: Data) {
        receivedData.append(data)
        delegate?.fileManager(didUpdateStatus: "Receiving data: \(receivedData.length) bytes")
    }
    
    func saveReceivedData() -> URL? {
        guard receivedData.length > 0 else {
            delegate?.fileManager(didUpdateStatus: "No data to save")
            return nil
        }
        
        // make temp url
        
        let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let temporaryFileURL = temporaryDirectoryURL.appendingPathComponent("receivedFile.dat")
        
        // write data to the file
        
        do {
            try receivedData.write(to: temporaryFileURL, options: .atomic)
            delegate?.fileManager(didUpdateStatus: "File saved: \(temporaryFileURL.lastPathComponent)")
            delegate?.fileManager(didSaveFile: temporaryFileURL)
            return temporaryFileURL
        } catch {
            delegate?.fileManager(didUpdateStatus: "Error saving file: \(error.localizedDescription)")
            return nil
        }
    }
    
    func openFile(_ url: URL) {
        // unsure if this is needed?
        
        guard let parentViewController = parentViewController else { return }
        
        let documentInteractionController = UIDocumentInteractionController(url: url)
        documentInteractionController.delegate = self
        documentInteractionController.presentPreview(animated: true)
    }
    
    func clearReceivedData() {
        receivedData = NSMutableData()
    }
    
    func getReceivedDataSize() -> Int {
        return receivedData.length
    }
}

// MARK: - UIDocumentPickerDelegate

extension BLEFileManager: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        
        // document data access
        
        do {
            let fileData = try Data(contentsOf: url)
            delegate?.fileManager(didSelectFile: url, data: fileData)
        } catch {
            delegate?.fileManager(didUpdateStatus: "Error loading file: \(error.localizedDescription)")
        }
    }
}

// MARK: - UIDocumentInteractionControllerDelegate

extension BLEFileManager: UIDocumentInteractionControllerDelegate {
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return parentViewController!
    }
}
