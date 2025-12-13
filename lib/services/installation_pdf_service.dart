// lib/services/installation_pdf_service.dart
// BOITEX INFO - ULTRA-PREMIUM PDF Generation Service
// 2025 Microsoft/Google-Level Design Quality
// ✅ READY TO USE - ALL FIXES APPLIED
// Contact: commercial@boitexinfo.com | +213 560 367 256

import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class InstallationPdfService {

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
  static final PdfColor brandPrimary = PdfColor.fromHex('#0078D4');
  static final PdfColor brandSecondary = PdfColor.fromHex('#107C10');
  static final PdfColor darkText = PdfColor.fromHex('#1A1A1A');
  static final PdfColor subtleGray = PdfColor.fromHex('#605E5C');
  static final PdfColor lightBg = PdfColor.fromHex('#F3F2F1');
  static final PdfColor accentOrange = PdfColor.fromHex('#FF6B35');
  static final PdfColor cardBg = PdfColors.white;
  static final PdfColor dividerColor = PdfColor.fromHex('#EDEBE9');

  // ═══════════════════════════════════════════════════════════════
  // MAIN PDF GENERATION
  // ═══════════════════════════════════════════════════════════════
  static Future<File> generateInstallationReport({
    required Map<String, dynamic> installationData,
  }) async {
    final pdf = pw.Document();

    // Load company logo
    pw.ImageProvider? logoImage;
    try {
      final bytes = await rootBundle.load('assets/boitex_logo.png');
      logoImage = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (e) {
      print('Logo not found: $e');
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(0),
        build: (context) => [
          _buildCoverPage(installationData, logoImage),
          pw.SizedBox(height: 40),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildModernSection(
                  title: 'Client Information',
                  icon: '📋',
                  children: [
                    _buildInfoGrid([
                      {'label': 'Nom du client', 'value': installationData['clientName'] ?? 'N/A'},
                      {'label': 'Téléphone', 'value': installationData['clientPhone'] ?? 'N/A'},
                      {'label': 'Magasin', 'value': installationData['storeName'] ?? 'N/A'},
                      {'label': 'Adresse', 'value': installationData['storeLocation'] ?? 'N/A'},
                    ]),
                  ],
                ),
                pw.SizedBox(height: 30),
                _buildModernSection(
                  title: 'Détails du Projet',
                  icon: '🎯',
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(16),
                      decoration: pw.BoxDecoration(
                        color: lightBg,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      ),
                      child: pw.Text(
                        installationData['initialRequest'] ?? 'Non spécifié',
                        style: pw.TextStyle(fontSize: 11, color: darkText, height: 1.5),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 30),
                if (installationData['orderedProducts'] != null &&
                    (installationData['orderedProducts'] as List).isNotEmpty)
                  _buildProductsSection(installationData['orderedProducts']),
                pw.SizedBox(height: 30),
                if (installationData['technicalEvaluation'] != null &&
                    (installationData['technicalEvaluation'] as List).isNotEmpty)
                  _buildTechnicalSection(installationData['technicalEvaluation']),
                pw.SizedBox(height: 30),
                if (installationData['assignedTechnicians'] != null &&
                    (installationData['assignedTechnicians'] as List).isNotEmpty)
                  _buildTechniciansSection(installationData['assignedTechnicians']),
                pw.SizedBox(height: 30),
                _buildModernSection(
                  title: 'Travaux Effectués',
                  icon: '✅',
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(16),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#E7F5E6'),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      ),
                      child: pw.Text(
                        installationData['reportNotes'] ?? 'Aucune note disponible',
                        style: pw.TextStyle(fontSize: 11, color: darkText, height: 1.5),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 30),
                if (installationData['signatureUrl'] != null)
                  _buildSignatureSection(installationData),
              ],
            ),
          ),
        ],
        footer: (context) => _buildPremiumFooter(context),
      ),
    );

    return await _savePdfToDevice(pdf, installationData);
  }

  // ═══════════════════════════════════════════════════════════════
  // PREMIUM COVER PAGE (Full-width hero design)
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildCoverPage(Map<String, dynamic> data, pw.ImageProvider? logo) {
    final now = DateTime.now();
    final formattedDate = DateFormat('dd MMMM yyyy', 'fr_FR').format(now);
    final clientName = data['clientName'] ?? 'Client';
    final installationCode = data['installationCode'] ?? 'N/A';

    return pw.Container(
      height: 320,
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [brandPrimary, PdfColor.fromHex('#005A9E')],
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
        ),
      ),
      child: pw.Stack(
        children: [
          pw.Positioned.fill(
            child: pw.Opacity(
              opacity: 0.05,
              child: pw.GridView(
                crossAxisCount: 8,
                children: List.generate(64, (i) =>
                    pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.white, width: 0.5),
                      ),
                    ),
                ),
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    if (logo != null) ...[
                      pw.Container(
                        width: 100,
                        height: 100,
                        child: pw.Image(logo, fit: pw.BoxFit.contain),
                      ),
                      pw.SizedBox(width: 16),
                    ],
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          companyName,
                          style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.Text(
                          'Service Technique Professionnel',
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColor.fromHex('#FFFFFF99'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'RAPPORT D\'INSTALLATION',
                      style: pw.TextStyle(
                        fontSize: 38,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        letterSpacing: -1,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(30)),
                      ),
                      child: pw.Text(
                        installationCode,
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: brandPrimary,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Row(
                      children: [
                        pw.Text(
                          '📅  $formattedDate',
                          style: pw.TextStyle(fontSize: 12, color: PdfColors.white),
                        ),
                        pw.SizedBox(width: 20),
                        pw.Text(
                          '👤  $clientName',
                          style: pw.TextStyle(fontSize: 12, color: PdfColors.white),
                        ),
                      ],
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

  // ═══════════════════════════════════════════════════════════════
  // MODERN SECTION BUILDER
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildModernSection({
    required String title,
    required String icon,
    required List<pw.Widget> children,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Text(icon, style: const pw.TextStyle(fontSize: 20)),
            pw.SizedBox(width: 10),
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: darkText,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
            color: cardBg,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
            border: pw.Border.all(color: dividerColor, width: 1),
            boxShadow: [
              pw.BoxShadow(
                color: PdfColor.fromHex('#0000000A'),
                blurRadius: 8,
                offset: const PdfPoint(0, 2),
              ),
            ],
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // INFO GRID (2-column layout)
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildInfoGrid(List<Map<String, String>> items) {
    return pw.Column(
      children: [
        for (int i = 0; i < items.length; i += 2)
          pw.Padding(
            padding: pw.EdgeInsets.only(bottom: i < items.length - 2 ? 16 : 0),
            child: pw.Row(
              children: [
                pw.Expanded(child: _buildInfoItem(items[i])),
                pw.SizedBox(width: 20),
                if (i + 1 < items.length)
                  pw.Expanded(child: _buildInfoItem(items[i + 1]))
                else
                  pw.Expanded(child: pw.SizedBox()),
              ],
            ),
          ),
      ],
    );
  }

  static pw.Widget _buildInfoItem(Map<String, String> item) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          item['label']!,
          style: pw.TextStyle(
            fontSize: 9,
            color: subtleGray,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          item['value']!,
          style: pw.TextStyle(
            fontSize: 11,
            color: darkText,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // PRODUCTS SECTION (Modern card design)
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildProductsSection(List<dynamic> products) {
    return _buildModernSection(
      title: 'Produits Installés',
      icon: '📦',
      children: [
        ...products.map((product) {
          final productName = product['productName'] ?? 'Produit inconnu';
          final quantity = product['quantity'] ?? 0;
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: lightBg,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    productName,
                    style: pw.TextStyle(fontSize: 11, color: darkText, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: brandPrimary,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(20)),
                  ),
                  child: pw.Text(
                    'Qté: $quantity',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.white, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TECHNICAL EVALUATION SECTION
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildTechnicalSection(List<dynamic> evaluations) {
    return _buildModernSection(
      title: 'Évaluation Technique',
      icon: '📐',
      children: [
        ...evaluations.asMap().entries.map((entry) {
          final i = entry.key;
          final eval = entry.value;
          final entranceType = eval['entranceType'] ?? 'Entrée';
          final doorType = eval['doorType'] ?? 'N/A';
          final entranceLength = eval['entranceLength'] ?? '?';
          final entranceWidth = eval['entranceWidth'] ?? '?';
          final hasPower = eval['hasPower'] == true;
          final hasConduit = eval['hasConduit'] == true;

          return pw.Container(
            margin: pw.EdgeInsets.only(bottom: i < evaluations.length - 1 ? 16 : 0),
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F0F8FF'),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: PdfColor.fromHex('#B3D9F2'), width: 1),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '$entranceType #${i + 1}',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: brandPrimary),
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Type de porte', style: pw.TextStyle(fontSize: 9, color: subtleGray)),
                          pw.Text(doorType, style: pw.TextStyle(fontSize: 10, color: darkText)),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Dimensions', style: pw.TextStyle(fontSize: 9, color: subtleGray)),
                          pw.Text('$entranceLength × $entranceWidth m',
                              style: pw.TextStyle(fontSize: 10, color: darkText)),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  children: [
                    _buildCheckItem('220V', hasPower),
                    pw.SizedBox(width: 16),
                    _buildCheckItem('Gaine', hasConduit),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  static pw.Widget _buildCheckItem(String label, bool checked) {
    return pw.Row(
      children: [
        pw.Container(
          width: 16,
          height: 16,
          decoration: pw.BoxDecoration(
            color: checked ? brandSecondary : PdfColors.grey300,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: checked
              ? pw.Center(
            child: pw.Text('✓', style: pw.TextStyle(fontSize: 12, color: PdfColors.white)),
          )
              : null,
        ),
        pw.SizedBox(width: 6),
        pw.Text(label, style: pw.TextStyle(fontSize: 10, color: darkText)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TECHNICIANS SECTION
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildTechniciansSection(List<dynamic> technicians) {
    return _buildModernSection(
      title: 'Techniciens Assignés',
      icon: '👥',
      children: [
        pw.Wrap(
          spacing: 10,
          runSpacing: 10,
          children: technicians.map((tech) {
            final techName = tech['displayName'] ?? 'Technicien';
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: pw.BoxDecoration(
                color: lightBg,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(20)),
                border: pw.Border.all(color: dividerColor),
              ),
              child: pw.Text(
                techName,
                style: pw.TextStyle(fontSize: 10, color: darkText),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SIGNATURE SECTION
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildSignatureSection(Map<String, dynamic> data) {
    final signedDate = data['signatureTimestamp'] != null
        ? DateFormat('dd MMMM yyyy', 'fr_FR').format(DateTime.parse(data['signatureTimestamp']))
        : 'Date inconnue';

    return _buildModernSection(
      title: 'Signature Client',
      icon: '✍️',
      children: [
        pw.Container(
          height: 120,
          decoration: pw.BoxDecoration(
            color: lightBg,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            border: pw.Border.all(color: dividerColor),
          ),
          child: pw.Center(
            child: pw.Text(
              '[Image de signature]',
              style: pw.TextStyle(fontSize: 10, color: subtleGray),
            ),
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'Signé le: $signedDate',
          style: pw.TextStyle(fontSize: 10, color: subtleGray),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // PREMIUM FOOTER
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildPremiumFooter(pw.Context context) {
    final now = DateTime.now();
    final formattedDateTime = DateFormat('dd MMMM yyyy à HH:mm', 'fr_FR').format(now);

    return pw.Container(
      height: 80,
      padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: dividerColor, width: 1)),
        color: lightBg,
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                companyName,
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: darkText),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '$companyEmail | $companyPhone',
                style: pw.TextStyle(fontSize: 8, color: subtleGray),
              ),
              pw.Text(
                companyWebsite,
                style: pw.TextStyle(fontSize: 8, color: subtleGray),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                'Page ${context.pageNumber} sur ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 9, color: subtleGray),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Généré le $formattedDateTime',
                style: pw.TextStyle(fontSize: 8, color: subtleGray),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SAVE TO DEVICE
  // ═══════════════════════════════════════════════════════════════
  static Future<File> _savePdfToDevice(pw.Document pdf, Map<String, dynamic> data) async {
    final bytes = await pdf.save();
    final dir = await getApplicationDocumentsDirectory();
    final installationCode = data['installationCode'] ?? 'INST-X';
    final clientName = (data['clientName'] ?? 'Client').replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final cleanCode = installationCode.toString().replaceAll('/', '-');
    final filename = 'Installation_${cleanCode}_$clientName.pdf';
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    return file;
  }

  // ═══════════════════════════════════════════════════════════════
  // WHATSAPP MESSAGE
  // ═══════════════════════════════════════════════════════════════
  static String generateWhatsAppMessage(Map<String, dynamic> data) {
    final code = data['installationCode'] ?? 'N/A';
    final clientName = data['clientName'] ?? 'Client';
    final now = DateTime.now();
    final date = DateFormat('dd MMMM yyyy', 'fr_FR').format(now);

    return '''Bonjour,

Voici votre rapport d'installation technique de BOITEX INFO.

📋 Code: $code
🏪 Client: $clientName
📅 Date: $date

Merci pour votre confiance.

BOITEX INFO
$companyEmail
$companyPhone
$companyWebsite''';
  }

  // ═══════════════════════════════════════════════════════════════
  // EMAIL CONTENT
  // ═══════════════════════════════════════════════════════════════
  static Map<String, String> generateEmailContent(Map<String, dynamic> data) {
    final code = data['installationCode'] ?? 'N/A';
    final clientName = data['clientName'] ?? 'Client';
    final now = DateTime.now();
    final date = DateFormat('dd MMMM yyyy', 'fr_FR').format(now);

    return {
      'subject': '✅ Rapport d\'Installation $code - $clientName',
      'body': '''Bonjour,

Veuillez trouver ci-joint le rapport détaillé de l'installation technique réalisée par BOITEX INFO.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 DÉTAILS DE L'INSTALLATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Code: $code
Client: $clientName
Date: $date
Statut: ✅ Terminée

Le rapport complet est disponible en pièce jointe au format PDF.

Pour toute question, n'hésitez pas à nous contacter.

Cordialement,
L'équipe BOITEX INFO

📧 $companyEmail
📱 $companyPhone
🌐 $companyWebsite'''
    };
  }
}
