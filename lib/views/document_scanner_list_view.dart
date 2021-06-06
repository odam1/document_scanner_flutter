import 'dart:io';

import 'package:document_scanner/src/document_scanner_controller.dart';
import 'package:document_scanner/src/document_scanner_models.dart';
import 'package:document_scanner/views/document_scanner_crop_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DocumentScannerListView extends StatefulWidget {
  DocumentScannerListView({Key? key, required this.controller}) : super(key: key);

  ///
  final DocumentScannerController controller;

  @override
  _DocumentScannerListViewState createState() => _DocumentScannerListViewState();
}

class _DocumentScannerListViewState extends State<DocumentScannerListView> {
  ///
  PageController? pageController;

  ///
  final transformationControllers = <TransformationController>[];

  ///
  int currentPage = 1;

  /// current bottom bar item index
  int currentBottomBarItemIndex = 0;

  ///
  TapDownDetails? doubleTapDownDetail;

  @override
  void initState() {
    super.initState();
    pageController = PageController();
    widget.controller.scannedDocumentList.forEach(
      (element) => transformationControllers.add(TransformationController()),
    );
  }

  @override
  void dispose() {
    super.dispose();
    pageController?.dispose();
    transformationControllers.forEach((element) => element.dispose());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        leadingWidth: 80,
        leading: CupertinoButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(
            "Done",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
        centerTitle: true,
        title: Text(
          "$currentPage of ${widget.controller.scannedDocumentList.length}",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.normal,
          ),
        ),
        actions: [
          // retake button
          CupertinoButton(
            onPressed: () {
              Navigator.of(context).pop(currentPage - 1);
            },
            child: Text(
              "Retake",
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: PageView.builder(
        onPageChanged: (page) {
          setState(() {
            currentPage = page + 1;
            transformationControllers.forEach((e) => e.value.setIdentity());
          });
        },
        controller: pageController,
        itemCount: widget.controller.scannedDocumentList.length,
        itemBuilder: (context, index) {
          final document = widget.controller.scannedDocumentList[index];
          final imageBytes = document.cropImage?.image ?? document.initialImage.image;
          return GestureDetector(
            onDoubleTapDown: (details) {
              doubleTapDownDetail = details;
            },
            onDoubleTap: () {
              print("Double tap 1");
              setState(() {
                final tfc = transformationControllers[index];
                final position = doubleTapDownDetail!.localPosition;
                if (tfc.value.isIdentity()) {
                  print("Double tap 2");
                  tfc.value = Matrix4.identity()
                    ..translate(-position.dx * 4, -position.dy * 4)
                    ..scale(5.0);
                } else {
                  print("Double tap 3");
                  tfc.value.setIdentity();
                }
              });
            },
            child: InteractiveViewer(
              clipBehavior: Clip.none,
              scaleEnabled: true,
              minScale: 1.0,
              maxScale: 5.0,
              transformationController: transformationControllers[index],
              child: Container(
                child: Image.memory(
                  imageBytes,
                  key: ValueKey("$index"),
                  filterQuality: FilterQuality.low,
                  fit: BoxFit.contain,
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
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        height: kBottomNavigationBarHeight,
        color: Colors.black,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // crop item
            CupertinoButton(
              onPressed: () {
                Navigator.of(context)
                    .push(
                  MaterialPageRoute(
                    builder: (_) => DocumentScannerCropView(scannedDocument: widget.controller.scannedDocumentList[currentPage - 1]),
                  ),
                )
                    .then((value) {
                  final scannedDocument = value as ScannedDocument?;
                  if (scannedDocument == null || !mounted) return;
                });
              },
              child: Icon(
                CupertinoIcons.crop,
                color: Colors.white,
              ),
            ),

            // color item
            CupertinoButton(
              onPressed: () {
                print("Color filter");
              },
              child: Icon(
                CupertinoIcons.color_filter,
                color: Colors.white,
              ),
            ),

            // rotate item
            CupertinoButton(
              onPressed: () {
                print("Rotate");
              },
              child: Icon(
                CupertinoIcons.rotate_left,
                color: Colors.white,
              ),
            ),

            // delete item
            CupertinoButton(
              onPressed: () {
                print("Delete");
              },
              child: Icon(
                CupertinoIcons.delete_simple,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
