// lib/screens/administration/manage_clients_page.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:boitex_info_app/screens/administration/add_client_page.dart';
import 'package:boitex_info_app/screens/administration/manage_stores_page.dart';
import 'package:printing/printing.dart';
import 'package:boitex_info_app/services/client_report_service.dart';
import 'package:boitex_info_app/services/client_report_pdf_service.dart';
import 'package:boitex_info_app/screens/administration/client_details_page.dart';

// 🎨 --- 2026 PREMIUM APPLE COLORS & CONSTANTS --- 🎨
const kTextDark = Color(0xFF1D1D1F);
const kTextSecondary = Color(0xFF86868B);
const kAppleBlue = Color(0xFF007AFF);
const kAppleRed = Color(0xFFFF3B30);
const kGlassBorder = Color(0x33FFFFFF);
const double kRadius = 24.0;

class ManageClientsPage extends StatefulWidget {
  final String userRole;
  const ManageClientsPage({super.key, required this.userRole});

  @override
  State<ManageClientsPage> createState() => _ManageClientsPageState();
}

class _ManageClientsPageState extends State<ManageClientsPage> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchTimer;
  String _searchQuery = '';
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // ⚙️ LOGIC METHODS
  // ---------------------------------------------------------------------------

  void _onSearchChanged() {
    if (_searchTimer?.isActive ?? false) _searchTimer!.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = _searchController.text.trim();
        if (_searchQuery.isNotEmpty) {
          _performSearch();
        } else {
          _isSearching = false;
          _searchResults.clear();
        }
      });
    });
  }

  Future<void> _performSearch() async {
    setState(() { _isSearching = true; });
    try {
      final queryStr = _searchQuery.toLowerCase();
      final snapshot = await FirebaseFirestore.instance.collection('clients').get();

      final results = snapshot.docs.where((doc) {
        final data = doc.data();
        final name = (data['name'] ?? '').toString().toLowerCase();
        List<dynamic> keywords = data['search_keywords'] ?? [];
        bool matchesKeyword = keywords.any((k) => k.toString().toLowerCase().contains(queryStr));

        return name.contains(queryStr) || matchesKeyword;
      }).map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('Error searching clients: $e');
      if (mounted) setState(() { _isSearching = false; });
    }
  }

  Future<void> _deleteClient(String clientId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        title: Text('Supprimer ce client ?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: kTextDark)),
        content: Text('Cette action supprimera définitivement le client et tous ses magasins. Cette action est irréversible.', style: GoogleFonts.inter(color: kTextDark)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Annuler', style: GoogleFonts.inter(color: kTextSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kAppleRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Supprimer', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('clients').doc(clientId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Client supprimé avec succès', style: GoogleFonts.inter()),
            backgroundColor: kTextDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur: $e', style: GoogleFonts.inter()),
            backgroundColor: kAppleRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ));
        }
      }
    }
  }

  Future<void> _renameClient(String clientId, String currentName) async {
    final TextEditingController nameController = TextEditingController(text: currentName);
    final String? newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        title: Text('Renommer le client', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: kTextDark)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: GoogleFonts.inter(color: kTextDark, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            labelText: 'Nouveau nom',
            labelStyle: GoogleFonts.inter(color: kTextSecondary),
            filled: true,
            fillColor: Colors.black.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kAppleBlue, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Annuler', style: GoogleFonts.inter(color: kTextSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kAppleBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () => Navigator.of(context).pop(nameController.text.trim()),
            child: Text('Enregistrer', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != currentName) {
      try {
        await FirebaseFirestore.instance.collection('clients').doc(clientId).update({'name': newName});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Client renommé avec succès', style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF34C759),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur lors du renommage: $e', style: GoogleFonts.inter()),
            backgroundColor: kAppleRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ));
        }
      }
    }
  }

  Future<void> _generateClientReport(String clientId, String clientName, Map<String, dynamic> config) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(kRadius),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: kAppleBlue),
              const SizedBox(height: 20),
              Text("Génération du rapport en cours...", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: kTextDark)),
            ],
          ),
        ),
      ),
    );

    try {
      DateTime now = DateTime.now();
      DateTime start;
      if (config['dateRange'] == '7_days') {
        start = now.subtract(const Duration(days: 7));
      } else if (config['dateRange'] == '30_days') {
        start = now.subtract(const Duration(days: 30));
      } else {
        start = DateTime(2000);
      }
      DateTimeRange range = DateTimeRange(start: start, end: now);

      final reportData = await ClientReportService().fetchReportData(
        clientId: clientId,
        clientName: clientName,
        dateRange: range,
        storeIds: config['storeIds'],
        activityTypes: config['activityTypes'],
      );

      final pdfBytes = await ClientReportPdfService().generateReport(reportData);

      if (mounted) {
        Navigator.pop(context);
        await Printing.layoutPdf(
          onLayout: (format) async => pdfBytes,
          name: 'Rapport_Activite_$clientName.pdf',
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Erreur: $e", style: GoogleFonts.inter()),
          backgroundColor: kAppleRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 🪄 MODERN APPLE IOS BOTTOM SHEET
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>?> _showReportConfigurationDialog(String clientId) async {
    bool selectAllStores = true;
    List<String> selectedStoreIds = [];
    String dateRange = '30_days';
    Map<String, bool> activityTypes = {
      'Interventions': true,
      'Installations': true,
      'Livraisons': true,
      'SAV': true,
    };

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
            builder: (context, setStateSheet) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.85,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40, height: 5,
                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text("Configuration du Rapport", style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: kTextDark, letterSpacing: -0.5)),
                          const SizedBox(height: 8),
                          Text("Sélectionnez les filtres pour générer l'export PDF.", style: GoogleFonts.inter(color: kTextSecondary, fontSize: 14)),
                          const SizedBox(height: 24),

                          Expanded(
                            child: ListView(
                              physics: const BouncingScrollPhysics(),
                              children: [
                                Text("PÉRIODE", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: kTextSecondary, letterSpacing: 1.2)),
                                const SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black.withOpacity(0.05))),
                                  child: Column(
                                    children: [
                                      RadioListTile<String>(
                                        value: '7_days', groupValue: dateRange,
                                        activeColor: kAppleBlue,
                                        title: Text("7 derniers jours", style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                                        onChanged: (v) => setStateSheet(() => dateRange = v!),
                                      ),
                                      Divider(height: 1, color: Colors.black.withOpacity(0.05), indent: 20),
                                      RadioListTile<String>(
                                        value: '30_days', groupValue: dateRange,
                                        activeColor: kAppleBlue,
                                        title: Text("30 derniers jours", style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                                        onChanged: (v) => setStateSheet(() => dateRange = v!),
                                      ),
                                      Divider(height: 1, color: Colors.black.withOpacity(0.05), indent: 20),
                                      RadioListTile<String>(
                                        value: 'all_time', groupValue: dateRange,
                                        activeColor: kAppleBlue,
                                        title: Text("Toute l'histoire", style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                                        onChanged: (v) => setStateSheet(() => dateRange = v!),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),

                                Text("MAGASINS", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: kTextSecondary, letterSpacing: 1.2)),
                                const SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black.withOpacity(0.05))),
                                  child: Column(
                                    children: [
                                      SwitchListTile.adaptive(
                                        activeColor: const Color(0xFF34C759),
                                        title: Text("Tous les magasins", style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: kTextDark)),
                                        value: selectAllStores,
                                        onChanged: (val) {
                                          setStateSheet(() {
                                            selectAllStores = val;
                                            if (val) selectedStoreIds.clear();
                                          });
                                        },
                                      ),
                                      if (!selectAllStores) ...[
                                        Divider(height: 1, color: Colors.black.withOpacity(0.05)),
                                        SizedBox(
                                          height: 200,
                                          child: StreamBuilder<QuerySnapshot>(
                                            stream: FirebaseFirestore.instance.collection('clients').doc(clientId).collection('stores').orderBy('name').snapshots(),
                                            builder: (context, snapshot) {
                                              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator.adaptive());
                                              final stores = snapshot.data!.docs;
                                              if (stores.isEmpty) return Center(child: Text("Aucun magasin trouvé.", style: GoogleFonts.inter(color: kTextSecondary)));
                                              return ListView.builder(
                                                itemCount: stores.length,
                                                itemBuilder: (context, index) {
                                                  final store = stores[index];
                                                  final name = store['name'] ?? 'Inconnu';
                                                  final isChecked = selectedStoreIds.contains(store.id);
                                                  return CheckboxListTile(
                                                    activeColor: kAppleBlue,
                                                    title: Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                                                    value: isChecked,
                                                    onChanged: (val) {
                                                      setStateSheet(() {
                                                        if (val == true) selectedStoreIds.add(store.id);
                                                        else selectedStoreIds.remove(store.id);
                                                      });
                                                    },
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                      ]
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),

                                Text("ACTIVITÉS À INCLURE", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: kTextSecondary, letterSpacing: 1.2)),
                                const SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black.withOpacity(0.05))),
                                  child: Column(
                                    children: activityTypes.keys.map((key) {
                                      return Column(
                                        children: [
                                          SwitchListTile.adaptive(
                                            activeColor: const Color(0xFF34C759),
                                            title: Text(key, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                                            value: activityTypes[key]!,
                                            onChanged: (val) => setStateSheet(() => activityTypes[key] = val),
                                          ),
                                          if (key != activityTypes.keys.last) Divider(height: 1, color: Colors.black.withOpacity(0.05), indent: 20),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Action Buttons
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: Text("Annuler", style: GoogleFonts.inter(color: kTextSecondary, fontWeight: FontWeight.bold, fontSize: 16)),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kTextDark,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 0,
                                  ),
                                  onPressed: () {
                                    final selectedActivities = activityTypes.entries.where((e) => e.value).map((e) => e.key).toList();
                                    if (selectedActivities.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                        content: Text("Veuillez sélectionner au moins une activité.", style: GoogleFonts.inter()),
                                        behavior: SnackBarBehavior.floating,
                                      ));
                                      return;
                                    }
                                    Navigator.pop(context, {
                                      'dateRange': dateRange,
                                      'storeIds': selectAllStores ? <String>[] : selectedStoreIds,
                                      'activityTypes': selectedActivities,
                                    });
                                  },
                                  child: Text("Générer le PDF", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 🎨 COLORFUL MESH BACKGROUND & GLASSMORPHIC UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('Gestion des Clients', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: kTextDark, fontSize: 20, letterSpacing: -0.5)),
        iconTheme: const IconThemeData(color: kTextDark),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(color: Colors.white.withOpacity(0.4)),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AddClientPage()));
        },
        backgroundColor: kTextDark,
        elevation: 10,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Nouveau Client', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.2)),
      ),
      body: Stack(
        children: [
          // 1. Colourful Mesh Gradient Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, 0.4, 0.8, 1.0],
                  colors: [
                    Color(0xFFE0C3FC), // Soft Lilac
                    Color(0xFFE8F1F5), // White-ish Blue
                    Color(0xFF8EC5FC), // Sky Blue
                    Color(0xFFFEE1E8), // Soft Pink
                  ],
                ),
              ),
            ),
          ),

          // 2. Extra Blur layer for the "frosted" global effect
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(color: Colors.white.withOpacity(0.2)),
            ),
          ),

          // 3. Main Content
          SafeArea(
            child: Column(
              children: [
                _buildGlassSearchBar(),
                Expanded(
                  child: _isSearching
                      ? const Center(child: CircularProgressIndicator.adaptive())
                      : (_searchQuery.isNotEmpty ? _buildSearchResults() : _buildNormalList()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.inter(color: kTextDark, fontWeight: FontWeight.w500, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Rechercher un client...',
                hintStyle: GoogleFonts.inter(color: kTextSecondary),
                prefixIcon: const Icon(Icons.search_rounded, color: kTextSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.cancel_rounded, color: kTextSecondary, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    FocusScope.of(context).unfocus();
                  },
                )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNormalList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('clients').orderBy('name').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Erreur: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator.adaptive());

        final clients = snapshot.data!.docs;
        if (clients.isEmpty) return Center(child: Text("Aucun client trouvé.", style: GoogleFonts.inter(color: kTextSecondary, fontSize: 16)));

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 100), // Space for FAB
          itemCount: clients.length,
          itemBuilder: (context, index) {
            final doc = clients[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildGlassClientCard(doc.id, data['name'] ?? 'Inconnu', data);
          },
        );
      },
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(child: Text("Aucun client trouvé pour '$_searchQuery'.", style: GoogleFonts.inter(color: kTextSecondary, fontSize: 16)));
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final clientMap = _searchResults[index];
        return _buildGlassClientCard(clientMap['id'], clientMap['name'], clientMap);
      },
    );
  }

  // 💎 THE 2026 PREMIUM GLASS CARD
  Widget _buildGlassClientCard(String clientId, String clientName, Map<String, dynamic> clientData) {
    final int hash = clientName.hashCode;
    final Color color1 = HSLColor.fromAHSL(1.0, (hash % 360).toDouble(), 0.7, 0.6).toColor();
    final Color color2 = HSLColor.fromAHSL(1.0, ((hash + 40) % 360).toDouble(), 0.8, 0.5).toColor();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, left: 20, right: 20),
      child: Slidable(
        key: ValueKey(clientId),
        endActionPane: ActionPane(
          motion: const StretchMotion(),
          extentRatio: 0.5,
          children: [
            SlidableAction(
              onPressed: (context) => _renameClient(clientId, clientName),
              backgroundColor: kAppleBlue.withOpacity(0.9),
              foregroundColor: Colors.white,
              icon: Icons.edit_rounded,
              label: 'Modifier',
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(kRadius)),
            ),
            SlidableAction(
              onPressed: (context) => _deleteClient(clientId),
              backgroundColor: kAppleRed.withOpacity(0.9),
              foregroundColor: Colors.white,
              icon: Icons.delete_outline_rounded,
              label: 'Supprimer',
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(kRadius)),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(kRadius),
            border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(kRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // ✅ NEW: TOP ROW IS NOW CLICKABLE TO VIEW FULL CLIENT DETAILS
                    InkWell(
                      onTap: () {
                        // Open the new breathtaking Client Details Hub
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => ClientDetailsPage(clientId: clientId),
                        ));
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Row(
                          children: [
                            Container(
                              width: 54, height: 54,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(colors: [color1, color2], begin: Alignment.topLeft, end: Alignment.bottomRight),
                                boxShadow: [BoxShadow(color: color2.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
                              ),
                              child: Center(
                                child: Text(
                                  clientName.isNotEmpty ? clientName[0].toUpperCase() : '?',
                                  style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(clientName, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark, letterSpacing: -0.3)),
                                  const SizedBox(height: 4),
                                  Text("ID: ${clientId.substring(0, 8).toUpperCase()}", style: GoogleFonts.inter(fontSize: 12, color: kTextSecondary, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            // Small indicator showing it's clickable
                            const Icon(Icons.chevron_right_rounded, color: kTextSecondary, size: 20),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    Divider(height: 1, color: Colors.black.withOpacity(0.05)),
                    const SizedBox(height: 16),

                    // BOTTOM ROW: Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) => ManageStoresPage(clientId: clientId, clientName: clientName))),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.storefront_rounded, size: 18, color: kTextDark),
                                  const SizedBox(width: 8),
                                  Text("Magasins", style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: kTextDark, fontSize: 14)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final config = await _showReportConfigurationDialog(clientId);
                              if (config != null) {
                                _generateClientReport(clientId, clientName, config);
                              }
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: kAppleBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.insert_chart_rounded, size: 18, color: kAppleBlue),
                                  const SizedBox(width: 8),
                                  Text("Rapport", style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: kAppleBlue, fontSize: 14)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}