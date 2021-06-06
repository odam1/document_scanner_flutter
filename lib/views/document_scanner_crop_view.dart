import 'dart:io';

import 'package:document_scanner/src/document_scanner_models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DocumentScannerCropView extends StatefulWidget {
  DocumentScannerCropView({Key? key, required this.scannedDocument}) : super(key: key);

  ///
  final ScannedDocument scannedDocument;

  @override
  _DocumentScannerCropViewState createState() => _DocumentScannerCropViewState();
}

class _DocumentScannerCropViewState extends State<DocumentScannerCropView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white10,
      appBar: AppBar(
        backgroundColor: Colors.black,
        automaticallyImplyLeading: false,
        title: Text(
          "Drag corners to ajust",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
      body: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: Container(
            width: widget.scannedDocument.initialImage.size.width,
            height: widget.scannedDocument.initialImage.size.height,
            child: Stack(
              children: [
                //
                Image.memory(
                  widget.scannedDocument.initialImage.image,
                  filterQuality: FilterQuality.low,
                  //fit: BoxFit.contain,
                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                    if (frame == null) {
                      return Container(
                        width: 60,
                        height: 60,
                        //color: Colors.black26,
                        padding: const EdgeInsets.all(16),
                        child: Builder(
                          builder: (context) {
                            if (Platform.isIOS) {
                              return CupertinoActivityIndicator();
                            }
                            return CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                            );
                          },
                        ),
                      );
                    }
                    return child;
                  },
                ),

                //
                _DocumentCropCornersView(
                  corners: widget.scannedDocument.corners,
                  size: widget.scannedDocument.initialImage.size,
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        height: kBottomNavigationBarHeight,
        color: Colors.black,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // cancel item
            CupertinoButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                "Cancel",
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),

            // done item
            CupertinoButton(
              onPressed: () {
                print("Done");
              },
              child: Text(
                "Done",
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

///
class _DocumentCropCornersView extends StatefulWidget {
  _DocumentCropCornersView({Key? key, required this.corners, required this.size}) : super(key: key);

  ///
  final DocumentCropCorners? corners;

  ///
  final Size size;

  ///
  DocumentCropCorners? getCorners() {
    return null;
  }

  @override
  __DocumentCropCornersViewState createState() => __DocumentCropCornersViewState();
}

class __DocumentCropCornersViewState extends State<_DocumentCropCornersView> {
  ///
  late final DocumentCropCorners corners;

  @override
  void initState() {
    super.initState();
    if (widget.corners?.isWithinSize(widget.size) == true) {
      this.corners = widget.corners!;
    } else {
      this.corners = DocumentCropCorners.initFromSize(widget.size);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // clip cover
        IgnorePointer(
          ignoring: true,
          child: ClipPath(
            clipper: _CropAreaClipper(corners),
            child: Container(
              color: Colors.black45,
            ),
          ),
        ),
      ],
    );
  }
}

///
class _CropAreaClipper extends CustomClipper<Path> {
  final DocumentCropCorners corners;

  _CropAreaClipper(this.corners);

  @override
  Path getClip(Size size) {
    this.corners.rearrange();

    final path = Path();
    path.moveTo(corners.topLeft.x, corners.topLeft.y);
    path.lineTo(corners.topRight.x, corners.topRight.y);
    path.lineTo(corners.bottomRight.x, corners.bottomRight.y);
    path.lineTo(corners.bottomLeft.x, corners.bottomLeft.y);
    path.close();

    return Path()
      ..addPath(path, Offset.zero)
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..fillType = PathFillType.evenOdd;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => true;
}
