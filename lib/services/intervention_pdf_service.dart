// lib/services/intervention_pdf_service.dart
// BOITEX INFO - ULTRA-PREMIUM PDF Generation Service for Interventions
// 2025 Microsoft/Google-Level Design Quality
// ✅ FIXED: Missing imports added
// Contact: commercial@boitexinfo.com | +213 560 367 256

import 'dart:io';
import 'dart:typed_data'; // ✅ ADDED: For Uint8List
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart'; // ✅ ADDED: For Share and XFile

class InterventionPdfService {

  // ═══════════════════════════════════════════════════════════════
  // COMPANY BRANDING - 2025 Edition
  // ═══════════════════════════════════════════════════════════════
  static const String companyName = 'BOITEX INFO';
  static const String companyEmail = 'commercial@boitexinfo.com';
  static const String companyPhone = '+213 560 367 256';
  static const String companyWebsite = 'www.boitexinfo.com';

  // ═══════════════════════════════════════════════════════════════
  // 2025 PREMIUM COLOR PALETTE (Inspired by Microsoft/Google)
  // ═══════════════════════════════════════════════════════════════
  static const PdfColor primaryColor = PdfColors.blueGrey800;
  static const PdfColor secondaryColor = PdfColors.blueGrey600;
  static const PdfColor accentColor = PdfColors.orange600;
  static const PdfColor backgroundColor = PdfColors.grey100;
  static const PdfColor borderColor = PdfColors.grey300;

