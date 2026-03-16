// lib/services/livraison_pdf_service.dart

import 'dart:typed_data';
import 'package:boitex_info_app/models/selection_models.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class LivraisonPdfService {
  // 🎨 "CLEAN TECH" PALETTE (Used for Page 1)
  static const PdfColor _bgSidebar = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor _bgMain = PdfColors.white;
  static const PdfColor _brandPrimary = PdfColor.fromInt(0xFF0F4C81);
  static const PdfColor _brandAccent = PdfColor.fromInt(0xFF38BDF8);
  static const PdfColor _textDark = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor _textGrey = PdfColor.fromInt(0xFF64748B);
  static const PdfColor _divider = PdfColor.fromInt(0xFFE2E8F0);

  // 🍏 "APPLE PREMIUM 2026" PALETTE (Used for Warranty Page)
  static const PdfColor _appleDark = PdfColor.fromInt(0xFF1D1D1F);
  static const PdfColor _appleGreyText = PdfColor.fromInt(0xFF86868B);
  static const PdfColor _appleBlue = PdfColor.fromInt(0xFF2997FF);
  static const PdfColor _appleRed = PdfColor.fromInt(0xFFFF3B30);

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
    const double contentMargin = 30.0;
    const double fontSizeTitle = 22.0;
    const double fontSizeBody = 10.0;
    const double fontSizeSmall = 8.0;

    // =========================================================================
    // 📄 PAGE 1: BON DE LIVRAISON (Clean Tech Style)
    // =========================================================================
    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.only(left: sidebarWidth + contentMargin, top: 40, right: 30, bottom: 40),
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
                      // ✅ HUGE LOGO ON PAGE 1
                      pw.Container(
                        height: 120, // <-- DOUBLED HEIGHT (Was 60)
                        width: double.infinity, // Max width available
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                      ),
                      pw.SizedBox(height: 20), // Adjusted spacing slightly so content fits

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
                      pw.SizedBox(height: 10),
                      pw.Text("Page ${context.pageNumber} / ${context.pagesCount}", style: const pw.TextStyle(color: _textGrey, fontSize: 8)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        header: (context) {
          if (context.pageNumber == 1) {
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
            return pw.Column(
                children: [
                  pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text("$bonCode - (Suite)", style: pw.TextStyle(color: _textGrey, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.Text(storeName.isNotEmpty ? "$clientName - $storeName" : clientName, style: pw.TextStyle(color: _textGrey, fontSize: 10)),
                      ]
                  ),
                  pw.Divider(color: _divider),
                  pw.SizedBox(height: 10),
                ]
            );
          }
        },
        build: (context) => [
          _buildCleanTable(products, fontSizeBody: fontSizeBody, fontSizeSmall: fontSizeSmall, padding: 10),
          pw.SizedBox(height: 20),
          pw.Container(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
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
                pw.Expanded(
                  flex: 1,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 5),
                        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _divider))),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text("TOTAL ARTICLES", style: const pw.TextStyle(color: _textGrey, fontSize: 10)),
                            pw.Text("${products.fold(0, (sum, i) => sum + i.quantity)}", style: pw.TextStyle(color: _brandPrimary, fontSize: 14, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 10),
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

    // =========================================================================
    // 🌟 PAGE 2: PREMIUM IOS 26 GLASS ANIMATION WARRANTY PAGE
    // =========================================================================
    final bool hasSerializedProducts = products.any((p) => p.serialNumbers.isNotEmpty);

    if (hasSerializedProducts) {
      final DateTime startDate = deliveryDate;
      final DateTime endDate = DateTime(startDate.year + 1, startDate.month, startDate.day);

      pdf.addPage(
          pw.Page(
              pageFormat: PdfPageFormat.a4,
              margin: pw.EdgeInsets.zero, // Zero margin to allow full background bleed
              build: (context) {
                return pw.Container(
                    width: PdfPageFormat.a4.width,
                    height: PdfPageFormat.a4.height,
                    // ✨ APPLE STYLE MAC-OS INSPIRED BACKGROUND GRADIENT
                    decoration: pw.BoxDecoration(
                        gradient: pw.LinearGradient(
                          colors: [
                            PdfColor.fromHex('#F5F7FA'), // Light silver
                            PdfColor.fromHex('#C3CFE2'), // Deep elegant blue-grey
                          ],
                          begin: pw.Alignment.topLeft,
                          end: pw.Alignment.bottomRight,
                        )
                    ),
                    child: pw.Stack(
                        children: [
                          // 🌟 FULL PAGE WATERMARK BACKGROUND LOGO
                          pw.Positioned.fill(
                              child: pw.Center(
                                  child: pw.Opacity(
                                      opacity: 0.08, // Increased slightly for a full-page background
                                      child: pw.Padding(
                                        padding: const pw.EdgeInsets.all(40),
                                        // Uses contain to ensure it is huge but doesn't get chopped at the edges
                                        child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                                      )
                                  )
                              )
                          ),

                          // 🌟 MAIN GLASS CONTENT CARD
                          pw.Center(
                            child: pw.Container(
                              width: PdfPageFormat.a4.width * 0.88, // Slightly wider to fit content perfectly
                              padding: const pw.EdgeInsets.all(35),
                              // ✨ PREMIUM GLASS FLOATING CARD EFFECT
                              decoration: pw.BoxDecoration(
                                color: const PdfColor(1, 1, 1, 0.95), // 95% opacity white
                                borderRadius: pw.BorderRadius.circular(24),
                                border: pw.Border.all(color: PdfColors.white, width: 2), // White highlight
                                boxShadow: [
                                  pw.BoxShadow(
                                    color: const PdfColor(0, 0, 0, 0.05),
                                    blurRadius: 30,
                                    spreadRadius: 10,
                                    offset: const PdfPoint(0, 20),
                                  ),
                                  pw.BoxShadow(
                                    color: const PdfColor(0, 0, 0, 0.08),
                                    blurRadius: 15,
                                    offset: const PdfPoint(0, 10),
                                  ),
                                ],
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                mainAxisSize: pw.MainAxisSize.min,
                                children: [
                                  // 🍏 APPLE-STYLE HEADER
                                  pw.Center(
                                    child: pw.Column(
                                      children: [
                                        pw.Text(
                                          "Certificat de Garantie",
                                          style: pw.TextStyle(color: _appleDark, fontSize: 30, fontWeight: pw.FontWeight.bold, letterSpacing: -0.5),
                                        ),
                                        pw.SizedBox(height: 15),
                                        pw.Container(
                                          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          decoration: pw.BoxDecoration(
                                            color: const PdfColor.fromInt(0x1A2997FF), // 10% opacity Apple Blue
                                            borderRadius: pw.BorderRadius.circular(20),
                                          ),
                                          child: pw.Text(
                                            "1 AN DE GARANTIE CONSTRUCTEUR",
                                            style: pw.TextStyle(color: _appleBlue, fontSize: 10, fontWeight: pw.FontWeight.bold, letterSpacing: 1),
                                          ),
                                        ),
                                        pw.SizedBox(height: 12),
                                        pw.Text(
                                          "Valable du ${DateFormat('dd MMMM yyyy', 'fr_FR').format(startDate)} au ${DateFormat('dd MMMM yyyy', 'fr_FR').format(endDate)}",
                                          style: pw.TextStyle(color: _appleGreyText, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),

                                  pw.SizedBox(height: 25),
                                  pw.Divider(color: _divider, thickness: 1),
                                  pw.SizedBox(height: 20),

                                  // 💎 SECTION 1 (Hardware focus)
                                  pw.Text("Couverture Matérielle", style: pw.TextStyle(color: _appleDark, fontSize: 16, fontWeight: pw.FontWeight.bold)),
                                  pw.SizedBox(height: 8),
                                  pw.Text(
                                    "Boitex Info garantit le matériel livré contre tout vice de fabrication ou défaut d'usine. En cas de dysfonctionnement couvert par cette garantie, le matériel devra être retourné à notre centre technique (SAV) pour diagnostic et réparation ou remplacement.",
                                    style: pw.TextStyle(color: _appleGreyText, fontSize: 11, lineSpacing: 4),
                                  ),

                                  pw.SizedBox(height: 20),

                                  // 💎 SECTION 2
                                  pw.Text("Exclusions de Garantie", style: pw.TextStyle(color: _appleDark, fontSize: 16, fontWeight: pw.FontWeight.bold)),
                                  pw.SizedBox(height: 12),
                                  _buildPremiumExclusion("Problèmes Électriques", "Surtensions, foudre, ou absence d'un onduleur (UPS) adéquat."),
                                  _buildPremiumExclusion("Dégâts Environnementaux", "Dégâts des eaux, humidité extrême, ou exposition directe à la chaleur."),
                                  _buildPremiumExclusion("Casse & Mauvaise Utilisation", "Dommages physiques, chocs, chutes, ou négligence sur site."),
                                  _buildPremiumExclusion("Intervention Tiers", "Réparation ou modification par une personne non agréée par Boitex Info."),

                                  pw.SizedBox(height: 15),

                                  // 💎 SECTION 3 (Hardware focus)
                                  pw.Container(
                                      padding: const pw.EdgeInsets.all(15),
                                      decoration: pw.BoxDecoration(
                                        color: _bgSidebar,
                                        borderRadius: pw.BorderRadius.circular(16),
                                      ),
                                      child: pw.Column(
                                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                                          children: [
                                            pw.Text("Recommandations d'utilisation", style: pw.TextStyle(color: _appleDark, fontSize: 14, fontWeight: pw.FontWeight.bold)),
                                            pw.SizedBox(height: 6),
                                            pw.Text(
                                              "Pour assurer la longévité de votre matériel, l'utilisation d'un onduleur (UPS) est strictement requise. Veillez également à utiliser les équipements dans un environnement bien aéré et conforme aux spécifications du constructeur.",
                                              style: pw.TextStyle(color: _appleGreyText, fontSize: 10, lineSpacing: 3),
                                            ),
                                          ]
                                      )
                                  ),

                                  pw.SizedBox(height: 15),
                                  pw.Divider(color: _divider, thickness: 1),
                                  pw.SizedBox(height: 15),

                                  // 🖋️ CACHET ET SIGNATURE AT THE BOTTOM (Delivery focus)
                                  pw.Row(
                                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                                      children: [
                                        pw.Column(
                                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                                            children: [
                                              pw.Text("Ce document officiel", style: pw.TextStyle(color: _appleDark, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                              pw.Text("certifie l'authenticité du matériel livré.", style: pw.TextStyle(color: _appleGreyText, fontSize: 8)),
                                              pw.SizedBox(height: 10),
                                              pw.Text("Réf: $docId", style: const pw.TextStyle(color: _textGrey, fontSize: 6)),
                                            ]
                                        ),
                                        pw.Column(
                                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                                            children: [
                                              pw.Text("DIRECTION GÉNÉRALE", style: pw.TextStyle(color: _appleDark, fontSize: 9, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
                                              pw.SizedBox(height: 5),
                                              pw.Container(
                                                height: 60,
                                                child: pw.Image(cachetImage, fit: pw.BoxFit.contain),
                                              ),
                                            ]
                                        ),
                                      ]
                                  ),

                                ],
                              ),
                            ),
                          ),
                        ]
                    )
                );
              }
          )
      );
    }

    return pdf.save();
  }

  // ----------------------------------------
  // ⚡ SIDEBAR WIDGETS
  // ----------------------------------------
  pw.Widget _buildSidebarLabel(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(text, style: pw.TextStyle(color: _brandAccent, fontSize: 8, fontWeight: pw.FontWeight.bold, letterSpacing: 1.2)),
    );
  }

  pw.Widget _buildSidebarText(String text, {double fontSize = 10, bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(text, style: pw.TextStyle(color: _textDark, fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
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
        child: pw.RichText(
            text: pw.TextSpan(
                children: [
                  pw.TextSpan(text: "$label : ", style: pw.TextStyle(color: _textGrey, fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
                  pw.TextSpan(text: value, style: pw.TextStyle(color: _textDark, fontSize: fontSize)),
                ]
            )
        )
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

  // ✨ NEW: Apple Premium Exclusion Bullet Point
  pw.Widget _buildPremiumExclusion(String title, String text) {
    return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 12),
        child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 4, right: 12),
                width: 6,
                height: 6,
                decoration: const pw.BoxDecoration(
                  color: _appleRed,
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.Expanded(
                  child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(title, style: pw.TextStyle(color: _appleDark, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 2),
                        pw.Text(text, style: pw.TextStyle(color: _appleGreyText, fontSize: 10)),
                      ]
                  )
              )
            ]
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
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(4),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _brandPrimary, width: 1.5)),
          ),
          children: [
            pw.Padding(padding: const pw.EdgeInsets.only(bottom: 4), child: pw.Text("RÉFÉRENCE", style: pw.TextStyle(color: _brandPrimary, fontSize: fontSizeSmall, fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.only(bottom: 4), child: pw.Text("DÉSIGNATION", style: pw.TextStyle(color: _brandPrimary, fontSize: fontSizeSmall, fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.only(bottom: 4), child: pw.Text("CDE", textAlign: pw.TextAlign.center, style: pw.TextStyle(color: _brandPrimary, fontSize: fontSizeSmall, fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.only(bottom: 4), child: pw.Text("LIV", textAlign: pw.TextAlign.right, style: pw.TextStyle(color: _brandPrimary, fontSize: fontSizeSmall, fontWeight: pw.FontWeight.bold))),
          ],
        ),
        ...products.map((item) {
          final int delivered = item.quantity;
          final int ordered = delivered;

          return pw.TableRow(
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _divider, width: 0.5)),
            ),
            children: [
              pw.Container(
                padding: pw.EdgeInsets.symmetric(vertical: padding),
                child: pw.Text(item.partNumber, style: pw.TextStyle(color: _textDark, fontSize: fontSizeBody, fontWeight: pw.FontWeight.bold)),
              ),
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
              pw.Container(
                padding: pw.EdgeInsets.symmetric(vertical: padding),
                alignment: pw.Alignment.topCenter,
                child: pw.Text("$ordered", style: const pw.TextStyle(color: _textGrey, fontSize: 10)),
              ),
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