import 'package:flutter/material.dart';

import 'package:document_scanner/document_scanner.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

void main() {
  runApp(MaterialApp(
    home: MyApp(),
  ));
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  DocumentScannerController? _controller;

  @override
  void initState() {
    super.initState();

    _controller = DocumentScannerController(
      onScanned: (scannedDocuments) {
        print("Scanned ${scannedDocuments.length}");
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ScannedImagesViewer(scannedDocuments: scannedDocuments),
          ),
        );
      },
      onCanceled: () {
        print("Canceled main");
      },
      onFailed: () {
        print("Failed main");
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Plugin example app'),
      // ),
      body: DocumentScannerView(
        controller: _controller!,
      ),
    );
  }
}

/// scanned images viewer
class ScannedImagesViewer extends StatelessWidget {
  const ScannedImagesViewer({Key? key, required this.scannedDocuments}) : super(key: key);

  final List<ScannedDocument> scannedDocuments;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Scanned documents"),
      ),
      body: PhotoViewGallery.builder(
        scrollPhysics: const BouncingScrollPhysics(),
        builder: (BuildContext context, int index) {
          return PhotoViewGalleryPageOptions(
            imageProvider: MemoryImage(scannedDocuments[index].cropImage?.image ?? scannedDocuments[index].initialImage.image),
            initialScale: PhotoViewComputedScale.contained * 0.8,
            heroAttributes: PhotoViewHeroAttributes(tag: "scan-${index + 1}"),
          );
        },
        itemCount: scannedDocuments.length,
        loadingBuilder: (context, event) => Center(
          child: Container(
            width: 20.0,
            height: 20.0,
            child: CircularProgressIndicator(
              value: event == null ? 0 : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
            ),
          ),
        ),
        //backgroundDecoration: widget.backgroundDecoration,
        //pageController: widget.pageController,
        onPageChanged: (index) {
          print("Paged changed $index");
        },
      ),
    );
  }
}
