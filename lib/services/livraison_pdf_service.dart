// lib/services/livraison_pdf_service.dart

import 'dart:typed_data';
import 'package:boitex_info_app/models/selection_models.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class LivraisonPdfService {
  // 🎨 "CLEAN TECH" PALETTE (Light, Modern, Professional)
  static const PdfColor _bgSidebar = PdfColor.fromInt(0xFFF8FAFC);    // Very Light Platinum
  static const PdfColor _bgMain = PdfColors.white;
  static const PdfColor _brandPrimary = PdfColor.fromInt(0xFF0F4C81); // Classic Blue (Professional)
  static const PdfColor _brandAccent = PdfColor.fromInt(0xFF38BDF8);  // Sky Blue (Highlights)
  static const PdfColor _textDark = PdfColor.fromInt(0xFF1E293B);     // Slate 800 (Soft Black)
  static const PdfColor _textGrey = PdfColor.fromInt(0xFF64748B);     // Slate 500
  static const PdfColor _divider = PdfColor.fromInt(0xFFE2E8F0);      // Light Grey Border

  Future<Uint8List> generateLivraisonPdf({
    required Map<String, dynamic> livraisonData,
    required List<ProductSelection> products,
    required Map<String, dynamic> clientData,
    required String docId, // ✅ ADDED: Required parameter for Deep Link ID
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

    // Client Info
    final String clientName = (livraisonData['clientName'] ?? '').toUpperCase();
    final String clientAddr = livraisonData['deliveryAddress'] ?? '';
    final String clientPhone = livraisonData['contactPhone'] ?? '';
    final String recipient = livraisonData['recipientName'] ?? '';
    final DateTime deliveryDate = (livraisonData['completedAt'] as dynamic)?.toDate() ?? DateTime.now();
    final String deliveryDateStr = DateFormat('dd/MM/yyyy HH:mm').format(deliveryDate);

    // Legal
    final String rc = clientData['rc'] ?? '—';
    final String nif = clientData['nif'] ?? '—';
    final String art = clientData['art'] ?? '—';

    // 3. Build Page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero, // Full bleed
        build: (context) {
          return pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // =========================
              // 👈 LEFT SIDEBAR (Light & Clean)
              // =========================
              pw.Container(
                width: 200,
                height: PdfPageFormat.a4.height,
                padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 40),
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
                    _buildSidebarText("SARL BOITEX INFO", isBold: true),
                    _buildSidebarText("116 Rue Des Frères Djilali\nBirkhadem, Alger"),

                    pw.SizedBox(height: 30),

                    _buildSidebarLabel("CONTACT"),
                    _buildIconText("Tél: +213 23 56 20 85"),
                    _buildIconText("commercial@boitexinfo.com"),
                    _buildIconText("www.boitexinfo.com"),

                    pw.SizedBox(height: 30),

                    _buildSidebarLabel("MENTIONS LÉGALES"),
                    _buildLegalRow("RC","01B0017926"),
                    _buildLegalRow("NIF","000116001792641"),
                    _buildLegalRow("ART","16124106515"),

                    pw.Spacer(),

                    // QR Code at bottom left
                    pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: _bgMain,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                        border: pw.Border.all(color: _divider),
                      ),
                      child: pw.BarcodeWidget(
                        data: "boitex://livraison/$docId", // ✅ UPDATED: Uses docId parameter
                        barcode: pw.Barcode.qrCode(),
                        width: 60,
                        height: 60,
                        color: _brandPrimary,
                        drawText: false,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text("Scan pour vérifier", style: const pw.TextStyle(color: _textGrey, fontSize: 8)),
                  ],
                ),
              ),

              // =========================
              // 👉 RIGHT CONTENT (Main)
              // =========================
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.fromLTRB(40, 50, 40, 40),
                  color: _bgMain,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Header: Document Type & Date
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text("BON DE LIVRAISON", style: pw.TextStyle(color: _brandAccent, fontSize: 10, letterSpacing: 2, fontWeight: pw.FontWeight.bold)),
                              pw.Text(bonCode, style: pw.TextStyle(color: _brandPrimary, fontSize: 28, fontWeight: pw.FontWeight.bold)),
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

                      pw.SizedBox(height: 40),

                      // Client Section (Clean Design)
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.all(20),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          border: pw.Border.all(color: _divider),
                          boxShadow: const [
                            pw.BoxShadow(color: PdfColors.grey200, blurRadius: 4, spreadRadius: 1),
                          ],
                        ),
                        child: pw.Row(
                          children: [
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text("DESTINATAIRE", style: pw.TextStyle(color: _textGrey, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                  pw.SizedBox(height: 5),
                                  pw.Text(clientName, style: pw.TextStyle(color: _textDark, fontSize: 14, fontWeight: pw.FontWeight.bold)),
                                  if (clientAddr.isNotEmpty) ...[
                                    pw.SizedBox(height: 4),
                                    pw.Text(clientAddr, style: const pw.TextStyle(color: _textDark, fontSize: 10)),
                                  ],
                                  if (clientPhone.isNotEmpty)
                                    pw.Text(clientPhone, style: const pw.TextStyle(color: _textDark, fontSize: 10)),
                                ],
                              ),
                            ),
                            // Small vertical divider
                            pw.Container(width: 1, height: 40, color: _divider, margin: const pw.EdgeInsets.symmetric(horizontal: 20)),

                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                _buildMiniMeta("RC", rc),
                                _buildMiniMeta("NIF", nif),
                                _buildMiniMeta("ART", art),
                              ],
                            )
                          ],
                        ),
                      ),

                      pw.SizedBox(height: 30),

                      // Product Table
                      _buildCleanTable(products),

                      pw.Spacer(),

                      // Footer Area (Totals & Signatures)
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          // Cachet Area
                          pw.Expanded(
                            flex: 1,
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text("CACHET BOITEX INFO", style: pw.TextStyle(color: _textGrey, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                                pw.SizedBox(height: 10),
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
                                  padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 0),
                                  decoration: const pw.BoxDecoration(
                                    border: pw.Border(bottom: pw.BorderSide(color: _divider)),
                                  ),
                                  child: pw.Row(
                                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      pw.Text("TOTAL ARTICLES", style: const pw.TextStyle(color: _textGrey, fontSize: 10)),
                                      pw.Text(
                                          "${products.fold(0, (sum, i) => sum + i.quantity)}",
                                          style: pw.TextStyle(color: _brandPrimary, fontSize: 18, fontWeight: pw.FontWeight.bold)
                                      ),
                                    ],
                                  ),
                                ),
                                pw.SizedBox(height: 20),

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
                                        pw.Center(child: pw.Text("Signature Client", style: const pw.TextStyle(color: _textGrey, fontSize: 9))),
                                    ],
                                  ),
                                ),
                                if (recipient.isNotEmpty) ...[
                                  pw.SizedBox(height: 5),
                                  pw.Text("Reçu par: $recipient", style: pw.TextStyle(color: _textDark, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                  if(signatureBytes != null)
                                    pw.Text("Le: $deliveryDateStr", style: const pw.TextStyle(color: _textGrey, fontSize: 8)),
                                ]
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ----------------------------------------
  // ⚡ SIDEBAR WIDGETS
  // ----------------------------------------

  pw.Widget _buildSidebarLabel(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
          text,
          style: pw.TextStyle(color: _brandAccent, fontSize: 9, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5)
      ),
    );
  }

  pw.Widget _buildSidebarText(String text, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(
          text,
          style: pw.TextStyle(color: _textDark, fontSize: 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)
      ),
    );
  }

  pw.Widget _buildIconText(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(text, style: const pw.TextStyle(color: _textGrey, fontSize: 9)),
    );
  }

  pw.Widget _buildLegalRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(color: _textGrey, fontSize: 8, fontWeight: pw.FontWeight.bold)),
          pw.Text(value, style: const pw.TextStyle(color: _textDark, fontSize: 8)),
        ],
      ),
    );
  }

  // ----------------------------------------
  // ⚡ CONTENT WIDGETS
  // ----------------------------------------

  pw.Widget _buildMiniMeta(String label, String value) {
    return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.RichText(
            text: pw.TextSpan(
                children: [
                  pw.TextSpan(text: "$label: ", style: const pw.TextStyle(color: _textGrey, fontSize: 8)),
                  pw.TextSpan(text: value, style: pw.TextStyle(color: _textDark, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ]
            )
        )
    );
  }

  pw.Widget _buildCleanTable(List<ProductSelection> products) {
    return pw.Table(
      border: null,
      columnWidths: {
        0: const pw.FlexColumnWidth(2), // Ref
        1: const pw.FlexColumnWidth(5), // Desc
        2: const pw.FlexColumnWidth(1), // Qty
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _brandPrimary, width: 1.5)),
          ),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Text("RÉFÉRENCE", style: pw.TextStyle(color: _brandPrimary, fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Text("DÉSIGNATION", style: pw.TextStyle(color: _brandPrimary, fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Text("QTÉ", textAlign: pw.TextAlign.right, style: pw.TextStyle(color: _brandPrimary, fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ),
          ],
        ),

        // Spacer
        pw.TableRow(children: [pw.SizedBox(height: 10), pw.SizedBox(height: 10), pw.SizedBox(height: 10)]),

        // Rows
        ...products.map((item) {
          return pw.TableRow(
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _divider, width: 0.5)),
            ),
            children: [
              // Ref
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 12),
                child: pw.Text(item.partNumber, style: pw.TextStyle(color: _textDark, fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ),
              // Desc + Serials
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 12),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(item.productName, style: const pw.TextStyle(color: _textDark, fontSize: 10)),
                    if (item.serialNumbers.isNotEmpty) ...[
                      pw.SizedBox(height: 6),
                      pw.Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: item.serialNumbers.map((sn) =>
                              pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: pw.BoxDecoration(
                                    color: _bgSidebar,
                                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                                    border: pw.Border.all(color: _divider),
                                  ),
                                  // ✅ Uses Courier for "Code" look, standard font package
                                  child: pw.Text(sn, style: pw.TextStyle(color: _textDark, fontSize: 8, font: pw.Font.courier()))
                              )
                          ).toList()
                      )
                    ]
                  ],
                ),
              ),
              // Qty
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 12),
                alignment: pw.Alignment.topRight,
                child: pw.Text("${item.quantity}", style: pw.TextStyle(color: _brandPrimary, fontSize: 11, fontWeight: pw.FontWeight.bold)),
              ),
            ],
          );
        }).toList(),
      ],
    );
  }

  // ----------------------------------------
  // 📦 HELPERS
  // ----------------------------------------
  Future<pw.MemoryImage> _loadLogo() async {
    final ByteData bytes = await rootBundle.load('assets/images/logo.png');
    return pw.MemoryImage(bytes.buffer.asUint8List());
  }

  Future<pw.MemoryImage> _loadCachet() async {
    try {
      final ByteData bytes = await rootBundle.load('assets/images/cachet.png');
      return pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (e) {
      return _loadLogo(); // Fallback
    }
  }
}