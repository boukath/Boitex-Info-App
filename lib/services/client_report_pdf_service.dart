// lib/services/client_report_pdf_service.dart

import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/services/client_report_service.dart';

class ClientReportPdfService {

  // 🎨 Chart Color Palette (Professional Tones)
  static const List<PdfColor> _chartColors = [
    PdfColor.fromInt(0xFF7B61FF), // Primary Purple
    PdfColor.fromInt(0xFF00B4D8), // Cyan
    PdfColor.fromInt(0xFFFF6F91), // Pink/Red
    PdfColor.fromInt(0xFFFFC75F), // Orange/Yellow
    PdfColor.fromInt(0xFF4D96FF), // Blue
    PdfColor.fromInt(0xFF6BCB77), // Green
  ];

  Future<Uint8List> generateReport(ClientReportData data) async {
    final pdf = pw.Document();

    final logoImage = await _loadLogo();
    final fontRegular = await PdfGoogleFonts.poppinsRegular();
    final fontBold = await PdfGoogleFonts.poppinsBold();

    final theme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: theme,
          margin: const pw.EdgeInsets.all(40),
        ),
        header: (context) => _buildHeader(context, data, logoImage),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          // --- PAGE 1: DASHBOARD ---
          _buildDashboard(data),

          // ✅ NEW: Charts Section
          if (data.interventionsByMonth.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _buildChartsRow(data),
          ],

          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.SizedBox(height: 20),

