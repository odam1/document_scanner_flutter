import Flutter
import UIKit 

public class SwiftDocumentScannerPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
      let channel = FlutterMethodChannel(name: DocumentScannerViewFactory.METHOD_CHANNEL_NAME, binaryMessenger: registrar.messenger())
      let instance = SwiftDocumentScannerPlugin()
      registrar.addMethodCallDelegate(instance, channel: channel)
      
      let viewFactory = DocumentScannerViewFactory(messenger: registrar.messenger())
      registrar.register(viewFactory, withId: DocumentScannerViewFactory.METHOD_CHANNEL_NAME+"#view")
        
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
      switch call.method {
        case "cropPicture":
            SwiftDocumentScannerPlugin.cropPicture(call, result: result)
            break
        case "detectPaper":
            SwiftDocumentScannerPlugin.detectPaper(call, result: result)
            break
        default:
            result(nil)
      }
    }
    
    // MARK: - Document processing functions
      
    private static func cropPicture(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let data = call.arguments as? Dictionary<String, Any> else {
            result(nil)
            return
        }
        guard let bytes = data["bytes"] as? Data, let corners = data["corners"] as? Array<Array<Double>>, corners.count == 4 else {
            result(nil)
            return
        }
        guard let image = UIImage(data: bytes) else {
            result(nil)
            return
        }
        
        DispatchQueue.global(qos: .background).async {[self] in
            let topLeft = CGPoint(x: corners[0][0], y: corners[0][1])
            let topRight = CGPoint(x: corners[1][0], y: corners[1][1])
            let bottomRight = CGPoint(x: corners[2][0], y: corners[2][1])
            let bottomLeft = CGPoint(x: corners[3][0], y: corners[3][1])
            
            let quad = Quadrilateral(topLeft: topLeft, topRight: topRight, bottomRight: bottomRight, bottomLeft: bottomLeft)
            
            let croppedImage = self.cropImage(image: image, corners: quad)
            let data = croppedImage?.pngData()
            
            DispatchQueue.main.async {
                result(data)
            }
        }
        
    }
    
    
    private static func detectPaper(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let data = call.arguments as? Dictionary<String, Any> else {
            result(nil)
            return
        }
        guard let bytes = data["bytes"] as? Data, let shouldCrop = data["shouldCrop"] as? Bool else {
            result(nil)
            return
        }
        guard let image = UIImage(data: bytes) else {
            result(nil)
            return            
        }
        
        DispatchQueue.global(qos: .background).async { [self] in
            self.detect(image: image) { (quad) in
                var resp = [String:Any]()
                if let quad = quad {
                    
                    if shouldCrop, let croppedImage = self.cropImage(image: image, corners: quad) {
                        resp["bytes"] = croppedImage.pngData()
                    }
                    resp["corners"] = [
                        [quad.topLeft.x, quad.topLeft.y],
                        [quad.topRight.x, quad.topRight.y],
                        [quad.bottomRight.x, quad.bottomRight.y],
                        [quad.bottomLeft.x, quad.bottomLeft.y]
                    ]
                }
                
                DispatchQueue.main.async {
                    if(resp.isEmpty) {
                        result(nil)
                    }else{
                        result(resp)
                    }
                }
                
            }
            
        }
        
    }
    
    
    static func detect(image: UIImage, completion: @escaping (Quadrilateral?) -> Void) {
        guard let ciImage = CIImage(image: image) else {
            completion(nil)
            return
        }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let orientedImage = ciImage.oriented(forExifOrientation: Int32(orientation.rawValue))
        
        if #available(iOS 11.0, *) {
            // Use the VisionRectangleDetector on iOS 11 to attempt to find a rectangle from the initial image.
            VisionRectangleDetector.rectangle(forImage: ciImage, orientation: orientation) { (quad) in
                let detectedQuad = quad?.toCartesian(withHeight: orientedImage.extent.height)
                completion(detectedQuad)
            }
        } else {
            // Use the CIRectangleDetector on iOS 10 to attempt to find a rectangle from the initial image.
            let detectedQuad = CIRectangleDetector.rectangle(forImage: ciImage)?.toCartesian(withHeight: orientedImage.extent.height)
            completion(detectedQuad)
        }
    }
    
    static func cropImage(image: UIImage, corners: Quadrilateral) -> UIImage? {
        var cartesianQuad = corners.toCartesian(withHeight: image.size.height)
        cartesianQuad.reorganize()
        
        guard let filteredImage = CIImage(image: image)?.applyingFilter("CIPerspectiveCorrection", parameters: [
            "inputTopLeft": CIVector(cgPoint: cartesianQuad.bottomLeft),
            "inputTopRight": CIVector(cgPoint: cartesianQuad.bottomRight),
            "inputBottomLeft": CIVector(cgPoint: cartesianQuad.topLeft),
            "inputBottomRight": CIVector(cgPoint: cartesianQuad.topRight)
        ]) else {
            return nil
        }
        
        return UIImage(ciImage: filteredImage)
    }
      
}


