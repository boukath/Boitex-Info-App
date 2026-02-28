// lib/services/stock_audit_pdf_service.dart

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class StockAuditPdfService {
  // --- PREMIUM COLOR PALETTE ---
  static const primaryColor = PdfColor.fromInt(0xff0f172a); // Slate 900 (Deep Navy)
  static const secondaryColor = PdfColor.fromInt(0xff64748b); // Slate 500 (Muted Text)
  static const accentColor = PdfColor.fromInt(0xff3b82f6); // Blue 500 (Highlights)
  static const positiveColor = PdfColor.fromInt(0xff10b981); // Emerald 500 (Stock +)
  static const negativeColor = PdfColor.fromInt(0xffef4444); // Red 500 (Stock -)
  static const surfaceColor = PdfColor.fromInt(0xfff8fafc); // Slate 50 (Alt Rows)
  static const borderColor = PdfColor.fromInt(0xffe2e8f0); // Slate 200 (Subtle Lines)

  /// Generates a "Smart" PDF report from stock movements.
  Future<Uint8List> generateAuditPdf(
      List<QueryDocumentSnapshot> movements,
      DateTime? startDate,
      DateTime? endDate,
      Map<String, String> userNamesMap,
      Map<String, String> productCatalog,
      String reportTitle, {
        String activeFilters = '', // Kept exact signature
      }) async {
    final pdf = pw.Document();

    // --- PREMIUM TYPOGRAPHY ---
    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontMedium = await PdfGoogleFonts.interMedium();
    final fontBold = await PdfGoogleFonts.interBold();

    final dateFormatter = DateFormat('dd MMM yyyy • HH:mm', 'fr_FR');

    // EXACT ORIGINAL DATA LOGIC (Do not change)
    int safeInt(dynamic val) {
      if (val == null) return 0;
      if (val is int) return val;
      if (val is double) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    String formatQty(dynamic val) {
      final int qty = safeInt(val);
      return qty == 0 ? '-' : qty.toString();
    }

    // Prepare rows data beforehand so we can style them dynamically
    final List<Map<String, dynamic>> processedData = movements.map((doc) {
      final movementData = doc.data() as Map<String, dynamic>;
      final Timestamp? ts = movementData['timestamp'];
      final String formattedDate = ts != null ? dateFormatter.format(ts.toDate()) : 'N/A';

      String productRef = (movementData['productRef'] ?? 'N/A').toString();
      final String productId = movementData['productId'] ?? '';

      if ((productRef == 'N/A' || productRef.isEmpty) && productCatalog.containsKey(productId)) {
        productRef = productCatalog[productId]!;
      }

      String userName = userNamesMap[movementData['userId']] ?? movementData['user'] ?? 'Inconnu';
      final String notes = (movementData['notes'] ?? '').toString();

      if ((userName == 'Inconnu' || userName == 'Technicien') && notes.contains("(Livré)")) {
        final parts = notes.split("(Livré)");
        if (parts.length > 1) {
          final extractedName = parts.last.trim();
          if (extractedName.isNotEmpty) {
            userName = extractedName;
          }
        }
      }

      final int quantityChange = safeInt(movementData['quantityChange']);

      return {
        'date': formattedDate,
        'product': (movementData['productName'] ?? 'N/A').toString(),
        'ref': productRef,
        'change': quantityChange,
        'old': formatQty(movementData['oldQuantity']),
        'new': formatQty(movementData['newQuantity']),
        'user': userName,
        'notes': notes,
      };
    }).toList();

    // --- PDF PAGE GENERATION ---
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape.copyWith(
          marginTop: 40,
          marginBottom: 40,
          marginLeft: 40,
          marginRight: 40,
        ),
        header: (context) => _buildPremiumHeader(
          context,
          startDate,
          endDate,
          reportTitle,
          activeFilters,
          fontBold,
          fontMedium,
          fontRegular,
        ),
        footer: (context) => _buildPremiumFooter(context, fontRegular),
        build: (context) => [
          pw.SizedBox(height: 20),
          _buildPremiumTable(processedData, fontRegular, fontMedium, fontBold),
        ],
      ),
    );

    return pdf.save();
  }

  // ===========================================================================
  // 💎 PREMIUM WIDGET BUILDERS
  // ===========================================================================

  pw.Widget _buildPremiumHeader(
      pw.Context context,
      DateTime? startDate,
      DateTime? endDate,
      String title,
      String activeFilters,
      pw.Font boldFont,
      pw.Font mediumFont,
      pw.Font regularFont,
      ) {
    String dateRange = 'Historique Complet';
    final DateFormat formatter = DateFormat('dd MMM yyyy', 'fr_FR');

    if (startDate != null && endDate != null) {
      dateRange = '${formatter.format(startDate)} au ${formatter.format(endDate)}';
    } else if (startDate != null) {
      dateRange = 'À partir du ${formatter.format(startDate)}';
    } else if (endDate != null) {
      dateRange = "Jusqu'au ${formatter.format(endDate)}";
    }

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 20),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: borderColor, width: 1.5)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          // Left side: Title and Filters
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title.toUpperCase(),
                  style: pw.TextStyle(font: boldFont, fontSize: 24, color: primaryColor, letterSpacing: 1.2),
                ),
                pw.SizedBox(height: 6),
                if (activeFilters.isNotEmpty)
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: surfaceColor,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      border: pw.Border.all(color: borderColor),
                    ),
                    child: pw.Text(
                      'Filtres: $activeFilters',
                      style: pw.TextStyle(font: mediumFont, fontSize: 10, color: secondaryColor),
                    ),
                  ),
              ],
            ),
          ),

          // Right side: Meta info (Dates)
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'PÉRIODE',
                style: pw.TextStyle(font: boldFont, fontSize: 9, color: secondaryColor, letterSpacing: 1),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                dateRange,
                style: pw.TextStyle(font: mediumFont, fontSize: 12, color: primaryColor),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Généré le ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now())}',
                style: pw.TextStyle(font: regularFont, fontSize: 9, color: secondaryColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPremiumTable(
      List<Map<String, dynamic>> data,
      pw.Font regularFont,
      pw.Font mediumFont,
      pw.Font boldFont,
      ) {
    return pw.Table(
      // Clean structure: No outer borders, only subtle bottom borders inside
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: borderColor, width: 0.5),
        bottom: pw.BorderSide(color: borderColor, width: 1.0),
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.6), // Date
        1: const pw.FlexColumnWidth(2.5), // Produit
        2: const pw.FlexColumnWidth(1.5), // Ref
        3: const pw.FlexColumnWidth(1.2), // Changement
        4: const pw.FlexColumnWidth(0.8), // Avant
        5: const pw.FlexColumnWidth(0.8), // Après
        6: const pw.FlexColumnWidth(1.8), // User
        7: const pw.FlexColumnWidth(3.0), // Notes
      },
      children: [
        // --- TABLE HEADER ROW ---
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: primaryColor),
          children: [
            _buildHeaderCell('Date', boldFont),
            _buildHeaderCell('Produit', boldFont),
            _buildHeaderCell('Référence', boldFont),
            _buildHeaderCell('Mouvement', boldFont, align: pw.TextAlign.right),
            _buildHeaderCell('Avant', boldFont, align: pw.TextAlign.right),
            _buildHeaderCell('Après', boldFont, align: pw.TextAlign.right),
            _buildHeaderCell('Technicien', boldFont),
            _buildHeaderCell('Notes', boldFont),
          ],
        ),
        // --- TABLE DATA ROWS ---
        ...data.asMap().entries.map((entry) {
          final int index = entry.key;
          final Map<String, dynamic> row = entry.value;

          final bool isEven = index % 2 == 0;
          final int change = row['change'] as int;

          // Determine colors based on stock movement
          final bool isPositive = change > 0;
          final PdfColor changeColor = change == 0
              ? secondaryColor
              : (isPositive ? positiveColor : negativeColor);
          final String changeText = change > 0 ? '+$change' : '$change';

          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isEven ? PdfColors.white : surfaceColor,
            ),
            children: [
              _buildDataCell(row['date'], regularFont, color: secondaryColor),
              _buildDataCell(row['product'], mediumFont, color: primaryColor),
              _buildDataCell(row['ref'], regularFont, color: secondaryColor),

              // Custom Colored Cell for "Changement"
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                child: pw.Text(
                  changeText,
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(font: boldFont, fontSize: 11, color: changeColor),
                ),
              ),

              _buildDataCell(row['old'], mediumFont, align: pw.TextAlign.right),
              _buildDataCell(row['new'], mediumFont, align: pw.TextAlign.right),
              _buildDataCell(row['user'], mediumFont, color: primaryColor),
              _buildDataCell(row['notes'], regularFont, color: secondaryColor),
            ],
          );
        }),
      ],
    );
  }

  // Helper for Header Cells
  pw.Widget _buildHeaderCell(String text, pw.Font font, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: pw.Text(
        text.toUpperCase(),
        textAlign: align,
        style: pw.TextStyle(
          font: font,
          fontSize: 9,
          color: PdfColors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // Helper for Data Cells
  pw.Widget _buildDataCell(
      String text,
      pw.Font font,
      {
        pw.TextAlign align = pw.TextAlign.left,
        PdfColor color = primaryColor
      }
      ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 10, color: color),
      ),
    );
  }

  pw.Widget _buildPremiumFooter(pw.Context context, pw.Font regularFont) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: borderColor, width: 1.0)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Document confidentiel - Boitex Info',
            style: pw.TextStyle(font: regularFont, fontSize: 9, color: secondaryColor),
          ),
          pw.Text(
            'Page ${context.pageNumber} sur ${context.pagesCount}',
            style: pw.TextStyle(font: regularFont, fontSize: 9, color: secondaryColor),
          ),
        ],
      ),
    );
  }
}