          // --- PAGE 2+: DETAILS ---
          ...data.stores.map((store) {
            if (!store.hasActivity) return pw.Container();

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildStoreSection(store),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 20),
              ],
            );
          }).toList(),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(pw.Context context, ClientReportData data, pw.MemoryImage? logo) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final period = "${dateFormat.format(data.startDate)} - ${dateFormat.format(data.endDate)}";

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logo != null) pw.Image(logo, width: 100),
              pw.SizedBox(height: 5),
              pw.Text("Rapport d'Activité & Maintenance", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
              pw.Text("Client: ${data.clientName}", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text("BOITEX INFO", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
              pw.Text("Période: $period", style: const pw.TextStyle(fontSize: 10)),
              pw.Text("Généré le: ${dateFormat.format(DateTime.now())}", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildDashboard(ClientReportData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text("📊 Synthèse Globale", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard("Interventions", "${data.totalInterventions}", PdfColors.blue),
              _buildStatCard("Magasins Actifs", "${data.stores.length}", PdfColors.green),
              _buildStatCard("Équipements", "${data.totalEquipment}", PdfColors.orange),
            ],
          ),
          pw.SizedBox(height: 15),
          if (data.topProblematicStores.isNotEmpty) ...[
            pw.Text("⚠️ Top Magasins (Volume d'Interventions)", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Column(
              children: data.topProblematicStores.map((s) =>
                  pw.Row(
                    children: [
                      pw.Container(width: 6, height: 6, decoration: const pw.BoxDecoration(color: PdfColors.red, shape: pw.BoxShape.circle)),
                      pw.SizedBox(width: 5),
                      pw.Text("${s.name} (${s.interventions.length} interventions)", style: const pw.TextStyle(fontSize: 10)),
                    ],
                  )
              ).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 📈 CHARTS IMPLEMENTATION
  // ---------------------------------------------------------------------------
  pw.Widget _buildChartsRow(ClientReportData data) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // --- 1. BAR CHART (Monthly Trend) ---
        pw.Expanded(
          flex: 3,
          child: pw.Container(
            height: 150,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("📅 Évolution Mensuelle", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Expanded(
                  child: pw.Chart(
                    grid: pw.CartesianGrid(
                      xAxis: pw.FixedAxis(
                        List.generate(data.interventionsByMonth.length, (i) => i.toDouble()),
                        // ✅ FIX: Used 'format' (returns String) instead of 'tick'
                        format: (v) {
                          final index = v.toInt();
                          if (index < 0 || index >= data.interventionsByMonth.length) {
                            return '';
                          }
                          return data.interventionsByMonth.keys.elementAt(index);
                        },
                        textStyle: const pw.TextStyle(fontSize: 8), // Styling applied here
                      ),
                      yAxis: pw.FixedAxis(
                        [0, 5, 10, 15, 20], // Adjust scale based on volume
                        divisions: true,
                        textStyle: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
                      ),
                    ),
                    datasets: [
                      pw.BarDataSet(
                        color: PdfColors.blueAccent,
                        width: 15,
                        data: List.generate(data.interventionsByMonth.length, (index) {
                          final value = data.interventionsByMonth.values.elementAt(index);
                          return pw.PointChartValue(index.toDouble(), value.toDouble());
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        pw.SizedBox(width: 15),

        // --- 2. PIE CHART (Type Breakdown) ---
        pw.Expanded(
          flex: 2,
          child: pw.Container(
            height: 150,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("🔧 Répartition par Type", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Expanded(
                  child: pw.Chart(
                    title: pw.Text(""), // Hide title inside chart
                    grid: pw.PieGrid(),
                    datasets: List.generate(data.interventionsByType.length, (index) {
                      final key = data.interventionsByType.keys.elementAt(index);
                      final value = data.interventionsByType.values.elementAt(index);
                      // Cycle through colors
                      final color = _chartColors[index % _chartColors.length];

                      return pw.PieDataSet(
                        legend: "$key ($value)",
                        value: value,
                        color: color,
                        legendStyle: const pw.TextStyle(fontSize: 8),
                        legendPosition: pw.PieLegendPosition.inside, // Keep it compact
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildStoreSection(StoreReportData store) {
    final headerColor = store.interventions.isNotEmpty ? PdfColors.blue800 : PdfColors.grey700;
    final groupedEquipment = _groupEquipment(store.equipment);

    return pw.Container(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 10),
            decoration: pw.BoxDecoration(color: PdfColors.grey200, borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(store.name.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: headerColor)),
                pw.Text(store.location, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              ],
            ),
          ),
          pw.SizedBox(height: 10),

          if (groupedEquipment.isNotEmpty) ...[
            pw.Text("📦 Parc Équipements (Synthèse)", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            pw.Table.fromTextArray(
              headers: ['Équipement', 'Marque', 'Quantité', 'Dernière Install.'],
              data: groupedEquipment.map((e) => [
                e['name'],
                e['marque'],
                e['count'].toString(),
                e['date'],
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              border: null,
              headerCellDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey600),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5))),
            ),
            pw.SizedBox(height: 10),
          ],

          if (store.interventions.isNotEmpty) ...[
            pw.Text("🛠️ Historique Interventions Détaillé", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            pw.Table.fromTextArray(
              headers: ['Date', 'Tech', 'Responsable', 'Demande', 'Diagnostic', 'Solution / Travaux'],
              columnWidths: {
                0: const pw.FixedColumnWidth(50),
                1: const pw.FixedColumnWidth(55),
                2: const pw.FixedColumnWidth(60),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1),
                5: const pw.FlexColumnWidth(1.2),
              },
              data: store.interventions.map((i) => [
                DateFormat('dd/MM/yy').format(i.date),
                i.technician,
                i.managerName,
                i.summary.isEmpty ? '-' : i.summary,
                i.diagnostic.isEmpty ? '-' : i.diagnostic,
                i.workDone.isEmpty ? '-' : i.workDone,
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue600),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              border: null,
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5))),
            ),
          ] else ...[
            pw.Text("Aucune intervention sur la période.", style: const pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColors.grey)),
          ],
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _groupEquipment(List<EquipmentReportItem> items) {
    if (items.isEmpty) return [];

    final Map<String, Map<String, dynamic>> groups = {};

    for (var item in items) {
      final key = "${item.name}|${item.marque}";

      if (!groups.containsKey(key)) {
        groups[key] = {
          'name': item.name,
          'marque': item.marque,
          'count': 0,
          'latestDate': item.installDate,
        };
      }

      groups[key]!['count'] += 1;

      final DateTime? current = groups[key]!['latestDate'];
      if (item.installDate != null) {
        if (current == null || item.installDate!.isAfter(current)) {
          groups[key]!['latestDate'] = item.installDate;
        }
      }
    }

    return groups.values.map((g) {
      final date = g['latestDate'] as DateTime?;
      return {
        'name': g['name'],
        'marque': g['marque'],
        'count': g['count'],
        'date': date != null ? DateFormat('dd/MM/yyyy').format(date) : '-',
      };
    }).toList();
  }

  pw.Widget _buildStatCard(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(value, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: color)),
        pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
      ],
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        "Page ${context.pageNumber} sur ${context.pagesCount}",
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
      ),
    );
  }

  Future<pw.MemoryImage?> _loadLogo() async {
    try {
      final byteData = await rootBundle.load('assets/boitex_logo.png');
      return pw.MemoryImage(byteData.buffer.asUint8List());
    } catch (e) {
      return null;
    }
  }
}