import 'dart:io';

import 'package:document_scanner/src/document_scanner_controller.dart';
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
  int currentPage = 1;

  /// current bottom bar item index
  int currentBottomBarItemIndex = 0;

  @override
  void initState() {
    super.initState();
    pageController = PageController();
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
          });
        },
        controller: pageController,
        itemCount: widget.controller.scannedDocumentList.length,
        itemBuilder: (context, index) {
          final document = widget.controller.scannedDocumentList[index];
          final imageBytes = document.cropImage?.image ?? document.initialImage.image;
          return InteractiveViewer(
            clipBehavior: Clip.none,
            scaleEnabled: true,
            minScale: 1.0,
            maxScale: 5.0,
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
                print("Crop");
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
