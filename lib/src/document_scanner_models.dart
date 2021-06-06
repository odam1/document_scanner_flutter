import 'dart:math';
import 'dart:typed_data';

import 'dart:ui';

import 'package:document_scanner/document_scanner.dart';
import 'package:flutter/material.dart';

class ScannedDocument {
  final DocumentImageModel initialImage;
  DocumentImageModel? cropImage;
  DocumentCropCorners? corners;
  bool isCropping = false;
  bool get hasCroppedImage => cropImage != null;
  bool get hasCorners => corners != null;

  ScannedDocument({
    required Uint8List initialImage,
    required Size initialImageSize,
    Uint8List? cropImage,
    Size? cropImageSize,
    this.corners,
  }) : this.initialImage = DocumentImageModel(image: initialImage, size: initialImageSize) {
    if (cropImage == null || (cropImageSize == null && corners == null)) return;
    this.cropImage = DocumentImageModel(
      image: cropImage,
      size: cropImageSize ?? getImageSizeFromCorners(corners!)!,
    );
  }
  factory ScannedDocument.fromMap(Map<String, dynamic> info) {
    final corners = (info['corners'] as List?)?.cast<List>().map((e) => Point<double>(e[0] as double, e[1] as double)).toList();
    return ScannedDocument(
      initialImage: info['initialImage'],
      initialImageSize: Size(info['initialImageSize'][0], info['initialImageSize'][1]),
      cropImage: info['cropImage'],
      cropImageSize: info['cropImageSize'] != null ? Size(info['cropImageSize'][0], info['cropImageSize'][1]) : null,
      corners: DocumentCropCorners.fromList(corners),
    );
  }
  Future crop() async {
    isCropping = true;
    if (hasCorners) {
      final cropImg = await cropPicture(initialImage.image, corners!, timeout: const Duration(seconds: 10));
      this.cropImage = cropImg == null ? null : DocumentImageModel(image: cropImg, size: getImageSizeFromCorners(this.corners)!);
    } else {
      final data = await detectDocumentFromPicture(initialImage.image, timeout: const Duration(seconds: 10));
      if (data != null) {
        final cropImage = data['bytes'] as Uint8List;
        final corners = (data['corners'] as List?)?.cast<List>().map((e) => Point<double>(e[0] as double, e[1] as double)).toList();
        this.corners = DocumentCropCorners.fromList(corners);
        this.cropImage = DocumentImageModel(image: cropImage, size: getImageSizeFromCorners(this.corners)!);
      }
    }
    isCropping = false;
  }
}

///
class DocumentImageModel {
  final Uint8List image;
  final Size size;
  DocumentImageModel({required this.image, required this.size});
}

///
class DocumentCropCorners {
  Point<double> topLeft;
  Point<double> topRight;
  Point<double> bottomLeft;
  Point<double> bottomRight;
  DocumentCropCorners({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
  });
  static DocumentCropCorners? fromList(List<Point<double>>? corners) {
    if (corners == null || corners.length != 4) {
      return null;
    }
    return DocumentCropCorners(
      topLeft: corners[0],
      topRight: corners[1],
      bottomLeft: corners[2],
      bottomRight: corners[3],
    );
  }

  List<Point<double>> toList() => [
        topLeft,
        topRight,
        bottomLeft,
        bottomRight,
      ];
  void rearrange() {
    final points = [topLeft, topRight, bottomRight, bottomLeft];
    points.sort((p1, p2) => p1.y.compareTo(p2.y));

    final topPoints = points.sublist(0, 2)..sort((p1, p2) => p1.x.compareTo(p2.x));
    final bottomPoints = points.sublist(3)..sort((p1, p2) => p1.x.compareTo(p2.x));

    topLeft = topPoints[0];
    topRight = topPoints[1];
    bottomRight = bottomPoints[1];
    bottomLeft = bottomPoints[0]; 
  }
}

///
class FlashLightMode {
  static const String flashOn = "On";
  static const String flashOff = "Off";
  static const String flashAuto = "Auto";
  static const String flashTorch = "Torch";
  static const List<String> modeList = [
    flashAuto,
    flashOn,
    flashOff,
    flashTorch,
  ];

  IconData get icon {
    switch (flashMode) {
      case flashOn:
        return Icons.flash_on;
      case flashOff:
        return Icons.flash_off;
      case flashAuto:
        return Icons.flash_auto;
      case flashTorch:
        return Icons.lightbulb;
      default:
        return Icons.flash_off;
    }
  }

  final String flashMode;
  FlashLightMode(this.flashMode) : assert(modeList.contains(flashMode), "Flash mode [$flashMode] not supported");
  String toString() => flashMode;
}

///
class ScannerMode {
  static const String auto = "Auto";
  static const String manual = "Manual";

  final String mode;
  ScannerMode(this.mode) : assert([auto, manual].contains(mode), "Scanner mode [$mode] not supported");
  String toString() => this.mode;
}

/// get image size from corners
Size? getImageSizeFromCorners(DocumentCropCorners? corners) {
  if (corners == null) return null;

  final tl = corners.topLeft;
  final tr = corners.topRight;
  final br = corners.bottomLeft;
  final bl = corners.bottomRight;

  final w1 = sqrt(pow(br.x - bl.x, 2.0) + pow(br.y - bl.y, 2.0));
  final w2 = sqrt(pow(tr.x - tl.x, 2.0) + pow(tr.y - tl.y, 2.0));

  final h1 = sqrt(pow(tr.x - br.x, 2.0) + pow(tr.y - br.y, 2.0));
  final h2 = sqrt(pow(tl.x - bl.x, 2.0) + pow(tl.y - bl.y, 2.0));

  return Size(max(w1, w2), max(h1, h2));
}
