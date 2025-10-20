// lib/widgets/pdf_viewer_page.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

class PdfViewerPage extends StatelessWidget {
  final Uint8List pdfBytes;
  final String title;

  const PdfViewerPage({
    super.key,
    required this.pdfBytes,
    this.title = 'Aperçu PDF',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF667EEA), // Match your theme
      ),
      body: PDFView(
        pdfData: pdfBytes,
        autoSpacing: true,
        pageFling: true,
        pageSnap: true,
        swipeHorizontal: false, // Vertical scrolling
      ),
    );
  }
}