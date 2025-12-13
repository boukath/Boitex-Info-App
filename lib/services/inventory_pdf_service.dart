// lib/services/inventory_pdf_service.dart

import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class InventoryPdfService {
  /// Generates a PDF for the given product list and filters.
  static Future<Uint8List> generateInventoryPdf(
      List<DocumentSnapshot> products,
      String title,
      String filters,
      ) async {
    final doc = pw.Document();
    final logoImage = await _loadLogo();
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    final List<List<String>> tableData = _buildTableData(products);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeader(context, logoImage, title, filters, boldFont),
        footer: (context) => _buildFooter(context, font),
        build: (context) => [
          _buildProductTable(tableData, boldFont, font),
          _buildSummary(products.length, boldFont, font),
        ],
      ),
    );

    return doc.save();
  }

  /// Loads the company logo from assets
  static Future<pw.MemoryImage?> _loadLogo() async {
    try {
      final logoData = await rootBundle.load('assets/boitex_logo.png');
      return pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      print("Error loading logo: $e");
      return null;
    }
  }

  /// Builds the header for each page
  static pw.Widget _buildHeader(
      pw.Context context,
      pw.MemoryImage? logoImage,
      String title,
      String filters,
      pw.Font boldFont,
      ) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10.0),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: 1, color: PdfColors.grey)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(font: boldFont, fontSize: 18),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                filters,
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Généré le: ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
            ],
          ),
          if (logoImage != null)
            pw.Container(
              height: 60,
              child: pw.Image(logoImage),
            ),
        ],
      ),
    );
  }

  /// Builds the footer for each page
  static pw.Widget _buildFooter(pw.Context context, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 10.0),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(width: 1, color: PdfColors.grey)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Boitex Info - Rapport d\'Inventaire',
            style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey),
          ),
          pw.Text(
            'Page ${context.pageNumber} sur ${context.pagesCount}',
            style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey),
          ),
        ],
      ),
    );
  }

  /// Creates the main data table
  static pw.Widget _buildProductTable(
      List<List<String>> data,
      pw.Font boldFont,
      pw.Font font,
      ) {
    final headers = ['Référence', 'Nom du Produit', 'Quantité'];

    return pw.Table.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(
        font: boldFont,
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold,
      ),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.blueGrey700,
      ),
      cellStyle: pw.TextStyle(font: font),
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        2: pw.Alignment.center, // Align quantity to center
      },
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(4),
        2: const pw.FlexColumnWidth(1),
      },
    );
  }

  /// Creates the summary section
  static pw.Widget _buildSummary(int productCount, pw.Font boldFont, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 20),
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        'Total des lignes de produits: $productCount',
        style: pw.TextStyle(font: boldFont),
      ),
    );
  }

  /// Formats the product data for the table
  static List<List<String>> _buildTableData(List<DocumentSnapshot> products) {
    return products.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final ref = data['reference'] ?? 'N/A';
      final name = data['nom'] ?? 'Nom inconnu';
      final stock = (data['quantiteEnStock'] ?? 0).toString();

      // ✅ --- THIS IS THE FIX ---
      // We explicitly cast the list to <String>
      return <String>[ref, name, stock];

    }).toList();
  }
}