// lib/services/store_qr_pdf_service.dart

import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class StoreQrPdfService {

  /// Generates and prints the QR Code PDF for a specific store including location data
  /// and bilingual (French/Arabic) instructions.
  static Future<void> generateStoreQr(
      String storeName,
      String clientName,
      String storeId,
      String token,
      String? location
      ) async {

    try {
      final pdf = pw.Document();

      // 1. Load Assets
      // Load the App Logo (Ensure this path exists in your assets)
      pw.ImageProvider? logoImage;
      try {
        logoImage = await imageFromAssetBundle('assets/images/logo.png');
      } catch (e) {
        debugPrint("Error loading logo for PDF: $e");
      }

      // Load a font that supports Arabic (Cairo is excellent for bilingual UI)
      final ttf = await PdfGoogleFonts.cairoRegular();
      final ttfBold = await PdfGoogleFonts.cairoBold();

      // 2. Construct the Secure URL
      // MUST match the logic in main.dart
      const String kBaseUrl = "https://app.boitexinfo.com";
      final String secureUrl = "$kBaseUrl/?sid=$storeId&token=$token";

      // 3. Create the PDF Page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  // --- HEADER ---
                  if (logoImage != null)
                    pw.Image(logoImage, width: 120), // Slightly smaller to save space

                  pw.SizedBox(height: 20),

                  pw.Text("SUPPORT TECHNIQUE", style: pw.TextStyle(font: ttfBold, fontSize: 22)),
                  pw.SizedBox(height: 5),
                  pw.Text(clientName.toUpperCase(), style: pw.TextStyle(font: ttf, fontSize: 16, color: PdfColors.grey700)),
                  pw.Text(storeName, style: pw.TextStyle(font: ttfBold, fontSize: 26)),

                  // Location Display
                  if (location != null && location.isNotEmpty) ...[
                    pw.SizedBox(height: 5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text("Localisation: ", style: pw.TextStyle(font: ttfBold, color: PdfColors.grey700)),
                        pw.Text(location, style: pw.TextStyle(font: ttf, color: PdfColors.grey700)),
                      ],
                    ),
                  ],

                  pw.SizedBox(height: 30),

                  // --- QR CODE ---
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: secureUrl,
                    width: 230,
                    height: 230,
                  ),

                  pw.SizedBox(height: 30),

                  // --- BILINGUAL INSTRUCTIONS ---
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: pw.BorderRadius.circular(10),
                    ),
                    child: pw.Column(
                      children: [
                        // Header for Instructions
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                          children: [
                            pw.Text("BESOIN D'UNE INTERVENTION ?", style: pw.TextStyle(font: ttfBold, fontSize: 14)),
                            // ✅ FIXED: textDirection moved to pw.Text parameter
                            pw.Text("هل تحتاج إلى تدخل فني؟",
                                textDirection: pw.TextDirection.rtl,
                                style: pw.TextStyle(font: ttfBold, fontSize: 14)),
                          ],
                        ),
                        pw.Divider(color: PdfColors.grey300),
                        pw.SizedBox(height: 10),

                        // Split Columns: French (Left) vs Arabic (Right)
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            // French Instructions (Left)
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text("1. Scannez ce QR Code avec votre téléphone.", style: pw.TextStyle(font: ttf, fontSize: 10)),
                                  pw.SizedBox(height: 4),
                                  pw.Text("2. Sélectionnez l'équipement en panne.", style: pw.TextStyle(font: ttf, fontSize: 10)),
                                  pw.SizedBox(height: 4),
                                  pw.Text("3. Prenez une photo et envoyez.", style: pw.TextStyle(font: ttf, fontSize: 10)),
                                ],
                              ),
                            ),

                            // Vertical Divider
                            pw.Container(
                              width: 1,
                              height: 50,
                              color: PdfColors.grey300,
                              margin: const pw.EdgeInsets.symmetric(horizontal: 10),
                            ),

                            // Arabic Instructions (Right)
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.end,
                                children: [
                                  // ✅ FIXED: textDirection moved to pw.Text parameter for all 3 lines
                                  pw.Text("1. امسح رمز الاستجابة السريعة (QR)",
                                      textDirection: pw.TextDirection.rtl,
                                      style: pw.TextStyle(font: ttf, fontSize: 10)),
                                  pw.SizedBox(height: 4),
                                  pw.Text("2. حدد الجهاز المعطل",
                                      textDirection: pw.TextDirection.rtl,
                                      style: pw.TextStyle(font: ttf, fontSize: 10)),
                                  pw.SizedBox(height: 4),
                                  pw.Text("3. التقط صورة وأرسل الطلب",
                                      textDirection: pw.TextDirection.rtl,
                                      style: pw.TextStyle(font: ttf, fontSize: 10)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 20),
                  pw.Text("ID Magasin: $storeId", style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey500)),
                ],
              ),
            );
          },
        ),
      );

      // 4. Open Print Preview
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'QR_${storeName.replaceAll(' ', '_')}',
      );

    } catch (e) {
      debugPrint("Error generating QR PDF: $e");
    }
  }
}