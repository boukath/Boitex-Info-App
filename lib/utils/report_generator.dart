import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class ReportGenerator {
  static Future<void> generateAndSharePdf(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    // Load the logo image from app assets for the watermark
    final logoImageBytes = await rootBundle.load('assets/boitex_logo.png');
    final logoImage = pw.MemoryImage(logoImageBytes.buffer.asUint8List());

    // Download the signature image from its Firebase Storage URL, if it exists
    pw.MemoryImage? signatureImage;
    if (data['report_signatureImageUrl'] != null) {
      try {
        final response = await http.get(Uri.parse(data['report_signatureImageUrl']));
        if (response.statusCode == 200) {
          signatureImage = pw.MemoryImage(response.bodyBytes);
        }
      } catch (e) {
        print("Could not download signature image: $e");
      }
    }

    // Format dates and times
    final dateFormatter = DateFormat('dd MMMM yyyy', 'fr_FR');
    final timeFormatter = DateFormat('HH:mm');
    final interventionDate = (data['interventionDate'] as Timestamp).toDate();
    final arrivalTime = data['report_arrivalTime'] != null ? (data['report_arrivalTime'] as Timestamp).toDate() : null;
    final departureTime = data['report_departureTime'] != null ? (data['report_departureTime'] as Timestamp).toDate() : null;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // Watermark in the background
              pw.Center(
                child: pw.Opacity(
                  opacity: 0.1,
                  child: pw.Image(logoImage, width: 350),
                ),
              ),
              // Main content of the PDF
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Header(
                    level: 0,
                    child: pw.Text('Rapport d\'Intervention - ${data['interventionCode']}', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Divider(),

                  _buildSectionHeader('Résumé de la Demande'),
                  _buildDetailRow('Client:', data['clientName']),
                  _buildDetailRow('Magasin:', '${data['storeName']} - ${data['storeLocation']}'),
                  _buildDetailRow('Date d\'intervention:', dateFormatter.format(interventionDate)),
                  _buildDetailRow('Priorité:', data['priority'] ?? 'N/A'),
                  _buildDetailRow('Description:', data['description'], isMultiLine: true),

                  pw.SizedBox(height: 20),

                  _buildSectionHeader('Rapport d\'Intervention'),
                  _buildDetailRow('Responsable Magasin:', data['report_managerName'] ?? 'N/A'),
                  _buildDetailRow('Numéro Responsable:', data['report_managerPhone'] ?? 'N/A'),
                  _buildDetailRow('Heure d\'arrivée:', arrivalTime != null ? timeFormatter.format(arrivalTime) : 'N/A'),
                  _buildDetailRow('Heure de départ:', departureTime != null ? timeFormatter.format(departureTime) : 'N/A'),
                  _buildDetailRow('Diagnostic:', data['report_diagnostic'] ?? 'N/A', isMultiLine: true),
                  _buildDetailRow('Travaux effectués:', data['report_workDone'] ?? 'N/A', isMultiLine: true),

                  pw.SizedBox(height: 20),

                  if (signatureImage != null)
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Signature du Responsable:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 8),
                        pw.Container(
                          height: 100,
                          width: 200,
                          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey)),
                          child: pw.Image(signatureImage),
                        ),
                      ],
                    ),

                  pw.Spacer(),
                  pw.Divider(),
                  pw.Text('Statut Final: ${data['status']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          );
        },
      ),
    );

    // Use the printing package to open the native share dialog for the PDF
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Rapport-Intervention-${data['interventionCode']}.pdf',
    );
  }

  // Helper function to build a section header in the PDF
  static pw.Widget _buildSectionHeader(String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8, top: 16),
      child: pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
    );
  }

  // Helper function to build a row of details (Label: Value) in the PDF
  static pw.Widget _buildDetailRow(String label, String value, {bool isMultiLine = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: isMultiLine ? pw.CrossAxisAlignment.start : pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }
}