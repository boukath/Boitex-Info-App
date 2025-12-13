// lib/services/pdf_network_image.dart

import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Fetches an image from a network URL and returns it as a Uint8List.
/// This is a necessary helper for the PDF library, which cannot use network URLs directly.
Future<Uint8List> pdfNetworkImage(String url) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode == 200) {
    return response.bodyBytes;
  }
  throw Exception('Failed to load network image for PDF: ${response.statusCode}');
}