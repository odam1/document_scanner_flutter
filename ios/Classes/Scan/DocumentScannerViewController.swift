//
//  DocumentScannerViewController.swift
//  document_scanner
//
//  Created by ODAM COURAGE on 31/05/2021.
//

import UIKit
import AVFoundation


public final class DocumentScannerViewController: UIViewController {
    
    private var captureSessionManager: CaptureSessionManagerCustom?
    private let videoPreviewLayer = AVCaptureVideoPreviewLayer()
    
    /// The view that shows the focus rectangle (when the user taps to focus, similar to the Camera app)
    private var focusRectangle: FocusRectangleView!
    
    /// The view that draws the detected rectangles.
    private let quadView = QuadrilateralView()
    
    private var autoScanEnable: Bool = true
    private var cameraFlashMode: CameraFlashMode = .auto
    
    init(enableAutoScan: Bool, cameraFlashMode: CameraFlashMode) {
        self.autoScanEnable = enableAutoScan
        self.cameraFlashMode = cameraFlashMode
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func getCurrentCaptureSession() -> CaptureSession {
        let session = CaptureSession.current
        session.isAutoScanEnabled = self.autoScanEnable
        return session
    }
    

    // MARK: - Life Cycle

    override public func viewDidLoad() {
        super.viewDidLoad()
        
        title = nil
        view.backgroundColor = UIColor.black
        
        setupViews()
        setupConstraints()
        
        captureSessionManager = CaptureSessionManagerCustom(videoPreviewLayer: videoPreviewLayer, delegate: self)
        captureSessionManager?.cameraFlashMode = self.cameraFlashMode
        
        toggleFlash(mode: self.cameraFlashMode, saveMode: true)
        
        NotificationCenter.default.addObserver(self, selector: #selector(subjectAreaDidChange), name: Notification.Name.AVCaptureDeviceSubjectAreaDidChange, object: nil)
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //setNeedsStatusBarAppearanceUpdate()
        
        self.getCurrentCaptureSession().isEditing = false
        quadView.removeQuadrilateral()
        captureSessionManager?.start()
        UIApplication.shared.isIdleTimerDisabled = true
         
    }
    
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        videoPreviewLayer.frame = view.layer.bounds
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
        
        captureSessionManager?.stop()
        guard let device = AVCaptureDevice.default(for: AVMediaType.video) else { return }
        if device.torchMode == .on {
            toggleFlash(mode: .off)
        }
    }
    
    // MARK: - Setups
    
    private func setupViews() {
        view.backgroundColor = .darkGray
        view.layer.addSublayer(videoPreviewLayer)
        quadView.translatesAutoresizingMaskIntoConstraints = false
        quadView.editable = false
        quadView.strokeColor = UIColor.systemBlue.cgColor
        
        view.addSubview(quadView) 
    }
     
    
    private func setupConstraints() {
        var quadViewConstraints = [NSLayoutConstraint]()
        
        quadViewConstraints = [
            quadView.topAnchor.constraint(equalTo: view.topAnchor),
            view.bottomAnchor.constraint(equalTo: quadView.bottomAnchor),
            view.trailingAnchor.constraint(equalTo: quadView.trailingAnchor),
            quadView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        ]
        
        NSLayoutConstraint.activate(quadViewConstraints)
    }
    
    // MARK: - Tap to Focus
    
    /// Called when the AVCaptureDevice detects that the subject area has changed significantly. When it's called, we reset the focus so the camera is no longer out of focus.
    @objc private func subjectAreaDidChange() {
        /// Reset the focus and exposure back to automatic
        do {
            try self.getCurrentCaptureSession().resetFocusToAuto()
        } catch {
            let error = ImageScannerControllerError.inputDevice
            guard let captureSessionManager = captureSessionManager else { return }
            captureSessionManager.delegate?.captureSessionManager(captureSessionManager, didFailWithError: error)
            return
        }
        
        /// Remove the focus rectangle if one exists
        self.getCurrentCaptureSession().removeFocusRectangleIfNeeded(focusRectangle, animated: true)
    }
    
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard  let touch = touches.first else { return }
        let touchPoint = touch.location(in: view)
        let convertedTouchPoint: CGPoint = videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: touchPoint)
        
        self.getCurrentCaptureSession().removeFocusRectangleIfNeeded(focusRectangle, animated: false)
        
        focusRectangle = FocusRectangleView(touchPoint: touchPoint)
        view.addSubview(focusRectangle)
        
