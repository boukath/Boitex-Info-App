// lib/services/store_pdf_export_service.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class StorePdfExportService {
  static const PdfColor primaryColor = PdfColor.fromInt(0xFF667EEA);
  static const PdfColor secondaryColor = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor lightGray = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor textGray = PdfColor.fromInt(0xFF475569);

  static Future<void> generateAndShareStoreDashboard({
    required BuildContext context,
    required String clientId,
    required String storeId,
    required String storeName,
    String? logoUrl,
  }) async {
    // 1. Show Loading Indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF667EEA)),
                SizedBox(height: 16),
                Text("Génération du rapport Premium...", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // 2. Fetch All Data
      final storeDoc = await FirebaseFirestore.instance.collection('clients').doc(clientId).collection('stores').doc(storeId).get();
      final storeData = storeDoc.data() ?? {};
      final address = storeData['adresse'] ?? storeData['address'] ?? 'Adresse non renseignée';

      final equipmentDocs = await FirebaseFirestore.instance.collection('clients').doc(clientId).collection('stores').doc(storeId).collection('materiel_installe').get();
      final contacts = await _fetchContacts(storeId);
      final history = await _fetchHistory(storeId);

      // 3. Download Logo if available
      pw.ImageProvider? logoImage;
      if (logoUrl != null && logoUrl.isNotEmpty) {
        try {
          logoImage = await networkImage(logoUrl);
        } catch (_) {}
      }

      // 4. Create the PDF Document
      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: await PdfGoogleFonts.robotoRegular(),
          bold: await PdfGoogleFonts.robotoBold(),
          italic: await PdfGoogleFonts.robotoItalic(),
        ),
      );

      // --- PAGE 1: PREMIUM COVER PAGE ---
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.Container(
              decoration: const pw.BoxDecoration(
                gradient: pw.LinearGradient(
                  colors: [PdfColor.fromInt(0xFF667EEA), PdfColor.fromInt(0xFF764BA2)],
                  begin: pw.Alignment.topLeft,
                  end: pw.Alignment.bottomRight,
                ),
              ),
              child: pw.Center(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    if (logoImage != null)
                      pw.Container(
                        height: 150,
                        width: 150,
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          color: PdfColors.white,
                          image: pw.DecorationImage(image: logoImage, fit: pw.BoxFit.cover),
                        ),
                      )
                    else
                      pw.Container(
                        height: 120,
                        width: 120,
                        decoration: const pw.BoxDecoration(shape: pw.BoxShape.circle, color: PdfColors.white),
                        child: pw.Center(child: pw.Text(storeName[0].toUpperCase(), style: pw.TextStyle(fontSize: 60, color: primaryColor, fontWeight: pw.FontWeight.bold))),
                      ),
                    pw.SizedBox(height: 40),
                    pw.Text("DOSSIER SITE COMPLET", style: pw.TextStyle(fontSize: 24, color: PdfColors.white, letterSpacing: 2, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 20),
                    pw.Text(storeName.toUpperCase(), style: pw.TextStyle(fontSize: 42, color: PdfColors.white, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                    pw.SizedBox(height: 20),
                    pw.Text(address, style: const pw.TextStyle(fontSize: 16, color: PdfColors.white)),
                    pw.SizedBox(height: 60),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      // ✅ FIXED: Using PdfColor(1, 1, 1, 0.2) instead of PdfColors.white.withOpacity(0.2)
                      decoration: const pw.BoxDecoration(color: PdfColor(1.0, 1.0, 1.0, 0.2), borderRadius: pw.BorderRadius.all(pw.Radius.circular(30))),
                      child: pw.Text("Généré le ${DateFormat('dd MMMM yyyy à HH:mm').format(DateTime.now())}", style: const pw.TextStyle(color: PdfColors.white, fontSize: 14)),
                    )
                  ],
                ),
              ),
            );
          },
        ),
      );

      // --- PAGE 2+: DASHBOARD & DATA (MultiPage) ---
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => _buildHeader(storeName, logoImage),
          footer: (context) => _buildFooter(context),
          build: (pw.Context context) {
            return [
              // 1. KPI DASHBOARD
              pw.Text("Tableau de Bord", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: secondaryColor)),
              pw.SizedBox(height: 16),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildKpiBox("Équipements", equipmentDocs.docs.length.toString(), PdfColors.blueAccent),
                  _buildKpiBox("Interventions", history.where((h) => h['type'] == 'Intervention').length.toString(), PdfColors.orange),
                  _buildKpiBox("Contacts", contacts.length.toString(), PdfColors.green),
                ],
              ),
              pw.SizedBox(height: 32),

              // 2. CONTACTS SECTION
              pw.Text("Répertoire & Contacts", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: secondaryColor)),
              pw.SizedBox(height: 12),
              if (contacts.isEmpty)
                pw.Text("Aucun contact enregistré.", style: const pw.TextStyle(color: PdfColors.grey))
              else
                pw.Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: contacts.map((c) => pw.Container(
                    width: 230,
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: lightGray,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(c['name']!, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: secondaryColor)),
                        pw.SizedBox(height: 4),
                        pw.Text("Tél: ${c['phone']}", style: const pw.TextStyle(fontSize: 12)),
                        pw.Text("Email: ${c['email']}", style: const pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                  )).toList(),
                ),
              pw.SizedBox(height: 32),

              // 3. EQUIPMENT SECTION
              pw.Text("Parc Installé (${equipmentDocs.docs.length})", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: secondaryColor)),
              pw.SizedBox(height: 12),
              _buildEquipmentTable(equipmentDocs.docs),
              pw.SizedBox(height: 32),

              // 4. HISTORY TIMELINE SECTION
              pw.Text("Historique des Opérations (${history.length})", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: secondaryColor)),
              pw.SizedBox(height: 12),
              ...history.map((h) => _buildHistoryRow(h)).toList(),
            ];
          },
        ),
      );

      // Close loading dialog
      Navigator.pop(context);

      // 5. Share / Save the PDF
      final Uint8List pdfBytes = await pdf.save();
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'Dossier_Site_${storeName.replaceAll(' ', '_')}.pdf',
      );

    } catch (e) {
      Navigator.pop(context); // close dialog
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur lors de la génération: $e")));
    }
  }

  // --- PDF WIDGET BUILDERS ---

  static pw.Widget _buildHeader(String storeName, pw.ImageProvider? logo) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 24),
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 1))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text("Rapport d'Activité - $storeName", style: pw.TextStyle(color: primaryColor, fontWeight: pw.FontWeight.bold, fontSize: 12)),
          if (logo != null) pw.Container(height: 30, width: 30, child: pw.Image(logo, fit: pw.BoxFit.contain)),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 24),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 1))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text("Généré par Boitex Info App", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
          pw.Text("Page ${context.pageNumber} / ${context.pagesCount}", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
        ],
      ),
    );
  }

  static pw.Widget _buildKpiBox(String title, String value, PdfColor color) {
    return pw.Container(
      width: 150,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: lightGray,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
        // ✅ FIXED: Directly passing red, green, blue values to set 0.5 opacity manually
        border: pw.Border.all(color: PdfColor(color.red, color.green, color.blue, 0.5), width: 2),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(value, style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: color)),
          pw.SizedBox(height: 4),
          pw.Text(title, style: pw.TextStyle(fontSize: 12, color: secondaryColor, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _buildEquipmentTable(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return pw.Text("Aucun équipement.", style: const pw.TextStyle(color: PdfColors.grey));

    final tableHeaders = ['Nom / Produit', 'N° Série', 'Date Install.', 'Statut'];
    final tableData = docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final installDate = data['installDate'] as Timestamp?;
      return [
        data['name'] ?? data['nom'] ?? 'Inconnu',
        data['serialNumber'] ?? 'N/A',
        installDate != null ? DateFormat('dd/MM/yyyy').format(installDate.toDate()) : '-',
        data['status'] ?? 'Actif'
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: tableHeaders,
      data: tableData,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: primaryColor),
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200))),
      cellPadding: const pw.EdgeInsets.all(8),
      cellStyle: const pw.TextStyle(fontSize: 11),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
    );
  }

  static pw.Widget _buildHistoryRow(Map<String, dynamic> item) {
    final dateTs = item['date'] as Timestamp?;
    final dateStr = dateTs != null ? DateFormat('dd/MM/yyyy').format(dateTs.toDate()) : '-';
    PdfColor typeColor = primaryColor;

    if (item['type'] == 'Livraison') typeColor = PdfColors.green;
    if (item['type'] == 'SAV') typeColor = PdfColors.orange;
    if (item['type'] == 'Installation') typeColor = PdfColors.teal;

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 80,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(dateStr, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: secondaryColor)),
                pw.SizedBox(height: 4),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  // ✅ FIXED: Passing red, green, blue values for 0.2 opacity manually
                  decoration: pw.BoxDecoration(color: PdfColor(typeColor.red, typeColor.green, typeColor.blue, 0.2), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
                  child: pw.Text(item['type'], style: pw.TextStyle(fontSize: 9, color: typeColor, fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(item['code'] ?? '-', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                pw.SizedBox(height: 4),
                pw.Text(item['primaryDesc'] ?? 'Aucun détail fourni', style: const pw.TextStyle(fontSize: 11, color: textGray)),
                if (item['technicians'] != null && (item['technicians'] as List).isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text("Intervenants: ${(item['technicians'] as List).join(', ')}", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic)),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- DATA FETCHING HELPERS (Mirrored from your UI) ---
  static Future<List<Map<String, String>>> _fetchContacts(String storeId) async {
    List<Map<String, String>> contacts = [];
    Set<String> uniqueKeys = {};

    void add(String? name, String? phone, String? email) {
      final n = (name?.trim() ?? '').isEmpty ? 'Inconnu' : name!.trim();
      final p = (phone?.trim() ?? '').isEmpty ? 'N/A' : phone!.trim();
      final e = (email?.trim() ?? '').isEmpty ? 'N/A' : email!.trim();
      if (n == 'Inconnu' && p == 'N/A' && e == 'N/A') return;

      final key = '${n.toLowerCase()}_${p.toLowerCase()}';
      if (!uniqueKeys.contains(key)) {
        uniqueKeys.add(key);
        contacts.add({'name': n, 'phone': p, 'email': e});
      }
    }

    try {
      final interventions = await FirebaseFirestore.instance.collection('interventions').where('storeId', isEqualTo: storeId).get();
      for (var doc in interventions.docs) {
        add(doc.data()['managerName'], doc.data()['managerPhone'], doc.data()['managerEmail']);
      }
      final installations = await FirebaseFirestore.instance.collection('installations').where('storeId', isEqualTo: storeId).get();
      for (var doc in installations.docs) {
        add(doc.data()['managerName'] ?? doc.data()['contactName'], doc.data()['managerPhone'] ?? doc.data()['contactPhone'], doc.data()['managerEmail'] ?? doc.data()['contactEmail']);
      }
    } catch (_) {}
    return contacts;
  }

  static Future<List<Map<String, dynamic>>> _fetchHistory(String storeId) async {
    List<Map<String, dynamic>> history = [];
    try {
      final interventions = await FirebaseFirestore.instance.collection('interventions').where('storeId', isEqualTo: storeId).get();
      for (var doc in interventions.docs) {
        history.add({'type': 'Intervention', 'code': doc['interventionCode'] ?? 'N/A', 'date': doc['scheduledAt'] ?? doc['createdAt'], 'primaryDesc': doc['diagnostic'], 'technicians': doc['assignedTechnicians']});
      }
      final installations = await FirebaseFirestore.instance.collection('installations').where('storeId', isEqualTo: storeId).get();
      for (var doc in installations.docs) {
        history.add({'type': 'Installation', 'code': doc['installationCode'] ?? 'N/A', 'date': doc['completedAt'] ?? doc['createdAt'], 'primaryDesc': doc['initialRequest'], 'technicians': doc['assignedTechnicianNames']});
      }
      final livraisons = await FirebaseFirestore.instance.collection('livraisons').where('storeId', isEqualTo: storeId).get();
      for (var doc in livraisons.docs) {
        history.add({'type': 'Livraison', 'code': doc['bonLivraisonCode'] ?? 'N/A', 'date': doc['completedAt'] ?? doc['createdAt'], 'primaryDesc': 'Livraison effectuée.'});
      }
      final savs = await FirebaseFirestore.instance.collection('sav_tickets').where('storeId', isEqualTo: storeId).get();
      for (var doc in savs.docs) {
        history.add({'type': 'SAV', 'code': doc['savCode'] ?? 'N/A', 'date': doc['pickupDate'] ?? doc['createdAt'], 'primaryDesc': doc['problemDescription'], 'technicians': doc['pickupTechnicianNames']});
      }

      history.sort((a, b) {
        final Timestamp? tA = a['date'] as Timestamp?;
        final Timestamp? tB = b['date'] as Timestamp?;
        if (tA == null) return 1;
        if (tB == null) return -1;
        return tB.compareTo(tA);
      });
    } catch (_) {}
    return history;
  }
}