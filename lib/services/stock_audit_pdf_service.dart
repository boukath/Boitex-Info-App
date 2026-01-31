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
  /// - [reportTitle]: Custom title for the report.
  Future<Uint8List> generateAuditPdf(
      List<QueryDocumentSnapshot> movements,
      DateTime? startDate,
      DateTime? endDate,
      Map<String, String> userNamesMap,
      Map<String, String> productCatalog,
      String reportTitle,
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

    // ✅ FIX 1: SAFE INTEGER CONVERTER
    // This function handles '5', '5.0', and null safely without crashing
    int safeInt(dynamic val) {
      if (val == null) return 0;
      if (val is int) return val;
      if (val is double) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    // ✅ FIX 2: Apply safe conversion to formatting
    String formatQty(dynamic val) {
      final int qty = safeInt(val);
      return qty == 0 ? '-' : qty.toString();
    }

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

      if ((productRef == 'N/A' || productRef.isEmpty) &&
          productCatalog.containsKey(productId)) {
        productRef = productCatalog[productId]!;
      }

      // 2. SMART USER NAME RESOLUTION
      String userName = userNamesMap[movementData['userId']] ??
          movementData['user'] ??
          'Inconnu';

      final String notes = (movementData['notes'] ?? '').toString();

      if ((userName == 'Inconnu' || userName == 'Technicien') &&
          notes.contains("(Livré)")) {
        final parts = notes.split("(Livré)");
        if (parts.length > 1) {
          final extractedName = parts.last.trim();
          if (extractedName.isNotEmpty) {
            userName = extractedName;
          }
        }
      }

      // 3. APPLY SAFE INT FIX HERE
      // Using safeInt() prevents the "double is not subtype of int" crash
      final int quantityChange = safeInt(movementData['quantityChange']);

      // -----------------------------------------------------------
      // 🕵️ SMART LOGIC END
      // -----------------------------------------------------------

      data.add([
        formattedDate,
        (movementData['productName'] ?? 'N/A').toString(),
        productRef,
        quantityChange.toString(), // ✅ Safe
        formatQty(movementData['oldQuantity']), // ✅ Safe
        formatQty(movementData['newQuantity']), // ✅ Safe
        userName,
        notes,
      ]);
    }

    pdf.addPage(
      pw.MultiPage(
        // ✅ Increase page limit to prevent crashes on large reports
        maxPages: 10000,
        theme: theme,
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) => [
          _buildHeader(context, startDate, endDate, reportTitle),
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
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerLeft,
              7: pw.Alignment.centerLeft,
            },
            columnWidths: {
              0: const pw.FlexColumnWidth(1.8),
              1: const pw.FlexColumnWidth(2.5),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(0.8),
              5: const pw.FlexColumnWidth(0.8),
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
      pw.Context context, DateTime? startDate, DateTime? endDate, String title) {
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
            title,
            style: pw.Theme.of(context).header0,
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            dateRange,
            style: pw.Theme.of(context).header3,
          ),
          pw.Text(
            'Généré le: ${formatter.format(DateTime.now())}',
            style:
            pw.Theme.of(context).header4.copyWith(color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }
}