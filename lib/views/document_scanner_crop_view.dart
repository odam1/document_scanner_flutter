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
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        print(widget.size);
        print(size);
        return Container(
          color: Colors.black26,
        );
      },
    );
  }
}
