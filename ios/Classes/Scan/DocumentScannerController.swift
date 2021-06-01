//
//  DocumentScannerController.swift
//  document_scanner
//
//  Created by ODAM COURAGE on 31/05/2021.
//

import Foundation

 
public final class DocumentScannerController: UINavigationController {
    
    /// The object that acts as the delegate of the `DocumentScannerController`.
    public weak var documentScannerDelegate: DocumentScannerControllerDelegate?
    
    private var documentScannerViewController: DocumentScannerViewController?
    
    private var autoScanEnable: Bool = true
    private var cameraFlashMode: CameraFlashMode = .auto
    
    // MARK: - Life Cycle
    
    /// A black UIView, used to quickly display a black screen when the shutter button is presseed.
    internal let blackFlashView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override public var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    init(enableAutoScan: Bool, cameraFlashMode: CameraFlashMode) {
        self.autoScanEnable = enableAutoScan
        self.cameraFlashMode = cameraFlashMode
        
        documentScannerViewController = DocumentScannerViewController(enableAutoScan: enableAutoScan, cameraFlashMode: cameraFlashMode)
        super.init(rootViewController: documentScannerViewController!)
        
        setNavigationBarHidden(true, animated: false)
        self.view.addSubview(blackFlashView)
        setupConstraints()
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func resetScanner() {
        documentScannerViewController = DocumentScannerViewController(enableAutoScan: self.autoScanEnable, cameraFlashMode: self.cameraFlashMode)
        setViewControllers([documentScannerViewController!], animated: false)
    }
    
    private func setupConstraints() {
        let blackFlashViewConstraints = [
            blackFlashView.topAnchor.constraint(equalTo: view.topAnchor),
            blackFlashView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.bottomAnchor.constraint(equalTo: blackFlashView.bottomAnchor),
            view.trailingAnchor.constraint(equalTo: blackFlashView.trailingAnchor)
        ]
        
        NSLayoutConstraint.activate(blackFlashViewConstraints)
    }
    
    internal func flashToBlack() {
        view.bringSubviewToFront(blackFlashView)
        blackFlashView.isHidden = false
        let flashDuration = DispatchTime.now() + 0.05
        DispatchQueue.main.asyncAfter(deadline: flashDuration) {
            self.blackFlashView.isHidden = true
        }
    }
    
    // MARK: - Actions
    
    func captureImage() -> Bool {
        self.flashToBlack()
        self.documentScannerViewController?.captureImage()
        return true
    }
    
    func refreshCamera() -> Bool{
        self.resetScanner()
        return true
    }
    
    func pauseCamera() -> Bool{
        self.documentScannerViewController?.stopSession()
        return true
    }
    
    func changeFlashMode(mode: String) -> Bool {
        guard let flashMode = CameraFlashMode.getCameraFlashMode(from: mode) else {
            return false
        }
        self.cameraFlashMode = flashMode
        self.documentScannerViewController?.toggleFlash(mode: flashMode, saveMode: true)
        return true
    }
    
    func toggleScannerMode(mode: String) -> Bool {
        switch mode {
        case "Auto":
            self.autoScanEnable = true
            self.documentScannerViewController?.toggleAutoScan(auto: true)
            break
        case "Manual":
            self.autoScanEnable = false
            self.documentScannerViewController?.toggleAutoScan(auto: false)
            break
        default:
            return false
        }
        return true
    }
}


public protocol DocumentScannerControllerDelegate: NSObjectProtocol {
    func documentScannerController(_ scanner: DocumentScannerController, didFinishScanningWithResults results: DocumentScannerResults)
    func documentScannerController(_ scanner: DocumentScannerController, didStartCapturingPicture start: Bool)
    func documentScannerController(_ scanner: DocumentScannerController, didFailWithError error: Error)
}

enum CameraFlashMode {
    case on
    case off
    case auto
    case torch
    
    static func getCameraFlashMode(from mode: String) -> CameraFlashMode? {
        switch mode {
        case "On":
            return .on
        case "Off":
            return .off
        case "Auto":
            return .auto
        case "Torch":
            return .torch
        default:
           return nil
        } 
    }
}


