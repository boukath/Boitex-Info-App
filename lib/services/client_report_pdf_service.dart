// lib/services/client_report_pdf_service.dart

import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/services/client_report_service.dart';

class ClientReportPdfService {
  // 🎨 Premium Enterprise Color Palette
  static const PdfColor _primaryNavy = PdfColor.fromInt(0xFF0A192F);
  static const PdfColor _accentGold = PdfColor.fromInt(0xFFD4AF37);
  static const PdfColor _accentBlue = PdfColor.fromInt(0xFF00B4D8);
  static const PdfColor _lightGray = PdfColor.fromInt(0xFFF3F4F6);
  static const PdfColor _textDark = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor _textMuted = PdfColor.fromInt(0xFF64748B);

  Future<Uint8List> generateReport(ClientReportData data) async {
    final pdf = pw.Document();

    final logoImage = await _loadLogo();
    final fontRegular = await PdfGoogleFonts.poppinsRegular();
    final fontBold = await PdfGoogleFonts.poppinsBold();
    final fontMedium = await PdfGoogleFonts.poppinsMedium();

    final theme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
      italic: await PdfGoogleFonts.poppinsItalic(),
    );

    // 🌟 PRE-FETCH ALL STORE LOGOS FROM B2 🌟
    // We must download the images before drawing the PDF pages
    Map<String, pw.ImageProvider> preloadedStoreLogos = {};
    for (var store in data.stores) {
      if (store.hasActivity && store.logoUrl != null && store.logoUrl!.isNotEmpty) {
        try {
          preloadedStoreLogos[store.id] = await networkImage(store.logoUrl!);
        } catch (e) {
          print("⚠️ Could not load logo for ${store.name}: $e");
        }
      }
    }

    // --- PAGE 1: COVER PAGE ---
    pdf.addPage(
      pw.Page(
        pageTheme: pw.PageTheme(
          theme: theme,
          margin: pw.EdgeInsets.zero,
        ),
        build: (context) => _buildCoverPage(data, logoImage),
      ),
    );

