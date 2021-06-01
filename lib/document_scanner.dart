
export 'package:document_scanner/src/document_scanner_controller.dart';
export 'package:document_scanner/views/document_scanner_view.dart';
export 'package:document_scanner/src/document_scanner_models.dart';

import 'dart:async';
import 'dart:typed_data';

import 'package:document_scanner/src/document_scanner_controller.dart';
import 'package:document_scanner/src/document_scanner_models.dart';
import 'package:flutter/services.dart';

final _channel = MethodChannel(DocumentScannerController.methodChannelName);

/// crop out paper docuemnt from an image
Future<Uint8List?> cropPicture(Uint8List imageBytes, DocumentCropCorners corners, {Duration? timeout}) async {
  final completer = Completer<Uint8List?>();
  Timer? timer;
  //
  Future(() async {
    final data = {
      "bytes": imageBytes,
      "corners": corners.toList().map((e) => [e.x, e.y]).toList(),
    };
    final bytes = await _channel.invokeMethod("cropPicture", data);
    if (completer.isCompleted) return;
    timer?.cancel();
    final result = (bytes as Uint8List?);
    completer.complete(result);
  });

  //
  if (timeout != null) {
    timer = Timer(timeout, () {
      if (completer.isCompleted) return;
      completer.complete(null);
    });
  }
  return completer.future;
}

/// Detect paper document from an image
/// returns a map of ['bytes' as Uint8List] for cropped image and ['corners' as List<List<double>>] for detected corners
Future<Map<String, dynamic>?> detectDocumentFromPicture(Uint8List imageBytes, {bool shouldCrop = false, Duration? timeout}) async {
  final completer = Completer<Map<String, dynamic>?>();
  Timer? timer;
  //
  Future(() async {
    final data = {
      "bytes": imageBytes,
      "shouldCrop": shouldCrop,
    };
    final resp = await _channel.invokeMethod("detectPaper", data);
    if (completer.isCompleted) return;
    timer?.cancel();
    final result = (resp as Map?)?.cast<String, dynamic>();
    completer.complete(result);
  });

  //
  if (timeout != null) {
    timer = Timer(timeout, () {
      if (completer.isCompleted) return;
      completer.complete(null);
    });
  }
  return completer.future;
}
