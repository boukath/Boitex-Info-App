// lib/services/logistics_pdf_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // For web support

class LogisticsReportFilter {
  final DateTime startDate;
  final DateTime endDate;
  final String? type; // 'Entrée', 'Sortie', or null for both
  final String? productId; // null for all products
  final String? productName; // For display

  LogisticsReportFilter({
    required this.startDate,
    required this.endDate,
    this.type,
    this.productId,
    this.productName,
  });
}

class LogisticsPdfService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> generateAndOpenReport(LogisticsReportFilter filter) async {
    final pdf = pw.Document();

    // 1. Fetch Data
    final movements = await _fetchMovements(filter);

    // 2. Load Assets (Logo & Fonts)
    final logoImage = await _loadLogo();
    // We use standard fonts for reliability, but you can load custom .ttf if needed

    // 3. Calculate KPIs
    final totalIn = movements.where((m) => m['type'] == 'Entrée').fold(0, (sum, m) => sum + (m['change'] as int));
    final totalOut = movements.where((m) => m['type'] == 'Sortie').fold(0, (sum, m) => sum + (m['change'] as int).abs());
    final netChange = totalIn - totalOut;

    // 4. Build PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            _buildHeader(logoImage, filter),
            pw.SizedBox(height: 20),
            _buildKPIGrid(totalIn, totalOut, netChange, movements.length),
            pw.SizedBox(height: 30),
            _buildDataTable(movements),
            pw.SizedBox(height: 20),
            _buildFooter(),
          ];
        },
      ),
    );

    // 5. Save/Preview
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Rapport_Stock_Boitex_${DateFormat('ddMMyyyy').format(DateTime.now())}.pdf',
    );
  }

  // --- DATA FETCHING ---
  Future<List<Map<String, dynamic>>> _fetchMovements(LogisticsReportFilter filter) async {
    Query query = _firestore.collectionGroup('stock_history');

    // Date Filter
    query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(filter.startDate));
    query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(filter.endDate));

    // Type Filter
    if (filter.type != null) {
      query = query.where('type', isEqualTo: filter.type);
    }

    // NOTE: Product filtering is tricky with collectionGroup.
    // If productId is set, we might need to filter client-side or change the query structure.
    // For robust "collectionGroup" querying with specific parent IDs, client-side filtering is often safest for small-medium datasets.

    final snapshot = await query.orderBy('timestamp', descending: true).get();
    var docs = snapshot.docs;

    // Client-side filter for Product ID (if specific product selected)
    // To do this efficiently server-side requires specific index setups per product, usually overkill.
    if (filter.productId != null) {
      docs = docs.where((d) => d.reference.path.contains('produits/${filter.productId}/')).toList();
    }

    // Resolve Product Names (Async fetch for each can be slow, so we try to get it from history or just show ID)
    // ideally, 'stock_history' should contain 'productName'. If not, we fetch.
    List<Map<String, dynamic>> results = [];

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      String pName = "Produit";

      // Try to find product name. If you updated your onProductStockChanged to include productName, use it.
      // Otherwise, we'll fetch the parent product.
      if (data.containsKey('productName')) {
        pName = data['productName'];
      } else {
        // Quick fetch parent
        final parent = await doc.reference.parent.parent?.get();
        if (parent != null && parent.exists) {
          pName = parent.get('nom') ?? "Inconnu";
        }
      }

      results.add({
        ...data,
        'productName': pName,
        'id': doc.id,
      });
    }

    return results;
  }

  Future<Uint8List?> _loadLogo() async {
    try {
      // Adjust path to match your pubspec assets
      final byteData = await rootBundle.load('assets/images/logo.png');
      return byteData.buffer.asUint8List();
    } catch (e) {
      print("Logo loading error: $e");
      return null;
    }
  }

  // --- PDF WIDGETS ---

  pw.Widget _buildHeader(Uint8List? logo, LogisticsReportFilter filter) {
    final dateFormat = DateFormat('dd MMM yyyy', 'fr_FR');
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null) pw.Image(pw.MemoryImage(logo), width: 100),
            pw.SizedBox(height: 10),
            pw.Text("Boitex Info", style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            pw.Text("116 Rue des Frères Djilali", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            pw.Text("Bir Khadem, Alger", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text("Rapport Stock", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF667EEA))),
            pw.SizedBox(height: 10),
            pw.Text("Généré le: ${dateFormat.format(DateTime.now())}", style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 5),
            pw.Text("Période: ${dateFormat.format(filter.startDate)} - ${dateFormat.format(filter.endDate)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            if (filter.type != null) pw.Text("Filtre Type: ${filter.type}", style: const pw.TextStyle(fontSize: 10)),
            if (filter.productName != null) pw.Text("Produit: ${filter.productName}", style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildKPIGrid(int totalIn, int totalOut, int netChange, int count) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _buildKPICard("Entrées", "+$totalIn", PdfColors.green),
        _buildKPICard("Sorties", "-$totalOut", PdfColors.red),
        _buildKPICard("Flux Net", "${netChange > 0 ? '+' : ''}$netChange", netChange >= 0 ? PdfColors.blue : PdfColors.orange),
        _buildKPICard("Mouvements", "$count", PdfColors.grey800),
      ],
    );
  }

  pw.Widget _buildKPICard(String title, String value, PdfColor color) {
    return pw.Container(
      width: 110,
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  pw.Widget _buildDataTable(List<Map<String, dynamic>> movements) {
    final headers = ['Date', 'Heure', 'Produit', 'Type', 'Qté', 'Raison', 'Utilisateur'];

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: movements.map((m) {
        final date = (m['timestamp'] as Timestamp).toDate();
        final isEntry = m['type'] == 'Entrée';

        return [
          DateFormat('dd/MM/yy').format(date),
          DateFormat('HH:mm').format(date),
          m['productName'],
          m['type'] ?? '-',
          "${isEntry ? '+' : '-'}${m['change'].toString().replaceAll('-', '')}", // Force display format
          m['reason'] ?? '-',
          m['user'] ?? '-',
        ];
      }).toList(),
      border: null,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF667EEA)),
      cellHeight: 30,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.center,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerLeft,
        6: pw.Alignment.centerLeft,
      },
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
      ),
      cellStyle: const pw.TextStyle(fontSize: 9),
    );
  }

  pw.Widget _buildFooter() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 10),
        pw.Text(
          "Ce document est généré automatiquement par le système Boitex Info App.",
          style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8),
        ),
        pw.Text(
          "Boitex Info - Solutions de Sécurité & Retail",
          style: pw.TextStyle(color: PdfColors.grey500, fontSize: 8, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }
}