        do {
            try self.getCurrentCaptureSession().setFocusPointToTapPoint(convertedTouchPoint)
        } catch {
            let error = ImageScannerControllerError.inputDevice
            guard let captureSessionManager = captureSessionManager else { return }
            captureSessionManager.delegate?.captureSessionManager(captureSessionManager, didFailWithError: error)
            return
        }
    }
    
    // MARK: - Actions
    
    func captureImage() {
        let settings = AVCapturePhotoSettings()
        switch self.cameraFlashMode {
        case .on:
            settings.flashMode = .on
            break
        case .off:
            settings.flashMode = .off
            break
        case .auto:
            settings.flashMode = .auto
            break
        case .torch:
            break
        }
        captureSessionManager?.capturePhoto(with: settings)
    }
    
    func stopSession() {
        self.captureSessionManager?.stop()
    }
    
    func toggleAutoScan(auto: Bool) {
        self.autoScanEnable = auto
        self.getCurrentCaptureSession().isAutoScanEnabled = auto
    }
    
    func toggleFlash(mode: CameraFlashMode, saveMode: Bool = false) {
        if saveMode {
            self.cameraFlashMode = mode
            self.captureSessionManager?.cameraFlashMode = mode
        }
        
        guard let device = self.getCurrentCaptureSession().device, device.isTorchAvailable else { return }
        do {
            try device.lockForConfiguration()
        } catch {
            return
        }
        
        defer {
            device.unlockForConfiguration()
        }
        
        if mode == .torch {
            device.torchMode = .on
        } else {
            device.torchMode = .off
        }
    }
    
}

extension DocumentScannerViewController: RectangleDetectionDelegateProtocol {
    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didFailWithError error: Error) {
        DispatchQueue.main.async {[weak self] in
            guard let controller = self?.navigationController as? DocumentScannerController else {
                return
            }
            controller.documentScannerDelegate?.documentScannerController(controller, didFailWithError: error)
        }
    }
    
    func didStartCapturingPicture(for captureSessionManager: CaptureSessionManager) {
        stopSession()
        if let controller = self.navigationController as? DocumentScannerController {
            controller.documentScannerDelegate?.documentScannerController(controller, didStartCapturingPicture: true)
        }
    }
    
    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didCapturePicture picture: UIImage, withQuad quad: Quadrilateral?) {
         
        DispatchQueue.global(qos: .background).sync {[weak self] in
            let image = picture.applyingPortraitOrientation()
            let originalImage = ImageScannerScan(image: image)
            var croppedImage: ImageScannerScan? = nil
            if let quad = quad, let cropped = SwiftDocumentScannerPlugin.cropImage(image: image, corners: quad){
                croppedImage = ImageScannerScan(image: cropped)
            }
            
            let results = DocumentScannerResults(originalScan: originalImage, croppedScan: croppedImage, detectedRectangle: quad)
            
            DispatchQueue.main.async {
                guard let controller = self?.navigationController as? DocumentScannerController else {
                    return
                }
                controller.documentScannerDelegate?.documentScannerController(controller, didFinishScanningWithResults: results)
            }
        }
        
    }
    
    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didDetectQuad quad: Quadrilateral?, _ imageSize: CGSize) {
        guard let quad = quad else {
            // If no quad has been detected, we remove the currently displayed on on the quadView.
            quadView.removeQuadrilateral()
            return
        }
        
        let portraitImageSize = CGSize(width: imageSize.height, height: imageSize.width)
        
        let scaleTransform = CGAffineTransform.scaleTransform(forSize: portraitImageSize, aspectFillInSize: quadView.bounds.size)
        let scaledImageSize = imageSize.applying(scaleTransform)
        
        let rotationTransform = CGAffineTransform(rotationAngle: CGFloat.pi / 2.0)

        let imageBounds = CGRect(origin: .zero, size: scaledImageSize).applying(rotationTransform)

        let translationTransform = CGAffineTransform.translateTransform(fromCenterOfRect: imageBounds, toCenterOfRect: quadView.bounds)
        
        let transforms = [scaleTransform, rotationTransform, translationTransform]
        
        let transformedQuad = quad.applyTransforms(transforms)
        
        quadView.drawQuadrilateral(quad: transformedQuad, animated: true)
    }
    
}

private class CaptureSessionManagerCustom: CaptureSessionManager {
    //private let photoOutput = AVCapturePhotoOutput()
    
    fileprivate var cameraFlashMode: CameraFlashMode = .auto
    
    override func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        switch self.cameraFlashMode {
        case .on:
            settings.flashMode = .on
            break
        case .off:
            settings.flashMode = .off
            break
        case .auto:
            settings.flashMode = .auto
            break
        case .torch:
            break
        }
        self.capturePhoto(with: settings)
    }
    
    func capturePhoto(with settings: AVCapturePhotoSettings) {
        guard let connection = photoOutput.connection(with: .video), connection.isEnabled, connection.isActive else {
            let error = ImageScannerControllerError.capture
            delegate?.captureSessionManager(self, didFailWithError: error)
            return
        }
        CaptureSession.current.setImageOrientation()
       
        settings.isHighResolutionPhotoEnabled = true
        settings.isAutoStillImageStabilizationEnabled = true
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

public struct DocumentScannerResults {
     
    public let originalScan: ImageScannerScan
    public let originalData: Data
     
    public let croppedScan: ImageScannerScan?
    public let croppedData: Data?
     
    public let detectedRectangle: Quadrilateral?
    
    init(originalScan: ImageScannerScan, croppedScan: ImageScannerScan?, detectedRectangle: Quadrilateral?) {
        self.originalScan = originalScan
        self.croppedScan = croppedScan
        self.detectedRectangle = detectedRectangle
        
        self.originalData = originalScan.image.jpegData(compressionQuality: 100)!
        self.croppedData = croppedScan?.image.jpegData(compressionQuality: 100)
    }
}

