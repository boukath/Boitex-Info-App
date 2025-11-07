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

// ⭐️ --- IMPORTS ADDED FOR STEP 2B ---
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
// ⭐️ --- END OF ADDED IMPORTS ---


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

    // ⭐️ --- ADDED: Load network image for signature if it exists ---
    pw.MemoryImage? signatureImage;
    if (data['clientSignatureUrl'] != null && (data['clientSignatureUrl'] as String).isNotEmpty) {
      try {
        // We use 'http' to fetch the image bytes
        final response = await http.get(Uri.parse(data['clientSignatureUrl']));
        if (response.statusCode == 200) {
          signatureImage = pw.MemoryImage(response.bodyBytes);
        } else {
          print('Failed to load signature image: ${response.statusCode}');
        }
      } catch (e) {
        print('Error fetching signature image: $e');
      }
    }
    // ⭐️ --- END OF ADDED LOGIC ---

    final pageTheme = await _buildTheme();

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        header: (context) => _buildHeader(context, logo),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          // ⭐️ --- MODIFIED: Pass the signature image to the content builder ---
          _buildContent(context, data, signatureImage),
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
        // Using Open Sans as a reliable default Google Font
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

  // ⭐️ --- MODIFIED: Added 'signatureImage' parameter ---
  static pw.Widget _buildContent(pw.Context context, Map<String, dynamic> data, pw.MemoryImage? signatureImage) {
    final interventionCode = data['interventionCode'] ?? 'N/A';
    final clientName = data['clientName'] ?? 'N/A';

    // Handle potential Timestamp from Firestore vs. DateTime from app
    dynamic createdAtData = data['createdAt'];
    String date = 'N/A';
    if (createdAtData != null) {
      if (createdAtData is Timestamp) {
        date = DateFormat('dd MMMM yyyy', 'fr_FR').format(createdAtData.toDate());
      } else if (createdAtData is DateTime) {
        date = DateFormat('dd MMMM yyyy', 'fr_FR').format(createdAtData);
      }
    }


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
              // ⭐️ --- MODIFIED: Use _buildInfoRow for rich text ---
              _buildInfoRow('Rapport de Problème (Client)', data['problemReport']),
              _buildInfoRow('Diagnostique (Technicien)', data['diagnostic']),
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
                        pw.Text('Technicien Intervenant:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        pw.SizedBox(height: 4),
                        pw.Text('- ${data['createdByName'] ?? 'N/A'}', style: const pw.TextStyle(fontSize: 10)),

                        // ⭐️ --- THIS BLOCK IS NOW FIXED ---
                        if (data['assignedTechnicians'] != null && (data['assignedTechnicians'] as List).isNotEmpty)
                          ... (data['assignedTechnicians'] as List)
                          // 1. Filter the DATA (the maps) first
                              .where((tech) {
                            final String techName = tech['name'] ?? '';
                            final String createdByName = data['createdByName'] ?? 'N/A';
                            return techName.isNotEmpty && techName != createdByName;
                          })
                          // 2. Map the FILTERED data to widgets
                              .map((tech) => pw.Text('- ${tech['name']}', style: const pw.TextStyle(fontSize: 10)))
                              .toList()
                        // ⭐️ --- END OF FIX ---
                      ]
                  )
              ),
              // ⭐️ --- MODIFIED: Use the fetched signatureImage ---
              if (signatureImage != null)
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
                        // Use the signatureImage here
                        child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
                      ),
                    ],
                  ),
                )
              else
                pw.Expanded(
                    flex: 3,
                    child: pw.Container(
                        alignment: pw.Alignment.center,
                        child: pw.Text('Aucune signature client fournie.', style: pw.TextStyle(fontSize: 10, color: secondaryColor, fontStyle: pw.FontStyle.italic))
                    )
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
        crossAxisAlignment: pw.CrossAxisAlignment.start, // ⭐️ Use 'start' for multi-line text
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: secondaryColor, fontSize: 10)),
          pw.SizedBox(width: 10),
          // ⭐️ Use 'Expanded' and 'TextAlign.right' to handle long text wrapping
          pw.Expanded(
              child: pw.Text(
                  (value == null || value.isEmpty) ? 'N/A' : value,
                  textAlign: pw.TextAlign.right,
                  style: const pw.TextStyle(fontSize: 10)
              )
          ),
        ],
      ),
    );
  }

  // ⭐️ ═══════════════════════════════════════════════════════════════
  // ⭐️ NEW FUNCTION: GENERATE, UPLOAD, AND FINALIZE (FROM STEP 2B)
  // ⭐️ ═══════════════════════════════════════════════════════════════
  static Future<void> generateUploadAndFinalize({
    required Map<String, dynamic> interventionData,
    required String interventionId,
  }) async {

    // --- 1. Generate the PDF bytes ---
    print('Étape 1/4: Génération du PDF...');
    // We pass the data to the PDF generator
    final Uint8List pdfData = await generateInterventionPdf(interventionData);
    print('PDF généré (${pdfData.lengthInBytes} bytes)');

    // --- 2. Call Cloud Function to get B2 Upload URL ---
    print('Étape 2/4: Appel de la fonction getB2UploadUrl...');
    final HttpsCallable callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('getB2UploadUrl');

    // ⭐️ --- MODIFICATION: Pass arguments to the callable function ---
    final interventionCode = interventionData['interventionCode'] ?? interventionId;

    final response = await callable.call({
      'interventionId': interventionId,
      'interventionCode': interventionCode,
    });
    // ⭐️ --- END OF MODIFICATION ---

    final b2Creds = response.data as Map<String, dynamic>;

    final String uploadUrl = b2Creds['uploadUrl'];
    final String authToken = b2Creds['authorizationToken'];
    final String b2FileName = b2Creds['b2FileName'];
    final String publicPdfUrl = b2Creds['publicPdfUrl'];
    print('Identifiants B2 reçus.');

    // --- 3. Upload the PDF data to Backblaze B2 ---
    print('Étape 3/4: Téléchargement vers Backblaze...');
    final uploadResponse = await http.post(
      Uri.parse(uploadUrl),
      headers: {
        'Authorization': authToken,
        'X-Bz-File-Name': Uri.encodeComponent(b2FileName), // Ensure filename is URL-safe
        'Content-Type': 'application/pdf',
        'Content-Length': pdfData.lengthInBytes.toString(),
        // 'do_not_verify' is simpler for client-side uploads
        'X-Bz-Content-Sha1': 'do_not_verify',
      },
      body: pdfData,
    );

    if (uploadResponse.statusCode != 200) {
      print('Échec du téléchargement B2: ${uploadResponse.body}');
      throw Exception('Impossible de télécharger le PDF sur Backblaze.');
    }

    print('Téléchargement réussi. URL: $publicPdfUrl');

    // --- 4. Finalize by updating Firestore ---
    print('Étape 4/4: Finalisation du document Firestore...');
    await FirebaseFirestore.instance
        .collection('interventions')
        .doc(interventionId)
        .update({
      // This triggers the email function!
      'status': 'Terminé',

      // The URL our cloud function will download
      'pdfUrl': publicPdfUrl,

      // --- IMPORTANT ---
      // Also save all the data the PDF (and email) will need
      'workDone': interventionData['workDone'],
      'diagnostic': interventionData['diagnostic'],
      'problemReport': interventionData['problemReport'],
      'managerEmail': interventionData['managerEmail'],
      'clientSignatureUrl': interventionData['clientSignatureUrl'],
      'pdfGeneratedAt': FieldValue.serverTimestamp(),
      // Add any other fields you just collected
    });

    print('✅ Intervention finalisée avec succès!');
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