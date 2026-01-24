// lib/services/project_dossier_service.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

// Packages for Saving & Opening
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:file_saver/file_saver.dart';

class ProjectDossierService {
  // 2026 Premium Design Tokens
  static const PdfColor boitexNavy = PdfColor.fromInt(0xff0A192F);
  static const PdfColor boitexBlue = PdfColor.fromInt(0xff00D2FF);
  static const PdfColor boitexBlueFaded = PdfColor.fromInt(0xff80E9FF);
  static const PdfColor slateGray = PdfColor.fromInt(0xff4A5568);
  static const PdfColor surfaceLight = PdfColor.fromInt(0xffF7FAFC);
  static const PdfColor dividerColor = PdfColor.fromInt(0xffCBD5E0);

  /// 🚀 MAIN METHOD: Generates, Saves, and Opens the PDF
  /// Handles Web vs Mobile logic automatically.
  static Future<void> generateAndOpen(Map<String, dynamic> projectData, String fileName) async {
    try {
      // 1. Generate the raw PDF bytes
      final Uint8List bytes = await _generateBytes(projectData);

      // 2. Platform-specific Save & Launch
      if (kIsWeb) {
        // ✅ WEB: Trigger Browser Download using FileSaver
        // Note: We don't need 'open_filex' on web, the browser handles the download.
        await FileSaver.instance.saveFile(
          name: fileName.replaceAll('.pdf', ''), // remove extension if present (FileSaver adds it)
          bytes: bytes,
          ext: 'pdf',
          mimeType: MimeType.pdf,
        );
        print('✅ PDF Downloaded on Web');
      } else {
        // 📱 MOBILE: Save to Temp & Open
        final output = await getTemporaryDirectory();
        final file = File('${output.path}/$fileName');
        await file.writeAsBytes(bytes);

        // Open the file using the native viewer
        await OpenFilex.open(file.path);
        print('✅ PDF Saved & Opened on Mobile: ${file.path}');
      }
    } catch (e) {
      print('❌ Error in ProjectDossierService: $e');
    }
  }

