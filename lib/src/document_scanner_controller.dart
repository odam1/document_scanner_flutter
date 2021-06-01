import 'dart:async';

import 'package:document_scanner/document_scanner.dart';
import 'package:document_scanner/src/document_scanner_models.dart';
import 'package:flutter/services.dart';

class DocumentScannerController {
  /// channel name
  static const methodChannelName = "com.odamsoft.document_scanner";

  /// image captured listener
  final void Function(List<ScannedDocument>) onScanned;
  final void Function() onCanceled;
  final void Function() onFailed;

  ///
  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  ///
  final onScannerInfoChanged = StreamController<bool>.broadcast();

  ///
  final List<ScannedDocument> scannedDocumentList = [];

  ///
  bool get isReady => _channel != null;

  ///
  MethodChannel? _channel;

  DocumentScannerController({
    required this.onScanned,
    required this.onCanceled,
    required this.onFailed,
  });

  ///
  void onPlaformViewCreated(int id) {
    _channel = MethodChannel("$methodChannelName#$id");
    _channel!.setMethodCallHandler(_onMethodCall);
  }

  // case "captureImage":
  //               resp = self.scannerView?.captureImage()
  //               break
  //           case "refreshCamera":
  //               resp = self.scannerView?.refreshCamera()
  //               break
  //           case "pauseCamera":
  //               resp = self.scannerView?.pauseCamera()
  //               break;
  //           case "changeFlashMode":
  //               if let mode = call.arguments as? String {
  //                   resp = self.scannerView?.changeFlashMode(mode: mode)
  //               }
  //               break
  //           case "toggleScannerMode":
  //               if let mode = call.arguments as? String {
  //                   resp = self.scannerView?.toggleScannerMode(mode: mode)
  //               }
  //               break

  /// capture image
  Future<bool> captureImage() async {
    if (!isReady) return false;
    final resp = await _channel!.invokeMethod("captureImage");
    _isProcessing = resp == true;
    onScannerInfoChanged.add(true);
    return _isProcessing;
  }

  /// refresh the camera and reset scanner
  Future<bool> resetScanner() async {
    _isProcessing = false;
    onScannerInfoChanged.add(true);
    final resp = await _channel!.invokeMethod("refreshCamera");
    return resp == true;
  }

  /// pause the camera and scanner
  Future<bool> pauseScanner() async {
    _isProcessing = false;
    onScannerInfoChanged.add(true);
    final resp = await _channel!.invokeMethod("pauseCamera");
    return resp == true;
  }

  /// change flash mode
  Future<bool> changeFlashMode(FlashLightMode mode) async {
    if (!isReady) return false;
    final resp = await _channel!.invokeMethod("changeFlashMode", mode.flashMode);
    return resp == true;
  }

  /// change scanner mode
  Future<bool> toggleScannerMode(ScannerMode mode) async {
    if (!isReady) return false;
    final resp = await _channel!.invokeMethod("toggleScannerMode", mode.mode);
    return resp == true;
  }

  /// save method
  void save() {
    this.onScanned.call(scannedDocumentList.toList());
  }

  /// cancel method
  void cancel() {
    this.onCanceled.call();
  }

  ///
  void dispose() {
    if (!isReady) return;
    _channel!.invokeMethod("dispose");
    _isProcessing = false;
    onScannerInfoChanged.add(true);

    _channel = null;
    onScannerInfoChanged.close();
  }

  ///
  Future _onMethodCall(MethodCall call) async {
    if (!isReady) return;
    print("MethodChannel: ${call.method}");
    switch (call.method) {
      case "onCapture":
        final data = (call.arguments as Map).cast<String, dynamic>();
        _onCapture(data);
        break;
      case "scanned":
        final data = (call.arguments as Map).cast<String, dynamic>();
        final scannedDocuments = data.keys.map((e) => ScannedDocument.fromMap((data[e] as Map).cast<String, dynamic>())).toList();
        this.onScanned.call(scannedDocuments);
        break;
      // case "canceled":
      //   this.onCanceled.call();
      //   resetScanner();
      //   break;
      case "failed":
        this.onFailed.call();
        resetScanner();
        break;
      default:
    }
  }

  ///
  Future _onCapture(Map<String, dynamic> info) async {
    final scannedDocument = ScannedDocument.fromMap(info);
    scannedDocumentList.add(scannedDocument);
    if (!scannedDocument.hasCroppedImage) {
      scannedDocument.isCropping = true;
      scannedDocument.crop().then((_) {
        onScannerInfoChanged.add(true);
      });
      // if (scannedDocument.hasCorners) {
      //   final cropImage = await cropPicture(scannedDocument.initialImage.image, scannedDocument.corners!, timeout: const Duration(seconds: 10));
      //   scannedDocument.cropImage =
      //       cropImage == null ? null : DocumentImageModel(image: cropImage, size: getImageSizeFromCorners(scannedDocument.corners)!);
      // } else {
      //   final data = await detectDocumentFromPicture(scannedDocument.initialImage.image, timeout: const Duration(seconds: 10));
      //   if (data != null) {
      //     final cropImage = data['bytes'] as Uint8List;
      //     final corners = (data['corners'] as List?)?.cast<List>().map((e) => Point<double>(e[0] as double, e[1] as double)).toList();
      //     scannedDocument.corners = DocumentCropCorners.fromList(corners);
      //     scannedDocument.cropImage = DocumentImageModel(image: cropImage, size: getImageSizeFromCorners(scannedDocument.corners)!);
      //   }
      // }
    }
    resetScanner();
  }
}
