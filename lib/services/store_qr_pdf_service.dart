// lib/services/store_qr_pdf_service.dart

import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class StoreQrPdfService {

  /// Generates and prints the QR Code PDF for a specific store including location data,
  /// trilingual instructions, and Boitex Info contact details.
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
      pw.ImageProvider? logoImage;
      try {
        logoImage = await imageFromAssetBundle('assets/images/logo.png');
      } catch (e) {
        debugPrint("Error loading logo for PDF: $e");
      }

      // Fetch the Network Image for the QR Code center (WhatsApp style)
      pw.ImageProvider? qrCenterLogo;
      try {
        qrCenterLogo = await networkImage('https://f003.backblazeb2.com/file/BoitexInfo/Boitex+logo/Icon-192.png');
      } catch (e) {
        debugPrint("Error loading QR center logo: $e");
      }

      // Load fonts supporting Latin and Arabic
      final ttf = await PdfGoogleFonts.cairoRegular();
      final ttfBold = await PdfGoogleFonts.cairoBold();

      // 2. Construct the Secure URL
      const String kBaseUrl = "https://app.boitexinfo.com";
      final String secureUrl = "$kBaseUrl/?sid=$storeId&token=$token";

      // 3. Create the PDF Page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  children: [
                    // --- HEADER ---
                    if (logoImage != null)
                      pw.Image(logoImage, width: 110),

                    pw.SizedBox(height: 10),
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
                          pw.Text("Localisation: ", style: pw.TextStyle(font: ttfBold, color: PdfColors.grey700, fontSize: 12)),
                          pw.Text(location, style: pw.TextStyle(font: ttf, color: PdfColors.grey700, fontSize: 12)),
                        ],
                      ),
                    ],

                    pw.SizedBox(height: 20),

                    // --- QR CODE WITH LOGO OVERLAY ---
                    pw.SizedBox(
                      width: 230,
                      height: 230,
                      child: pw.Stack(
                        alignment: pw.Alignment.center,
                        children: [
                          pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(),
                            data: secureUrl,
                            width: 230,
                            height: 230,
                          ),
                          if (qrCenterLogo != null)
                            pw.Container(
                              padding: const pw.EdgeInsets.all(4),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.white,
                                borderRadius: pw.BorderRadius.circular(8),
                              ),
                              child: pw.Image(qrCenterLogo, width: 45, height: 45),
                            ),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 25),

                    // --- TRILINGUAL INSTRUCTIONS ---
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                        borderRadius: pw.BorderRadius.circular(10),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                            children: [
                              pw.Expanded(child: pw.Text("NEED SUPPORT?", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: ttfBold, fontSize: 11))),
                              pw.Expanded(child: pw.Text("BESOIN D'AIDE ?", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: ttfBold, fontSize: 11))),
                              pw.Expanded(child: pw.Text("محتاج مساعدة تقنية؟", textAlign: pw.TextAlign.center, textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: ttfBold, fontSize: 11))),
                            ],
                          ),
                          pw.Divider(color: PdfColors.grey300),
                          pw.SizedBox(height: 10),
                          pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              // English
                              pw.Expanded(
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text("1. Scan this QR Code.", style: pw.TextStyle(font: ttf, fontSize: 9)),
                                    pw.Text("2. Select the equipment.", style: pw.TextStyle(font: ttf, fontSize: 9)),
                                    pw.Text("3. Fill details & submit.", style: pw.TextStyle(font: ttf, fontSize: 9)),
                                  ],
                                ),
                              ),
                              pw.Container(width: 1, height: 40, color: PdfColors.grey300, margin: const pw.EdgeInsets.symmetric(horizontal: 5)),
                              // French
                              pw.Expanded(
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text("1. Scannez ce QR Code.", style: pw.TextStyle(font: ttf, fontSize: 9)),
                                    pw.Text("2. Sélectionnez l'équipement.", style: pw.TextStyle(font: ttf, fontSize: 9)),
                                    pw.Text("3. Envoyez votre demande.", style: pw.TextStyle(font: ttf, fontSize: 9)),
                                  ],
                                ),
                              ),
                              pw.Container(width: 1, height: 40, color: PdfColors.grey300, margin: const pw.EdgeInsets.symmetric(horizontal: 5)),
                              // Arabic
                              pw.Expanded(
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                                  children: [
                                    pw.Text("1. امسح الكود (QR).", textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: ttf, fontSize: 9)),
                                    pw.Text("2. خيّر الجهاز لي راه خاسر.", textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: ttf, fontSize: 9)),
                                    pw.Text("3. ابعت الطلب نتاعك.", textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: ttf, fontSize: 9)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // --- FOOTER: BOITEX INFO CONTACT DETAILS ---
                pw.Column(
                  children: [
                    pw.Divider(color: PdfColors.grey400, thickness: 1),
                    pw.SizedBox(height: 5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text("ID Magasin: $storeId", style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey600)),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text("Tél: 0560 18 44 64 / 023 56 20 85", style: pw.TextStyle(font: ttfBold, fontSize: 10)),
                            pw.Text("Email: commercial@boitexinfo.com", style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.blue700)),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text("Boitex Info - Solutions Technologiques & Maintenance",
                        style: pw.TextStyle(font: ttf, fontSize: 8, color: PdfColors.grey500, fontStyle: pw.FontStyle.italic)),
                  ],
                ),
              ],
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