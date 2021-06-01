//
//  DocumentScannerView.swift
//  document_scanner
//
//  Created by ODAM COURAGE on 18/05/2021.
//

import Flutter
import Foundation
import UIKit
import VisionKit


class DocumentScannerViewFactory: NSObject, FlutterPlatformViewFactory {
    static let METHOD_CHANNEL_NAME = "com.odamsoft.document_scanner";
    
    private let messenger: FlutterBinaryMessenger
    
    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }
    
    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return DocumentScannerView(frame: frame, viewIdentifier: viewId, arguments: args, messenger: messenger)
        
    }
    
}

private class DocumentScannerView: NSObject, FlutterPlatformView, DocumentScannerControllerDelegate  {
    
    private var scannerView: DocumentScannerController?
    
    private var channel: FlutterMethodChannel?
    
    
    init(frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?, messenger: FlutterBinaryMessenger ) {
            super.init()
        
        channel = FlutterMethodChannel(name: DocumentScannerViewFactory.METHOD_CHANNEL_NAME+"#\(viewId)", binaryMessenger: messenger)
        channel!.setMethodCallHandler(methodCallHandler)
        
        //
        var enableAutoScan: Bool = true
        var cameraFlashMode: CameraFlashMode = .auto
        if let args = args as? [String:Any] {
            if let autoScan = args["autoScan"] as? String, autoScan == "Manual" {
                enableAutoScan = false
            }
            if let mode = args["flashMode"] as? String {
                cameraFlashMode = CameraFlashMode.getCameraFlashMode(from: mode) ?? cameraFlashMode
            }
        }
        
        self.scannerView = DocumentScannerController(enableAutoScan: enableAutoScan, cameraFlashMode: cameraFlashMode)
        self.scannerView!.documentScannerDelegate = self
            
    }
    
    
    func view() -> UIView {
        return self.scannerView!.view
    }
    
    
    private func isReady() -> Bool {
        return channel != nil
    }
    
    
    private func methodCallHandler(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        var resp: Any? = nil
        switch call.method {
            case "captureImage":
                resp = self.scannerView?.captureImage()
                break
            case "refreshCamera":
                resp = self.scannerView?.refreshCamera()
                break
            case "pauseCamera":
                resp = self.scannerView?.pauseCamera()
                break;
            case "changeFlashMode":
                if let mode = call.arguments as? String {
                    resp = self.scannerView?.changeFlashMode(mode: mode)
                }
                break
            case "toggleScannerMode":
                if let mode = call.arguments as? String {
                    resp = self.scannerView?.toggleScannerMode(mode: mode)
                }
                break                
            case "dispose":
                channel?.setMethodCallHandler(nil)
                break
            default:
                break
        }
        result(resp)
    }
    
    func documentScannerController(_ scanner: DocumentScannerController, didFinishScanningWithResults results: DocumentScannerResults) {
        var data = [String:Any]()
        
        let initialImage = results.originalScan.image
        let initialImageSize = [initialImage.size.width, initialImage.size.height]
        data["initialImage"] = results.originalData
        data["initialImageSize"] = initialImageSize
        
        if let cropImage = results.croppedScan?.image {
            let cropImageSize = [cropImage.size.width, cropImage.size.height]
            data["cropImage"] = results.croppedData
            data["cropImageSize"] = cropImageSize
        }
        
        if let corners = results.detectedRectangle {
            data["corners"] = [
                [corners.topLeft.x, corners.topLeft.y],
                [corners.topRight.x, corners.topRight.y],
                [corners.bottomRight.x, corners.bottomRight.y],
                [corners.bottomLeft.x, corners.bottomLeft.y],
            ]
        }
        self.channel?.invokeMethod("onCapture", arguments: data)    
    }
    
    func documentScannerController(_ scanner: DocumentScannerController, didStartCapturingPicture start: Bool) {
        self.channel?.invokeMethod("isCapturing", arguments: nil)
    }
    
    func documentScannerController(_ scanner: DocumentScannerController, didFailWithError error: Error) {
        print(error)
        self.channel?.invokeMethod("failed", arguments: nil)
    }
    
}
