// lib/services/stock_audit_pdf_service.dart

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class StockAuditPdfService {
  /// Generates a "Smart" PDF report from stock movements.
  /// - [productCatalog]: A map of {productId: productReference} to fix missing refs.
  /// - [userNamesMap]: A map of {userId: displayName} to fix missing users.
  Future<Uint8List> generateAuditPdf(
      List<QueryDocumentSnapshot> movements,
      DateTime? startDate,
      DateTime? endDate,
      Map<String, String> userNamesMap,
      Map<String, String> productCatalog, // ✅ ADDED: Catalog for lookup
      ) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();

    final theme = pw.ThemeData.withFont(
      base: font,
      bold: boldFont,
    );

    final headers = [
      'Date',
      'Produit',
      'Réf.',
      'Changement',
      'Avant',
      'Après',
      'Utilisateur',
      'Notes'
    ];

    final data = <List<String>>[];
    final dateFormatter = DateFormat('dd/MM/yy HH:mm');

    for (final doc in movements) {
      final movementData = doc.data() as Map<String, dynamic>;
      final Timestamp? ts = movementData['timestamp'];
      final String formattedDate =
      ts != null ? dateFormatter.format(ts.toDate()) : 'N/A';

      // -----------------------------------------------------------
      // 🕵️ SMART LOGIC START
      // -----------------------------------------------------------

      // 1. SMART REFERENCE LOOKUP
      String productRef = (movementData['productRef'] ?? 'N/A').toString();
      final String productId = movementData['productId'] ?? '';

      // If Ref is missing, check the cheat sheet (Catalog)
      if ((productRef == 'N/A' || productRef.isEmpty) &&
          productCatalog.containsKey(productId)) {
        productRef = productCatalog[productId]!;
      }

      // 2. SMART USER NAME RESOLUTION
      // Priority: 1. Map Lookup (ID) -> 2. Stored Name -> 3. "Inconnu"
      String userName = userNamesMap[movementData['userId']] ??
          movementData['user'] ??
          'Inconnu';

      final String notes = (movementData['notes'] ?? '').toString();

      // Detective Rule: If unknown, try to find the name hidden in the notes
      // Example Note: "Sortie BL-40... confirmée (Livré) Boubaaya"
      if ((userName == 'Inconnu' || userName == 'Technicien') &&
          notes.contains("(Livré)")) {
        final parts = notes.split("(Livré)");
        if (parts.length > 1) {
          final extractedName = parts.last.trim();
          if (extractedName.isNotEmpty) {
            userName = extractedName; // Found him!
          }
        }
      }

      // 3. SMART QUANTITY FORMATTING (Hide Zeros)
      String formatQty(dynamic val) {
        final int qty = (val ?? 0) as int;
        return qty == 0 ? '-' : qty.toString();
      }

      // -----------------------------------------------------------
      // 🕵️ SMART LOGIC END
      // -----------------------------------------------------------

      data.add([
        formattedDate,
        (movementData['productName'] ?? 'N/A').toString(),
        productRef, // ✅ Uses Smart Ref
        (movementData['quantityChange'] ?? 0).toString(),
        formatQty(movementData['oldQuantity']), // ✅ Uses Smart Formatting
        formatQty(movementData['newQuantity']), // ✅ Uses Smart Formatting
        userName, // ✅ Uses Smart User Name
        notes,
      ]);
    }

    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) => [
          _buildHeader(context, startDate, endDate),
          pw.Table.fromTextArray(
            headers: headers,
            data: data,
            border: pw.TableBorder.all(color: PdfColors.grey300),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              0: pw.Alignment.centerLeft,  // Date
              1: pw.Alignment.centerLeft,  // Product
              2: pw.Alignment.centerLeft,  // Ref
              3: pw.Alignment.centerRight, // Change
              4: pw.Alignment.centerRight, // Before
              5: pw.Alignment.centerRight, // After
              6: pw.Alignment.centerLeft,  // User
              7: pw.Alignment.centerLeft,  // Notes
            },
            columnWidths: {
              0: const pw.FlexColumnWidth(1.8), // Date
              1: const pw.FlexColumnWidth(2.5), // Product
              2: const pw.FlexColumnWidth(1.5), // Ref
              3: const pw.FlexColumnWidth(1),   // Change
              4: const pw.FlexColumnWidth(0.8), // Before (smaller)
              5: const pw.FlexColumnWidth(0.8), // After (smaller)
              6: const pw.FlexColumnWidth(1.8), // User
              7: const pw.FlexColumnWidth(3),   // Notes
            },
          ),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(
      pw.Context context, DateTime? startDate, DateTime? endDate) {
    String dateRange = 'Tous les mouvements';
    final DateFormat formatter = DateFormat('dd/MM/yyyy');

    if (startDate != null && endDate != null) {
      dateRange =
      'Période du: ${formatter.format(startDate)} au ${formatter.format(endDate)}';
    } else if (startDate != null) {
      dateRange = 'Période du: ${formatter.format(startDate)}';
    } else if (endDate != null) {
      dateRange = "Période jusqu'au: ${formatter.format(endDate)}";
    }

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Audit des Mouvements de Stock',
            style: pw.Theme.of(context).header0,
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            dateRange,
            style: pw.Theme.of(context).header3,
          ),
          pw.Text(
            'Généré le: ${formatter.format(DateTime.now())}',
            style: pw.Theme.of(context).header4.copyWith(color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }
}