  // ═══════════════════════════════════════════════════════════════
  // GENERATE PDF - The Core Function
  // ═══════════════════════════════════════════════════════════════
  static Future<Uint8List> generateInterventionPdf(Map<String, dynamic> data) async {
    final pdf = pw.Document();
    final logo = pw.MemoryImage(
      (await rootBundle.load('assets/boitex_logo.png')).buffer.asUint8List(),
    );
    final pageTheme = await _buildTheme();

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        header: (context) => _buildHeader(context, logo),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildContent(context, data),
        ],
      ),
    );
    return pdf.save();
  }

  // ═══════════════════════════════════════════════════════════════
  // THEME & STYLES - Consistent and Professional
  // ═══════════════════════════════════════════════════════════════
  static Future<pw.PageTheme> _buildTheme() async {
    return pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(
        base: await PdfGoogleFonts.openSansRegular(),
        bold: await PdfGoogleFonts.openSansBold(),
        icons: await PdfGoogleFonts.materialIcons(),
      ),
      buildBackground: (context) => pw.FullPage(
        ignoreMargins: true,
        child: pw.Container(color: backgroundColor),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HEADER - Logo and Title
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildHeader(pw.Context context, pw.MemoryImage logo) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(companyName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18, color: primaryColor)),
                pw.Text('BOITEXINFO Service Technique', style: const pw.TextStyle(color: secondaryColor, fontSize: 10)),
              ],
            ),
            pw.SizedBox(
              height: 50,
              width: 50,
              child: pw.Image(logo),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: borderColor),
        pw.SizedBox(height: 20),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FOOTER - Contact Info and Page Number
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Column(
      children: [
        pw.Divider(color: borderColor),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('$companyEmail | $companyPhone', style: const pw.TextStyle(fontSize: 8, color: secondaryColor)),
            pw.Text(companyWebsite, style: const pw.TextStyle(fontSize: 8, color: secondaryColor)),
            pw.Text('Page ${context.pageNumber} sur ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: secondaryColor)),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Généré le ${DateFormat('dd MMMM yyyy HH:mm', 'fr_FR').format(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // CONTENT - All the Intervention Details
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildContent(pw.Context context, Map<String, dynamic> data) {
    final interventionCode = data['interventionCode'] ?? 'N/A';
    final clientName = data['clientName'] ?? 'N/A';
    final date = data['createdAt'] != null ? DateFormat('dd MMMM yyyy', 'fr_FR').format(data['createdAt'].toDate()) : 'N/A';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Title Section
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 20),
          alignment: pw.Alignment.center,
          child: pw.Column(
            children: [
              pw.Text('RAPPORT D\'INTERVENTION', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: primaryColor)),
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: pw.BoxDecoration(color: accentColor, borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Text(interventionCode, style: pw.TextStyle(fontSize: 14, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 4),
              pw.Text('$date | $clientName', style: const pw.TextStyle(fontSize: 12, color: secondaryColor)),
            ],
          ),
        ),

        // Client and Project Details
        _buildSection(
          icon: pw.IconData(0xe873), // briefcase icon
          title: 'Détails du Client et de l\'Intervention',
          child: pw.Column(
            children: [
              _buildInfoRow('Nom du client', data['clientName']),
              _buildInfoRow('Magasin', '${data['storeName']} - ${data['storeLocation']}'),
              _buildInfoRow('Service', data['serviceType']),
              _buildInfoRow('Contact sur site', '${data['managerName'] ?? 'N/A'} (${data['managerPhone'] ?? 'N/A'})'),
            ],
          ),
        ),

        // Technical Details Section
        _buildSection(
          icon: pw.IconData(0xe163), // build icon
          title: 'Analyse et Solution Technique',
          child: pw.Column(
            children: [
              _buildInfoRow('Diagnostique / Panne Signalée', data['diagnostic']),
              _buildInfoRow('Travaux Effectués', data['workDone']),
            ],
          ),
        ),

        // Technicians and Signature Section
        _buildSection(
          icon: pw.IconData(0xe7fd), // people icon
          title: 'Intervenants et Validation',
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Techniciens Assignés:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        pw.SizedBox(height: 4),
                        if (data['assignedTechnicians'] != null && (data['assignedTechnicians'] as List).isNotEmpty)
                          ... (data['assignedTechnicians'] as List).map((tech) => pw.Text('- ${tech['name']}', style: const pw.TextStyle(fontSize: 10))).toList()
                        else
                          pw.Text('Aucun technicien assigné', style: const pw.TextStyle(fontSize: 10)),
                      ]
                  )
              ),
              if (data['signatureUrl'] != null)
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('Signature du Client', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.SizedBox(height: 8),
                      pw.Container(
                        width: 180,
                        height: 90,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: borderColor),
                          borderRadius: pw.BorderRadius.circular(5),
                        ),
                        child: pw.Image(pw.MemoryImage(data['signatureUrl']), fit: pw.BoxFit.contain),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPER WIDGETS - For building the content sections
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildSection({required pw.IconData icon, required String title, required pw.Widget child}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 20),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Icon(icon, color: accentColor, size: 20),
            pw.SizedBox(width: 8),
            pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          ],
        ),
        pw.Divider(color: borderColor, height: 10, thickness: 1),
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: borderColor),
          ),
          child: child,
        ),
      ],
    );
  }

  static pw.Widget _buildInfoRow(String label, String? value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: secondaryColor, fontSize: 10)),
          pw.SizedBox(width: 10),
          pw.Expanded(child: pw.Text(value ?? 'N/A', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10))),
        ],
      ),
    );
  }


  // ═══════════════════════════════════════════════════════════════
  // SHARE FUNCTIONALITY
  // ═══════════════════════════════════════════════════════════════
  static Future<void> generateAndSharePdf(Map<String, dynamic> data) async {
    final pdfData = await generateInterventionPdf(data);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/Intervention_${data['interventionCode']?.replaceAll('/', '-')}_${data['clientName']}.pdf');
    await file.writeAsBytes(pdfData);

    final emailContent = generateEmailContent(data);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: emailContent['subject'],
      text: emailContent['body'],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // VIEW FUNCTIONALITY
  // ═══════════════════════════════════════════════════════════════
  static Future<void> generateAndPrintPdf(Map<String, dynamic> data) async {
    final pdfData = await generateInterventionPdf(data);
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdfData);
  }
  static Future<Uint8List> generatePdfBytes(Map<String, dynamic> data) async {
    // This just calls your existing core function that builds the PDF
    return await generateInterventionPdf(data);
  }

  // ═══════════════════════════════════════════════════════════════
  // EMAIL CONTENT
  // ═══════════════════════════════════════════════════════════════
  static Map<String, String> generateEmailContent(Map<String, dynamic> data) {
    final code = data['interventionCode'] ?? 'N/A';
    final clientName = data['clientName'] ?? 'Client';
    final now = DateTime.now();
    final date = DateFormat('dd MMMM yyyy', 'fr_FR').format(now);

    return {
      'subject': '✅ Rapport d\'Intervention $code - $clientName',
      'body': '''Bonjour,

Veuillez trouver ci-joint le rapport détaillé de l'intervention technique réalisée par BOITEX INFO.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 DÉTAILS DE L'INTERVENTION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- Code: $code
- Client: $clientName
- Date: $date

Nous restons à votre disposition pour toute information complémentaire.

Cordialement,
L'équipe BOITEX INFO
$companyEmail
$companyPhone
$companyWebsite'''
    };
  }
}