    // --- PAGE 2: EXECUTIVE SUMMARY ---
    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: theme,
          margin: const pw.EdgeInsets.all(40),
        ),
        header: (context) => _buildHeader(context, data, logoImage),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildExecutiveSummary(data),
          pw.SizedBox(height: 30),
          _buildChartsRow(data),
        ],
      ),
    );

    // --- PAGE 3+: STORE DETAILS (ONE STORE PER PAGE) ---
    bool isFirstStore = true;

    for (var store in data.stores) {
      if (!store.hasActivity) continue;

      pdf.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            theme: theme,
            margin: const pw.EdgeInsets.all(40),
          ),
          header: (context) => _buildHeader(context, data, logoImage),
          footer: (context) => _buildFooter(context),
          build: (context) => [
            if (isFirstStore) ...[
              pw.Text("DÉTAILS PAR SITE", style: pw.TextStyle(fontSize: 18, color: _primaryNavy, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 15),
            ],

            // ✅ Pass the preloaded logo to the builder
            ..._buildStoreSection(store, preloadedStoreLogos[store.id]),
          ],
        ),
      );

      isFirstStore = false;
    }

    return pdf.save();
  }

  // ---------------------------------------------------------------------------
  // 👔 COVER PAGE
  // ---------------------------------------------------------------------------
  pw.Widget _buildCoverPage(ClientReportData data, pw.MemoryImage? logo) {
    final dateFormat = DateFormat('dd MMMM yyyy', 'fr_FR');
    final period = "${dateFormat.format(data.startDate)} au ${dateFormat.format(data.endDate)}";

    return pw.Container(
      color: _primaryNavy,
      padding: const pw.EdgeInsets.all(50),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Spacer(),
          if (logo != null) pw.Image(logo, width: 150),
          pw.SizedBox(height: 40),
          pw.Text("RAPPORT D'ACTIVITÉ", style: pw.TextStyle(color: _accentGold, fontSize: 14, letterSpacing: 2, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Text(data.clientName.toUpperCase(), style: pw.TextStyle(color: PdfColors.white, fontSize: 36, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),
          pw.Container(height: 4, width: 60, color: _accentBlue),
          pw.SizedBox(height: 20),
          pw.Text("Période analysée : $period", style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 14)),
          pw.Spacer(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text("Propriété de BOITEX INFO", style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 10)),
              pw.Text("Généré le ${dateFormat.format(DateTime.now())}", style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 10)),
            ],
          )
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 📊 EXECUTIVE SUMMARY
  // ---------------------------------------------------------------------------
  pw.Widget _buildExecutiveSummary(ClientReportData data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text("SYNTHÈSE GLOBALE", style: pw.TextStyle(fontSize: 18, color: _primaryNavy, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 15),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _buildKpiCard("Interventions", data.totalInterventions.toString(), PdfColors.blueAccent),
            _buildKpiCard("Installations", data.totalInstallations.toString(), PdfColors.purpleAccent),
            _buildKpiCard("Livraisons", data.totalLivraisons.toString(), PdfColors.green),
            _buildKpiCard("Équipements", data.totalEquipment.toString(), _accentGold),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildKpiCard(String title, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.symmetric(horizontal: 4),
        padding: const pw.EdgeInsets.all(15),
        decoration: pw.BoxDecoration(
          color: _lightGray,
          border: pw.Border(left: pw.BorderSide(color: color, width: 4)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(value, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: _textDark)),
            pw.SizedBox(height: 4),
            pw.Text(title.toUpperCase(), style: pw.TextStyle(fontSize: 9, color: _textMuted, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🏢 STORE DETAILS
  // ---------------------------------------------------------------------------
  // ✅ ADDED `storeLogo` PARAMETER
  List<pw.Widget> _buildStoreSection(StoreReportData store, pw.ImageProvider? storeLogo) {
    return [
      // Store Header
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: _primaryNavy,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // ✅ DISPLAY THE STORE LOGO IF AVAILABLE
                  if (storeLogo != null) ...[
                    pw.Container(
                      height: 22,
                      width: 22,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        shape: pw.BoxShape.circle,
                        image: pw.DecorationImage(image: storeLogo, fit: pw.BoxFit.contain),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                  ],
                  pw.Text(store.name.toUpperCase(), style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 14)),
                ]
            ),
            pw.Text(store.location, style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 10)),
          ],
        ),
      ),
      pw.SizedBox(height: 15),

      // 1. Livraisons Table
      if (store.livraisons.isNotEmpty) ...[
        pw.Text("Livraisons", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _accentBlue)),
        pw.SizedBox(height: 6),
        _buildLivraisonTable(store.livraisons),
        pw.SizedBox(height: 20),
      ],

      // 2. Installations Table
      if (store.installations.isNotEmpty) ...[
        pw.Text("Installations", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.purple)),
        pw.SizedBox(height: 6),
        _buildInstallationTable(store.installations),
        pw.SizedBox(height: 20),
      ],

      // 3. Interventions / SAV Table
      if (store.interventions.isNotEmpty) ...[
        pw.Text("Interventions & SAV", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.orange)),
        pw.SizedBox(height: 6),
        _buildInterventionTable(store.interventions),
        pw.SizedBox(height: 20),
      ],

      // Bottom spacing
      pw.SizedBox(height: 15),
    ];
  }

  // --- Premium Tables ---

  pw.Widget _buildLivraisonTable(List<LivraisonReportItem> items) {
    return pw.Table.fromTextArray(
      headers: ['Date', 'Code BL', 'Destinataire', 'Détails Produits', 'Statut'],
      columnWidths: {
        0: const pw.FixedColumnWidth(55),
        1: const pw.FixedColumnWidth(65),
        2: const pw.FixedColumnWidth(80),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FixedColumnWidth(55),
      },
      data: items.map((i) {
        String productsString = i.products.map((p) {
          String detail = '• ${p.name} (${p.marque} | ${p.partNumber})\n  Qté: ${p.quantity}';
          if (p.serialNumbers.isNotEmpty) {
            detail += '\n  SN: ${p.serialNumbers.join(", ")}';
          }
          return detail;
        }).join('\n\n');

        if (productsString.isEmpty) {
          productsString = 'Aucun détail';
        }

        return [
          DateFormat('dd/MM/yy').format(i.date),
          _clean(i.code),
          _clean(i.recipient),
          _clean(productsString),
          _clean(i.status)
        ];
      }).toList(),
      headerStyle: pw.TextStyle(color: _textMuted, fontSize: 9, fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: _lightGray),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _lightGray, width: 0.5)),
    );
  }

  pw.Widget _buildInstallationTable(List<InstallationReportItem> items) {
    return pw.Table.fromTextArray(
      headers: ['Date', 'Code', 'Techniciens', 'Détails Produits', 'Statut'],
      columnWidths: {
        0: const pw.FixedColumnWidth(55),
        1: const pw.FixedColumnWidth(65),
        2: const pw.FixedColumnWidth(80),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FixedColumnWidth(55)
      },
      data: items.map((i) {
        String productsString = i.products.map((p) {
          String detail = '• ${p.name} (${p.marque} | ${p.reference})\n  Qté: ${p.quantity}';
          if (p.serialNumbers.isNotEmpty) {
            detail += '\n  SN: ${p.serialNumbers.join(", ")}';
          }
          return detail;
        }).join('\n\n');

        if (productsString.isEmpty) {
          productsString = 'Aucun équipement installé';
        }

        return [
          DateFormat('dd/MM/yy').format(i.date),
          _clean(i.code),
          _clean(i.technicians),
          _clean(productsString),
          _clean(i.status)
        ];
      }).toList(),
      headerStyle: pw.TextStyle(color: _textMuted, fontSize: 9, fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: _lightGray),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _lightGray, width: 0.5)),
    );
  }

  pw.Widget _buildInterventionTable(List<InterventionReportItem> items) {
    return pw.Table.fromTextArray(
      headers: ['Date', 'Type', 'Technicien', 'Diagnostic', 'Statut'],
      columnWidths: { 0: const pw.FixedColumnWidth(60), 3: const pw.FlexColumnWidth(2), 4: const pw.FixedColumnWidth(60) },
      data: items.map((i) => [
        DateFormat('dd/MM/yy').format(i.date),
        _clean(i.type),
        _clean(i.technician),
        _clean(i.diagnostic),
        _clean(i.status)
      ]).toList(),
      headerStyle: pw.TextStyle(color: _textMuted, fontSize: 9, fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: _lightGray),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _lightGray, width: 0.5)),
    );
  }

  // ---------------------------------------------------------------------------
  // 📈 CHARTS & UTILS
  // ---------------------------------------------------------------------------
  pw.Widget _buildChartsRow(ClientReportData data) {
    if (data.activityByType.isEmpty) return pw.Container();

    return pw.Row(
        children: [
          pw.Expanded(
              child: pw.Container(
                height: 120,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: _lightGray), borderRadius: pw.BorderRadius.circular(8)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Répartition de l'Activité", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _primaryNavy)),
                    pw.SizedBox(height: 10),
                    pw.Expanded(
                      child: pw.Chart(
                        grid: pw.PieGrid(),
                        datasets: List.generate(data.activityByType.length, (index) {
                          final key = data.activityByType.keys.elementAt(index);
                          final value = data.activityByType.values.elementAt(index);
                          final colors = [PdfColors.blueAccent, PdfColors.purpleAccent, PdfColors.green];
                          return pw.PieDataSet(
                            legend: "$key ($value)", value: value, color: colors[index % colors.length], legendStyle: const pw.TextStyle(fontSize: 8),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              )
          ),
        ]
    );
  }

  pw.Widget _buildHeader(pw.Context context, ClientReportData data, pw.MemoryImage? logo) {
    if (context.pageNumber == 1) return pw.Container(); // No header on cover

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text("Rapport d'Activité : ${data.clientName}", style: pw.TextStyle(color: _primaryNavy, fontWeight: pw.FontWeight.bold, fontSize: 10)),
          if (logo != null) pw.Image(logo, width: 60),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    if (context.pageNumber == 1) return pw.Container(); // No footer on cover

    return pw.Container(
        margin: const pw.EdgeInsets.only(top: 10),
        decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _lightGray))),
        padding: const pw.EdgeInsets.only(top: 5),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text("BOITEX INFO - Confidentiel", style: const pw.TextStyle(color: _textMuted, fontSize: 8)),
              pw.Text("Page ${context.pageNumber} / ${context.pagesCount}", style: const pw.TextStyle(color: _textMuted, fontSize: 8)),
            ]
        )
    );
  }

  // 🧹 Cleans invisible characters (like Zero-Width Spaces) from strings
  String _clean(String text) {
    return text
        .replaceAll('\u200B', '') // Zero-width space
        .replaceAll('\u200C', '') // Zero-width non-joiner
        .replaceAll('\u200D', '') // Zero-width joiner
        .replaceAll('\uFEFF', ''); // Byte order mark
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