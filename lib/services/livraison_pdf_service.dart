// lib/services/livraison_pdf_service.dart

import 'dart:typed_data';
import 'package:boitex_info_app/models/selection_models.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class LivraisonPdfService {
  // 🎨 "CLEAN TECH" PALETTE
  static const PdfColor _bgSidebar = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor _bgMain = PdfColors.white;
  static const PdfColor _brandPrimary = PdfColor.fromInt(0xFF0F4C81);
  static const PdfColor _brandAccent = PdfColor.fromInt(0xFF38BDF8);
  static const PdfColor _textDark = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor _textGrey = PdfColor.fromInt(0xFF64748B);
  static const PdfColor _divider = PdfColor.fromInt(0xFFE2E8F0);

  Future<Uint8List> generateLivraisonPdf({
    required Map<String, dynamic> livraisonData,
    required List<ProductSelection> products,
    required Map<String, dynamic> clientData,
    required String docId,
    Uint8List? signatureBytes,
  }) async {
    final pdf = pw.Document();

    // 1. Load Assets
    final logoImage = await _loadLogo();
    final cachetImage = await _loadCachet();

    // 2. Prepare Data
    final String bonCode = livraisonData['bonLivraisonCode'] ?? 'DRAFT';
    final DateTime date = (livraisonData['createdAt'] as dynamic)?.toDate() ?? DateTime.now();
    final String dateStr = DateFormat('dd MMM yyyy').format(date).toUpperCase();

    final String clientName = (livraisonData['clientName'] ?? '').toUpperCase();
    // ✅ ADDED: Extract the store name safely
    final String storeName = (livraisonData['storeName'] ?? '').toUpperCase();

    final String clientAddr = livraisonData['deliveryAddress'] ?? '';
    final String clientPhone = livraisonData['contactPhone'] ?? '';
    final String recipient = livraisonData['recipientName'] ?? '';
    final DateTime deliveryDate = (livraisonData['completedAt'] as dynamic)?.toDate() ?? DateTime.now();
    final String deliveryDateStr = DateFormat('dd/MM/yyyy HH:mm').format(deliveryDate);

    final String rc = clientData['rc'] ?? '—';
    final String nif = clientData['nif'] ?? '—';
    final String art = clientData['art'] ?? '—';

    // 3. Standard Layout Constants
    const double sidebarWidth = 200.0;
    const double contentMargin = 30.0; // Margin between sidebar and content
    const double fontSizeTitle = 22.0;
    const double fontSizeBody = 10.0;
    const double fontSizeSmall = 8.0;

    // 4. Build Multi-Page Document
    pdf.addPage(
      pw.MultiPage(
        // 🎨 THEME: Draws the persistent Sidebar & handles margins
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.only(
              left: sidebarWidth + contentMargin,
              top: 40,
              right: 30,
              bottom: 40
          ),
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Row(
              children: [
                pw.Container(
                  width: sidebarWidth,
                  height: PdfPageFormat.a4.height,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                  decoration: const pw.BoxDecoration(
                    color: _bgSidebar,
                    border: pw.Border(right: pw.BorderSide(color: _divider, width: 1)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Brand
                      pw.Container(
                        height: 60,
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                      ),
                      pw.SizedBox(height: 40),

                      // Sender Info
                      _buildSidebarLabel("ÉMETTEUR"),
                      _buildSidebarText("SARL BOITEX INFO", fontSize: fontSizeBody, isBold: true),
                      _buildSidebarText("116 Rue Des Frères Djilali\nBirkhadem, Alger", fontSize: fontSizeBody),

                      pw.SizedBox(height: 40),

                      _buildSidebarLabel("CONTACT"),
                      _buildIconText("Tél: +213 23 56 20 85", fontSize: fontSizeSmall),
                      _buildIconText("commercial@boitexinfo.com", fontSize: fontSizeSmall),
                      _buildIconText("www.boitexinfo.com", fontSize: fontSizeSmall),

                      pw.SizedBox(height: 40),

                      _buildSidebarLabel("MENTIONS LÉGALES"),
                      _buildLegalRow("RC", "01B0017926", fontSize: fontSizeSmall),
                      _buildLegalRow("NIF", "000116001792641", fontSize: fontSizeSmall),
                      _buildLegalRow("ART", "16124106515", fontSize: fontSizeSmall),

                      pw.Spacer(),

                      // QR Code
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          color: _bgMain,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                          border: pw.Border.all(color: _divider),
                        ),
                        child: pw.BarcodeWidget(
                          data: "boitex://livraison/$docId",
                          barcode: pw.Barcode.qrCode(),
                          width: 60,
                          height: 60,
                          color: _brandPrimary,
                          drawText: false,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text("Scan pour vérifier", style: const pw.TextStyle(color: _textGrey, fontSize: 8)),

                      // Page Number in Sidebar
                      pw.SizedBox(height: 10),
                      pw.Text(
                          "Page ${context.pageNumber} / ${context.pagesCount}",
                          style: const pw.TextStyle(color: _textGrey, fontSize: 8)
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // 🧠 HEADER LOGIC: Different header for Page 1 vs Page 2+
        header: (context) {
          if (context.pageNumber == 1) {
            // --- FULL HEADER (Page 1) ---
            return pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("BON DE LIVRAISON", style: pw.TextStyle(color: _brandAccent, fontSize: 10, letterSpacing: 2, fontWeight: pw.FontWeight.bold)),
                          pw.Text(bonCode, style: pw.TextStyle(color: _brandPrimary, fontSize: fontSizeTitle, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text("DATE D'ÉMISSION", style: pw.TextStyle(color: _textGrey, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          pw.Text(dateStr, style: pw.TextStyle(color: _textDark, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 25),
                  // Client Section
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(15),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      border: pw.Border.all(color: _divider),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text("DESTINATAIRE", style: pw.TextStyle(color: _textGrey, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 4),
                              pw.Text(clientName, style: pw.TextStyle(color: _textDark, fontSize: 12, fontWeight: pw.FontWeight.bold)),

                              // ✅ ADDED: Conditionally display store name on Page 1
                              if (storeName.isNotEmpty) ...[
                                pw.SizedBox(height: 2),
                                pw.Text(storeName, style: pw.TextStyle(color: _brandPrimary, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                              ],

                              if (clientAddr.isNotEmpty) ...[
                                pw.SizedBox(height: 2),
                                pw.Text(clientAddr, style: pw.TextStyle(color: _textDark, fontSize: 10)),
                              ],
                              if (clientPhone.isNotEmpty)
                                pw.Text(clientPhone, style: pw.TextStyle(color: _textDark, fontSize: 10)),
                            ],
                          ),
                        ),
                        pw.Container(width: 1, height: 30, color: _divider, margin: const pw.EdgeInsets.symmetric(horizontal: 15)),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildMiniMeta("RC", rc, fontSizeBody),
                            _buildMiniMeta("NIF", nif, fontSizeBody),
                            _buildMiniMeta("ART", art, fontSizeBody),
                          ],
                        )
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 30),
                ]
            );
          } else {
            // --- GHOST HEADER (Page 2+) ---
            return pw.Column(
                children: [
                  pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text("$bonCode - (Suite)", style: pw.TextStyle(color: _textGrey, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        // ✅ MODIFIED: Display Client Name + Store Name on Page 2+
                        pw.Text(
                            storeName.isNotEmpty ? "$clientName - $storeName" : clientName,
                            style: pw.TextStyle(color: _textGrey, fontSize: 10)
                        ),
                      ]
                  ),
                  pw.Divider(color: _divider),
                  pw.SizedBox(height: 10),
                ]
            );
          }
        },

        // 🏗️ MAIN CONTENT
        build: (context) => [
          // The Table
          _buildCleanTable(
              products,
              fontSizeBody: fontSizeBody,
              fontSizeSmall: fontSizeSmall,
              padding: 10
          ),

          pw.SizedBox(height: 20),

          // 🛡️ SAFETY 2: Atomic Footer Block
          pw.Container(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                // Cachet Area
                pw.Expanded(
                  flex: 1,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("CACHET BOITEX INFO", style: pw.TextStyle(color: _textGrey, fontSize: fontSizeSmall, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 5),
                      pw.Container(
                        height: 60,
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Image(cachetImage, fit: pw.BoxFit.contain),
                      ),
                    ],
                  ),
                ),
                // Totals & Signature
                pw.Expanded(
                  flex: 1,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      // Total Box
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 5),
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(bottom: pw.BorderSide(color: _divider)),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text("TOTAL ARTICLES", style: const pw.TextStyle(color: _textGrey, fontSize: 10)),
                            pw.Text(
                                "${products.fold(0, (sum, i) => sum + i.quantity)}",
                                style: pw.TextStyle(color: _brandPrimary, fontSize: 14, fontWeight: pw.FontWeight.bold)
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 10),

                      // Signature Box
                      pw.Container(
                        height: 80,
                        width: double.infinity,
                        decoration: pw.BoxDecoration(
                          color: _bgSidebar,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          border: pw.Border.all(color: _divider),
                        ),
                        child: pw.Stack(
                          children: [
                            if (signatureBytes != null)
                              pw.Center(child: pw.Image(pw.MemoryImage(signatureBytes), fit: pw.BoxFit.contain))
                            else
                              pw.Center(child: pw.Text("Signature Client", style: const pw.TextStyle(color: _textGrey, fontSize: 8))),
                          ],
                        ),
                      ),
                      if (recipient.isNotEmpty) ...[
                        pw.SizedBox(height: 5),
                        pw.Text("Reçu par: $recipient", style: const pw.TextStyle(color: _textDark, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        if(signatureBytes != null)
                          pw.Text("Le: $deliveryDateStr", style: const pw.TextStyle(color: _textGrey, fontSize: 6)),
                      ]
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // ----------------------------------------
  // ⚡ SIDEBAR WIDGETS
  // ----------------------------------------

  pw.Widget _buildSidebarLabel(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
          text,
          style: pw.TextStyle(color: _brandAccent, fontSize: 8, fontWeight: pw.FontWeight.bold, letterSpacing: 1.2)
      ),
    );
  }

  pw.Widget _buildSidebarText(String text, {double fontSize = 10, bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(
          text,
          style: pw.TextStyle(color: _textDark, fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)
      ),
    );
  }

  pw.Widget _buildIconText(String text, {double fontSize = 9}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(text, style: pw.TextStyle(color: _textGrey, fontSize: fontSize)),
    );
  }

  pw.Widget _buildLegalRow(String label, String value, {double fontSize = 8}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(color: _textGrey, fontSize: 8, fontWeight: pw.FontWeight.bold)),
          pw.Text(value, style: const pw.TextStyle(color: _textDark, fontSize: 8)),
        ],
      ),
    );
  }

  // ----------------------------------------
  // ⚡ CONTENT WIDGETS
  // ----------------------------------------

  pw.Widget _buildMiniMeta(String label, String value, double fontSize) {
    return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.RichText(
            text: pw.TextSpan(
                children: [
                  pw.TextSpan(text: "$label: ", style: const pw.TextStyle(color: _textGrey, fontSize: 8)),
                  pw.TextSpan(text: value, style: const pw.TextStyle(color: _textDark, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ]
            )
        )
    );
  }

  // ✅ UPDATED TABLE FOR MULTIPAGE
  pw.Widget _buildCleanTable(List<ProductSelection> products, {
    required double fontSizeBody,
    required double fontSizeSmall,
    required double padding,
  }) {
    return pw.Table(
      border: null,
      columnWidths: {
        0: const pw.FlexColumnWidth(2), // Ref
        1: const pw.FlexColumnWidth(4), // Desc
        2: const pw.FlexColumnWidth(1), // Cde
        3: const pw.FlexColumnWidth(1), // Liv
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _brandPrimary, width: 1.5)),
          ),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text("RÉFÉRENCE", style: pw.TextStyle(color: _brandPrimary, fontSize: fontSizeSmall, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text("DÉSIGNATION", style: pw.TextStyle(color: _brandPrimary, fontSize: fontSizeSmall, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text("CDE", textAlign: pw.TextAlign.center, style: pw.TextStyle(color: _brandPrimary, fontSize: fontSizeSmall, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text("LIV", textAlign: pw.TextAlign.right, style: pw.TextStyle(color: _brandPrimary, fontSize: fontSizeSmall, fontWeight: pw.FontWeight.bold)),
            ),
          ],
        ),

        // Rows
        ...products.map((item) {
          final int delivered = item.quantity;
          final int ordered = delivered;

          return pw.TableRow(
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _divider, width: 0.5)),
            ),
            children: [
              // Ref
              pw.Container(
                padding: pw.EdgeInsets.symmetric(vertical: padding),
                child: pw.Text(item.partNumber, style: pw.TextStyle(color: _textDark, fontSize: fontSizeBody, fontWeight: pw.FontWeight.bold)),
              ),
              // Desc + Serials
              pw.Container(
                padding: pw.EdgeInsets.symmetric(vertical: padding),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(item.productName, style: pw.TextStyle(color: _textDark, fontSize: fontSizeBody)),
                    if (item.serialNumbers.isNotEmpty) ...[
                      pw.SizedBox(height: padding / 2),
                      pw.Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: item.serialNumbers.map((sn) =>
                              pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: pw.BoxDecoration(
                                    color: _bgSidebar,
                                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                                    border: pw.Border.all(color: _divider),
                                  ),
                                  child: pw.Text(sn, style: pw.TextStyle(color: _textDark, fontSize: 8, font: pw.Font.courier()))
                              )
                          ).toList()
                      )
                    ]
                  ],
                ),
              ),
              // Qty Ordered (CDE)
              pw.Container(
                padding: pw.EdgeInsets.symmetric(vertical: padding),
                alignment: pw.Alignment.topCenter,
                child: pw.Text("$ordered", style: const pw.TextStyle(color: _textGrey, fontSize: 10)),
              ),
              // Qty Delivered (LIV)
              pw.Container(
                padding: pw.EdgeInsets.symmetric(vertical: padding),
                alignment: pw.Alignment.topRight,
                child: pw.Text("$delivered", style: pw.TextStyle(color: _brandPrimary, fontSize: fontSizeBody + 1, fontWeight: pw.FontWeight.bold)),
              ),
            ],
          );
        }).toList(),
      ],
    );
  }

  Future<pw.MemoryImage> _loadLogo() async {
    final ByteData bytes = await rootBundle.load('assets/images/logo.png');
    return pw.MemoryImage(bytes.buffer.asUint8List());
  }

  Future<pw.MemoryImage> _loadCachet() async {
    try {
      final ByteData bytes = await rootBundle.load('assets/images/cachet.png');
      return pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (e) {
      return _loadLogo();
    }
  }
}