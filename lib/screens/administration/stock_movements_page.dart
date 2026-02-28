// lib/screens/administration/stock_movements_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_saver/file_saver.dart';

import 'package:boitex_info_app/services/stock_audit_pdf_service.dart';
import 'package:boitex_info_app/widgets/pdf_viewer_page.dart';

enum StockMovementType { entry, exit }

class StockMovementsPage extends StatefulWidget {
  final StockMovementType type;

  const StockMovementsPage({super.key, required this.type});

  @override
  State<StockMovementsPage> createState() => _StockMovementsPageState();
}

class _StockMovementsPageState extends State<StockMovementsPage> {
  DateTime _selectedMonth = DateTime.now();

  // ✅ 1. FILTER STATE VARIABLES (UNCHANGED)
  String _filterProduct = '';
  String _filterClientStore = '';
  String _filterSupplier = '';
  String _filterUser = '';
  String _searchKeyword = '';

  // Keep a reference to the currently filtered docs for PDF export
  List<QueryDocumentSnapshot> _currentFilteredDocs = [];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null);
  }

  // (UNCHANGED)
  void _changeMonth(int monthsToAdd) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + monthsToAdd, 1);
    });
  }

  // (UNCHANGED)
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale("fr", "FR"),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: widget.type == StockMovementType.entry ? const Color(0xFF00B074) : const Color(0xFFFF5C5C),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month, 1);
      });
    }
  }

  // ✅ 2. PREMIUM BOTTOM SHEET FOR ADVANCED FILTERS
  void _showFilterDialog() {
    final productCtrl = TextEditingController(text: _filterProduct);
    final clientCtrl = TextEditingController(text: _filterClientStore);
    final supplierCtrl = TextEditingController(text: _filterSupplier);
    final userCtrl = TextEditingController(text: _filterUser);
    final searchCtrl = TextEditingController(text: _searchKeyword);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Center( // Centered for Web/4K compatibility
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800), // Max width for large screens
            child: Container(
              decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 40, spreadRadius: 0, offset: Offset(0, -10))
                  ]
              ),
              padding: EdgeInsets.only(
                left: 24, right: 24, top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 32,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Premium Drag Handle
                    Center(
                      child: Container(
                        width: 48, height: 5,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Filtres de recherche", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: Colors.black87)),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _filterProduct = ''; _filterClientStore = '';
                              _filterSupplier = ''; _filterUser = ''; _searchKeyword = '';
                            });
                            Navigator.pop(context);
                          },
                          child: Text("Réinitialiser", style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildPremiumFilterField("Recherche globale (Notes, Motif)", Icons.search_rounded, searchCtrl),
                    _buildPremiumFilterField("Produit (Nom ou Référence)", Icons.inventory_2_rounded, productCtrl),
                    _buildPremiumFilterField("Client / Magasin", Icons.storefront_rounded, clientCtrl),
                    _buildPremiumFilterField("Fournisseur", Icons.local_shipping_rounded, supplierCtrl),
                    _buildPremiumFilterField("Technicien / Utilisateur", Icons.person_rounded, userCtrl),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.type == StockMovementType.entry ? const Color(0xFF00B074) : const Color(0xFFFF5C5C),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          setState(() {
                            _filterProduct = productCtrl.text.trim();
                            _filterClientStore = clientCtrl.text.trim();
                            _filterSupplier = supplierCtrl.text.trim();
                            _filterUser = userCtrl.text.trim();
                            _searchKeyword = searchCtrl.text.trim();
                          });
                          Navigator.pop(context);
                        },
                        child: Text("Appliquer les Filtres", style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPremiumFilterField(String label, IconData icon, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        style: GoogleFonts.poppins(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 22),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  // ✅ 3. EXPORT PDF LOGIC (UNCHANGED)
  Future<void> _exportToPdf() async {
    if (_currentFilteredDocs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Aucune donnée à exporter.")));
      return;
    }

    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1).subtract(const Duration(days: 1));

      List<String> activeFilters = [];
      if (_filterProduct.isNotEmpty) activeFilters.add("Produit: $_filterProduct");
      if (_filterClientStore.isNotEmpty) activeFilters.add("Client: $_filterClientStore");
      if (_filterSupplier.isNotEmpty) activeFilters.add("Fournisseur: $_filterSupplier");
      if (_filterUser.isNotEmpty) activeFilters.add("Tech: $_filterUser");
      if (_searchKeyword.isNotEmpty) activeFilters.add("Mot-clé: $_searchKeyword");

      final filterString = activeFilters.isEmpty ? "Aucun" : activeFilters.join(" | ");
      final title = widget.type == StockMovementType.entry ? "Rapport des Entrées de Stock" : "Rapport des Sorties de Stock";

      final pdfService = StockAuditPdfService();
      final bytes = await pdfService.generateAuditPdf(
        _currentFilteredDocs,
        startOfMonth,
        endOfMonth,
        {},
        {},
        title,
        activeFilters: filterString,
      );

      if (mounted) Navigator.pop(context);

      final String filename = "Mouvements_${widget.type == StockMovementType.entry ? 'Entrees' : 'Sorties'}_${DateFormat('MMyyyy').format(_selectedMonth)}.pdf";

      if (kIsWeb) {
        await FileSaver.instance.saveFile(name: filename.replaceAll('.pdf', ''), bytes: bytes, ext: 'pdf', mimeType: MimeType.pdf);
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(bytes);
        if (mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => PdfViewerPage(pdfBytes: bytes, title: title)));
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur PDF: $e')));
    }
  }

  bool get _hasActiveFilters => _filterProduct.isNotEmpty || _filterClientStore.isNotEmpty || _filterSupplier.isNotEmpty || _filterUser.isNotEmpty || _searchKeyword.isNotEmpty;

  // ===========================================================================
  // 💎 PREMIUM UI BUILDER
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final isEntry = widget.type == StockMovementType.entry;
    final title = isEntry ? "Détails des Entrées" : "Détails des Sorties";
    final themeColor = isEntry ? const Color(0xFF00B074) : const Color(0xFFFF5C5C);
    final themeBgColor = isEntry ? const Color(0xFFE5F7F1) : const Color(0xFFFFEEEE);
    final typeString = isEntry ? 'Entrée' : 'Sortie';

    final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);

    final monthLabel = DateFormat.yMMMM('fr_FR').format(_selectedMonth);
    final formattedDate = monthLabel[0].toUpperCase() + monthLabel.substring(1);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC), // Sleek ultra-light grey background
      appBar: AppBar(
        title: Text(title, style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: -0.5)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 20),
            ),
            tooltip: "Exporter en PDF",
            onPressed: _exportToPdf,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: _hasActiveFilters ? themeColor : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8)
              ),
              child: Icon(
                _hasActiveFilters ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
                color: _hasActiveFilters ? Colors.white : Colors.black87,
                size: 20,
              ),
            ),
            tooltip: "Filtrer",
            onPressed: _showFilterDialog,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center( // Center content for 4K / Web
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200), // Limits width on Ultra-Wide Monitors
          child: Column(
            children: [
              // 🗓️ PREMIUM NAVIGATION PILL
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 12, left: 16, right: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min, // Hug contents
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: () => _changeMonth(-1), color: Colors.grey.shade600),
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(color: themeBgColor, borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 16, color: themeColor),
                              const SizedBox(width: 8),
                              Text(formattedDate, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: themeColor)),
                            ],
                          ),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.chevron_right_rounded), onPressed: () => _changeMonth(1), color: Colors.grey.shade600),
                    ],
                  ),
                ),
              ),

              // 📄 PREMIUM LIST OF MOVEMENTS
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collectionGroup('stock_history')
                      .where('type', isEqualTo: typeString)
                      .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
                      .where('timestamp', isLessThan: Timestamp.fromDate(endOfMonth))
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return Center(child: Text("Erreur: ${snapshot.error}", style: GoogleFonts.poppins()));
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      _currentFilteredDocs = [];
                      return _buildEmptyState("Aucun mouvement enregistré en $formattedDate");
                    }

                    // ✅ CLIENT-SIDE FILTERS (UNCHANGED LOGIC)
                    final allDocs = snapshot.data!.docs;
                    final filteredDocs = allDocs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final String productName = (data['productName'] ?? '').toString().toLowerCase();
                      final String productRef = (data['productRef'] ?? '').toString().toLowerCase();
                      final String user = (data['user'] ?? '').toString().toLowerCase();
                      final String clientName = (data['clientName'] ?? '').toString().toLowerCase();
                      final String notes = (data['notes'] ?? data['reason'] ?? '').toString().toLowerCase();

                      if (_filterProduct.isNotEmpty && !productName.contains(_filterProduct.toLowerCase()) && !productRef.contains(_filterProduct.toLowerCase())) return false;
                      if (_filterClientStore.isNotEmpty && !clientName.contains(_filterClientStore.toLowerCase()) && !notes.contains(_filterClientStore.toLowerCase())) return false;
                      if (_filterSupplier.isNotEmpty && !notes.contains(_filterSupplier.toLowerCase())) return false;
                      if (_filterUser.isNotEmpty && !user.contains(_filterUser.toLowerCase())) return false;
                      if (_searchKeyword.isNotEmpty &&
                          !productName.contains(_searchKeyword.toLowerCase()) &&
                          !productRef.contains(_searchKeyword.toLowerCase()) &&
                          !notes.contains(_searchKeyword.toLowerCase()) &&
                          !user.contains(_searchKeyword.toLowerCase())) return false;
                      return true;
                    }).toList();

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if(mounted) _currentFilteredDocs = filteredDocs;
                    });

                    if (filteredDocs.isEmpty) {
                      return _buildEmptyState("Aucun résultat pour ces filtres.", icon: Icons.filter_list_off_rounded);
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        return _buildPremiumMovementCard(filteredDocs[index], isEntry, themeColor, themeBgColor);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 📦 PREMIUM DATA ROW CARD
  Widget _buildPremiumMovementCard(QueryDocumentSnapshot doc, bool isEntry, Color themeColor, Color themeBgColor) {
    final data = doc.data() as Map<String, dynamic>;
    final change = data['change'] ?? data['quantityChange'] ?? 0;
    final reason = data['reason'] ?? data['notes'] ?? "Mise à jour";
    final user = data['user'] ?? "Inconnu";
    final timestamp = data['timestamp'] as Timestamp?;
    final dateStr = timestamp != null ? DateFormat('dd MMM yyyy • HH:mm', 'fr_FR').format(timestamp.toDate()) : "Date inconnue";

    final productRef = doc.reference.parent.parent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Status Icon
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: themeBgColor, borderRadius: BorderRadius.circular(14)),
              child: Icon(isEntry ? Icons.south_west_rounded : Icons.north_east_rounded, color: themeColor, size: 22),
            ),
            const SizedBox(width: 16),

            // Middle Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name Fetcher
                  productRef != null ? FutureBuilder<DocumentSnapshot>(
                    future: productRef.get(),
                    builder: (context, productSnap) {
                      if (!productSnap.hasData) return Text("Chargement...", style: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 13));
                      final productData = productSnap.data!.data() as Map<String, dynamic>?;
                      final productName = productData?['nom'] ?? data['productName'] ?? "Produit Inconnu";
                      return Text(productName, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.black87, letterSpacing: -0.3));
                    },
                  ) : Text(data['productName'] ?? "Produit Inconnu", style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.black87, letterSpacing: -0.3)),

                  const SizedBox(height: 6),

                  // Notes/Reason
                  Text(reason, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600, height: 1.4)),

                  const SizedBox(height: 12),

                  // Meta Data Chips (User & Date)
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      _buildMetaChip(Icons.person_rounded, user),
                      _buildMetaChip(Icons.access_time_filled_rounded, dateStr),
                    ],
                  ),
                ],
              ),
            ),

            // Right Side: Quantity
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade100)),
              child: Column(
                children: [
                  Text("QTE", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1)),
                  const SizedBox(height: 2),
                  Text("${isEntry ? '+' : ''}$change", style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 20, color: themeColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Text(text, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, {IconData icon = Icons.search_off_rounded}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)]),
            child: Icon(icon, size: 64, color: Colors.grey.shade300),
          ),
          const SizedBox(height: 24),
          Text(message, style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}