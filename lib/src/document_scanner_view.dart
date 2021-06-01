import 'dart:io';

import 'package:document_scanner/src/document_scanner_controller.dart';
import 'package:document_scanner/src/document_scanner_models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DocumentScannerView extends StatefulWidget {
  DocumentScannerView({Key? key, required this.controller}) : super(key: key);

  ///
  final DocumentScannerController controller;

  @override
  _DocumentScannerViewState createState() => _DocumentScannerViewState();
}

class _DocumentScannerViewState extends State<DocumentScannerView> {
  ///
  bool isReady = false;

  /// current flash mode
  FlashLightMode flashLightMode = FlashLightMode(FlashLightMode.flashAuto);

  /// current scanner mode
  ScannerMode scannerMode = ScannerMode(ScannerMode.auto);

  @override
  void initState() {
    super.initState();
    widget.controller.onScannerInfoChanged.stream.listen((event) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  ///
  void onPlatformViewCreated(int id) {
    widget.controller.onPlaformViewCreated(id);
    setState(() {
      isReady = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget platformView = Container();
    if (Platform.isIOS) {
      platformView = UiKitView(
        viewType: DocumentScannerController.methodChannelName + "#view",
        onPlatformViewCreated: onPlatformViewCreated,
        creationParams: {},
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else if (Platform.isAndroid) {
      platformView = AndroidView(
        key: ValueKey("android-native-view"),
        viewType: DocumentScannerController.methodChannelName + "#view",
        onPlatformViewCreated: onPlatformViewCreated,
        creationParams: {},
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else {
      return Center(
        child: Text("Document Scanner View Not Available"),
      );
    }

    //
    return Stack(
      children: [
        // platform view
        platformView,

        // loading indicator
        if (!isReady || widget.controller.isProcessing)
          Center(
            child: Container(
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
            ),
          ),

        // upper buttons
        if (isReady)
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              color: Colors.black38,
              child: SizedBox(
                height: 70,
                child: SafeArea(
                  child: Stack(
                    children: [
                      // cancel button
                      Align(
                        alignment: Alignment.centerLeft,
                        child: CupertinoButton(
                          onPressed: widget.controller.isProcessing
                              ? null
                              : () {
                                  widget.controller.cancel();
                                },
                          child: Text(
                            "Cancel",
                            style: TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      // tourch button
                      Align(
                        alignment: Platform.isIOS ? Alignment.center : Alignment.centerRight,
                        child: PopupMenuButton<String>(
                          elevation: 0,
                          color: Colors.black38,
                          icon: Icon(
                            flashLightMode.icon,
                            color: Colors.white,
                          ),
                          initialValue: flashLightMode.flashMode,
                          onSelected: widget.controller.isProcessing
                              ? null
                              : (mode) {
                                  final fmode = FlashLightMode(mode);
                                  widget.controller.changeFlashMode(fmode);
                                  setState(() {
                                    flashLightMode = fmode;
                                  });
                                },
                          itemBuilder: (_) => FlashLightMode.modeList.map((e) {
                            final mode = FlashLightMode(e);
                            return PopupMenuItem<String>(
                              value: e,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    e,
                                    style: TextStyle(
                                      color: Colors.white,
                                    ),
                                  ),
                                  Icon(
                                    mode.icon,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      /// toggle auto scan button
                      if (Platform.isIOS)
                        Align(
                          alignment: Alignment.centerRight,
                          child: CupertinoButton(
                            onPressed: () {
                              final mode = scannerMode.mode == ScannerMode.auto ? ScannerMode.manual : ScannerMode.auto;
                              widget.controller.toggleScannerMode(ScannerMode(mode)).then((value) {
                                if (mounted && value) {
                                  setState(() {
                                    scannerMode = ScannerMode(mode);
                                  });
                                }
                              });
                            },
                            child: Text(
                              scannerMode.mode,
                              style: TextStyle(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // capture button
        if (isReady)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GestureDetector(
                onTap: widget.controller.isProcessing
                    ? null
                    : () {
                        widget.controller.captureImage();
                      },
                child: Container(
                  width: 70,
                  height: 70,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 5),
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),

        // thumbnail
        if (isReady && widget.controller.scannedDocumentList.isNotEmpty)
          Align(
            alignment: Alignment.bottomLeft,
            child: GestureDetector(
              onTap: widget.controller.isProcessing
                  ? null
                  : () {
                      //TODO:
                      print("Thumbnail");
                    },
              child: Container(
                width: 55,
                height: 65,
                margin: const EdgeInsets.only(left: 20, bottom: 20),
                child: Stack(
                  children: [
                    //
                    Center(
                      child: Image.memory(
                        widget.controller.scannedDocumentList.last.cropImage?.image ?? widget.controller.scannedDocumentList.last.initialImage.image,
                        fit: BoxFit.contain,
                        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                          if (frame == null) {
                            return Container(
                              width: 40,
                              height: 40,
                              color: Colors.black26,
                              padding: const EdgeInsets.all(12),
                              child: Builder(
                                builder: (context) {
                                  if (Platform.isIOS) {
                                    return CupertinoActivityIndicator();
                                  }
                                  return CircularProgressIndicator(
                                    strokeWidth: 2,
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

                    //
                    // if (widget.controller.scannedDocumentList.any((e) => e.isCropping))
                    //   Center(
                    //     child: Container(
                    //       width: 30,
                    //       height: 30,
                    //       color: Colors.black26,
                    //       padding: const EdgeInsets.all(8),
                    //       child: CircularProgressIndicator(
                    //         strokeWidth: 2,
                    //         valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    //       ),
                    //     ),
                    //   ),
                  ],
                ),
              ),
            ),
          ),

        // save button
        if (isReady && widget.controller.scannedDocumentList.isNotEmpty)
          Align(
            alignment: Alignment.bottomRight,
            child: Container(
              margin: const EdgeInsets.only(right: 20, bottom: 28),
              child: ElevatedButton(
                onPressed: widget.controller.isProcessing
                    ? null
                    : () {
                        widget.controller.save();
                      },
                style: ButtonStyle(backgroundColor: MaterialStateColor.resolveWith((states) => Colors.white)),
                child: Text(
                  "Save (${widget.controller.scannedDocumentList.length})",
                  style: TextStyle(
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
