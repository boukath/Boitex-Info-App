// lib/services/store_qr_pdf_service.dart

import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class StoreQrPdfService {

  /// Generates and prints the QR Code PDF for a specific store
  static Future<void> generateStoreQr(
      String storeName,
      String clientName,
      String storeId,
      String token
      ) async {
    final pdf = pw.Document();

    // 1. Load the App Logo (Ensure this path exists in your assets)
    final logoImage = await imageFromAssetBundle('assets/images/logo.png');

    // 2. Construct the Secure URL
    // MUST match the logic we added in main.dart
    final String secureUrl = "https://app.boitexinfo.com/?sid=$storeId&token=$token";

    // 3. Create the PDF Page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                // Logo
                pw.Image(logoImage, width: 150),
                pw.SizedBox(height: 40),

                // Title
                pw.Text("SUPPORT TECHNIQUE", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Text(clientName.toUpperCase(), style: const pw.TextStyle(fontSize: 18, color: PdfColors.grey700)),
                pw.Text(storeName, style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold)),

                pw.SizedBox(height: 40),

                // THE QR CODE
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: secureUrl,
                  width: 250,
                  height: 250,
                ),

                pw.SizedBox(height: 40),

                // Instructions
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey),
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Column(children: [
                    pw.Text("BESOIN D'UNE INTERVENTION ?", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 5),
                    pw.Text("1. Scannez ce QR Code avec votre téléphone."),
                    pw.Text("2. Sélectionnez l'équipement en panne."),
                    pw.Text("3. Prenez une photo et envoyez."),
                  ]),
                ),

                pw.SizedBox(height: 20),
                pw.Text("ID Magasin: $storeId", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
              ],
            ),
          );
        },
      ),
    );

    // 4. Open Print Preview
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'QR_$storeName',
    );
  }
}