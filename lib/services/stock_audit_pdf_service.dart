// lib/services/stock_audit_pdf_service.dart

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class StockAuditPdfService {
  /// Generates a PDF report from the list of stock movements.
  Future<Uint8List> generateAuditPdf(
      List<QueryDocumentSnapshot> movements,
      DateTime? startDate,
      DateTime? endDate,
      Map<String, String> userNamesMap, // ✅ --- ADDED: Pass the map ---
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

      data.add([
        formattedDate,
        (movementData['productName'] ?? 'N/A').toString(),
        (movementData['productRef'] ?? 'N/A').toString(),
        (movementData['quantityChange'] ?? 0).toString(),
        (movementData['oldQuantity'] ?? 0).toString(),
        (movementData['newQuantity'] ?? 0).toString(),
        // ✅ --- UPDATED: Use the map ---
        userNamesMap[movementData['userId']] ?? 'Inconnu',
        // ✅ --- END UPDATED ---
        (movementData['notes'] ?? '').toString(),
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
            // ... (rest of the table formatting is unchanged)
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
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
            },
            columnWidths: {
              0: const pw.FlexColumnWidth(1.8),
              1: const pw.FlexColumnWidth(2.5),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(1),
              5: const pw.FlexColumnWidth(1),
              6: const pw.FlexColumnWidth(1.8),
              7: const pw.FlexColumnWidth(3),
            },
          ),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(
      pw.Context context, DateTime? startDate, DateTime? endDate) {
    // ... (This function remains unchanged)
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
            style: pw.Theme.of(context).header4,
          ),
        ],
      ),
    );
  }
}