  /// Internal method to generate PDF bytes (Private)
  static Future<Uint8List> _generateBytes(Map<String, dynamic> projectData) async {
    final pdf = pw.Document();

    // Load Logo with safe fallback
    pw.MemoryImage? logoImage;
    try {
      final logoProvider = await rootBundle.load('assets/boitex_logo.png');
      logoImage = pw.MemoryImage(logoProvider.buffer.asUint8List());
    } catch (e) {
      print("Notice: ProjectDossierService using text fallback (Logo not found).");
    }

    final String client = (projectData['clientName'] ?? 'CLIENT ANONYME').toString().toUpperCase();
    final String store = (projectData['storeName'] ?? 'UNITÉ COMMERCIALE').toString().toUpperCase();
    final String status = (projectData['status'] ?? 'EN COURS').toString().toUpperCase();
    final String requestId = projectData['projectId']?.toString().toUpperCase().substring(0, 8) ?? 'PRJ-2026';

    final DateTime date = projectData['createdAt'] != null
        ? (projectData['createdAt'] as dynamic).toDate()
        : DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(0),
        build: (context) => [
          _buildCoverHeader(logoImage, client, store, requestId, date, status),

          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 25),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildModernSectionTitle('01', 'SYNTHÈSE DE LA DEMANDE'),
                _buildRequestBox(projectData['initialRequest'] ?? 'Pas de description fournie.'),

                pw.SizedBox(height: 30),

                if (projectData['technical_evaluation'] != null) ...[
                  _buildModernSectionTitle('02', 'AUDIT TECHNIQUE SÉCURITÉ'),
                  ..._buildTechnicalGrid(projectData['technical_evaluation'] ?? []),
                  pw.SizedBox(height: 30),
                ],

                if (projectData['it_evaluation'] != null && (projectData['it_evaluation'] as Map).isNotEmpty) ...[
                  _buildModernSectionTitle('03', 'INFRASTRUCTURE DIGITALE & IT'),
                  _buildITModule(projectData['it_evaluation']),
                  pw.SizedBox(height: 30),
                ],

                if (projectData['orderedProducts'] != null && (projectData['orderedProducts'] as List).isNotEmpty) ...[
                  _buildModernSectionTitle('04', 'CONFIGURATION MATÉRIELLE'),
                  _buildPremiumTable(projectData['orderedProducts']),
                ],
              ],
            ),
          ),
        ],
        footer: (context) => _buildModernFooter(context),
      ),
    );

    return pdf.save();
  }

  // --- UI COMPONENTS ---

  static pw.Widget _buildCoverHeader(pw.MemoryImage? logo, String client, String store, String id, DateTime date, String status) {
    return pw.Container(
      height: 240,
      child: pw.Stack(
        children: [
          pw.Container(height: 220, color: boitexNavy),
          pw.Positioned(left: 0, top: 0, bottom: 20, child: pw.Container(width: 8, color: boitexBlue)),

          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(40, 50, 40, 0),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    if (logo != null)
                      pw.Image(logo, height: 50)
                    else
                      pw.Text("BOITEX INFO", style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 18)),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('RÉFÉRENCE DOSSIER', style: pw.TextStyle(color: boitexBlue, fontSize: 7, letterSpacing: 1.2)),
                        pw.Text(id, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 50),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(client, style: pw.TextStyle(color: PdfColors.white, fontSize: 24, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text(store, style: pw.TextStyle(color: boitexBlue, fontSize: 11, letterSpacing: 1.5)),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: boitexBlue, width: 1.5),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(status, style: pw.TextStyle(color: boitexBlue, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildModernSectionTitle(String num, String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 18),
      child: pw.Row(
        children: [
          pw.Text(num, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: boitexBlue)),
          pw.SizedBox(width: 12),
          pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: boitexNavy, letterSpacing: 1)),
          pw.SizedBox(width: 12),
          pw.Expanded(child: pw.Container(height: 0.8, color: dividerColor)),
        ],
      ),
    );
  }

  static pw.Widget _buildRequestBox(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: surfaceLight,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: dividerColor),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 10, color: slateGray, lineSpacing: 3.5),
      ),
    );
  }

  static List<pw.Widget> _buildTechnicalGrid(List<dynamic> evals) {
    return evals.map((e) => pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: dividerColor),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(width: 3, height: 14, color: boitexBlue),
              pw.SizedBox(width: 10),
              pw.Text('POINT D\'ACCÈS : ${e['entranceType'] ?? 'STANDARD'}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5, color: boitexNavy)),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _infoKpi('DIMENSION', '${e['entranceWidth'] ?? 'N/A'}m'),
              _infoKpi('ALIMENTATION', (e['isPowerAvailable'] == true) ? 'PRÉSENTE' : 'MANQUANTE'),
              _infoKpi('STRUCTURE SOL', (e['isFloorFinalized'] == true) ? 'DÉFINITIF' : 'EN TRAVAUX'),
            ],
          ),
        ],
      ),
    )).toList();
  }

  static pw.Widget _buildITModule(Map<String, dynamic> it) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: boitexNavy,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _infoKpi('LIAISON INTERNET', it['internetAccessType'] ?? 'N/A', light: true),
              _infoKpi('INFRA RÉSEAU', (it['hasNetworkRack'] == true) ? 'BAIE OK' : 'SANS BAIE', light: true),
              _infoKpi('HAUTE TENSION', (it['hasHighVoltage'] == true) ? 'À PROXIMITÉ' : 'AUCUNE', light: true),
            ],
          ),
          pw.SizedBox(height: 15),
          pw.Container(height: 0.5, color: boitexBlueFaded),
          pw.SizedBox(height: 12),
          pw.Text('OBSERVATIONS TECHNIQUES :', style: pw.TextStyle(color: boitexBlue, fontSize: 7, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(it['networkNotes'] ?? "Aucune note spécifique renseignée pour l'infrastructure IT.",
              style: pw.TextStyle(color: PdfColors.white, fontSize: 9, lineSpacing: 2)),
        ],
      ),
    );
  }

  static pw.Widget _buildPremiumTable(List<dynamic> products) {
    return pw.Table(
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: boitexNavy),
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(12), child: pw.Text('DÉSIGNATION MATÉRIEL', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8.5))),
            pw.Padding(padding: const pw.EdgeInsets.all(12), child: pw.Text('UNITÉS', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8.5), textAlign: pw.TextAlign.center)),
          ],
        ),
        ...products.map((p) => pw.TableRow(
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: dividerColor, width: 0.6))),
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(12), child: pw.Text(p['productName'] ?? 'ARTICLE TECHNIQUE', style: const pw.TextStyle(fontSize: 9.5, color: boitexNavy))),
            pw.Padding(padding: const pw.EdgeInsets.all(12), child: pw.Text('${p['quantity'] ?? 1}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: boitexNavy), textAlign: pw.TextAlign.center)),
          ],
        )),
      ],
    );
  }

  static pw.Widget _infoKpi(String label, String value, {bool light = false}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 7, color: light ? boitexBlue : slateGray, letterSpacing: 0.8)),
        pw.SizedBox(height: 4),
        pw.Text(value.toString().toUpperCase(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: light ? PdfColors.white : boitexNavy)),
      ],
    );
  }

  static pw.Widget _buildModernFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 25),
      child: pw.Column(
        children: [
          pw.Container(height: 0.8, color: dividerColor),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('BOITEXINFO PORTAL - CERTIFIED ARCHITECT REPORT 2026', style: const pw.TextStyle(fontSize: 6.5, color: slateGray, letterSpacing: 0.5)),
              pw.Text('DOCUMENT PAGE ${context.pageNumber} SUR ${context.pagesCount}', style: const pw.TextStyle(fontSize: 6.5, color: slateGray)),
            ],
          ),
        ],
      ),
    );
  }
}