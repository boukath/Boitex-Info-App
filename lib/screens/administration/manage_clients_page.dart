// lib/screens/administration/manage_clients_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_slidable/flutter_slidable.dart'; // ✅ ADDED: Swipe Actions
import 'package:boitex_info_app/screens/administration/add_client_page.dart';
import 'package:boitex_info_app/screens/administration/manage_stores_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'dart:async';

// ✅ IMPORTS FOR REPORT GENERATION
import 'package:printing/printing.dart';
import 'package:boitex_info_app/services/client_report_service.dart';
import 'package:boitex_info_app/services/client_report_pdf_service.dart';

class ManageClientsPage extends StatefulWidget {
  final String userRole;
  const ManageClientsPage({super.key, required this.userRole});

  @override
  State<ManageClientsPage> createState() => _ManageClientsPageState();
}

// 🎨 --- DESIGN CONSTANTS --- 🎨
const kPrimaryColor = Color(0xFF7B61FF);
const kAccentColor = Color(0xFF00B4D8);
const kErrorColor = Color(0xFFFF6F91);
const kBackgroundColorTop = Color(0xFFE8E1FF);
const kBackgroundColorBottom = Color(0xFFFBEAFF);
const kTextPrimary = Color(0xFF1E1E2A);
const kTextSecondary = Color(0xFF7A7A8C);
const kCardColor = Color.fromRGBO(255, 255, 255, 0.85);

class _ManageClientsPageState extends State<ManageClientsPage>
    with SingleTickerProviderStateMixin {

  final List<String> _selectedServices = [];
  late TabController _tabController;

  // --- ADVANCED SEARCH START ---
  final TextEditingController _clientSearchController = TextEditingController();
  final TextEditingController _storeSearchController = TextEditingController();
  final FocusNode _clientFocusNode = FocusNode();
  final FocusNode _storeFocusNode = FocusNode();

  String _clientSearchQuery = '';
  String _storeSearchQuery = '';
  List<String> _clientSearchTokens = [];
  List<String> _storeSearchTokens = [];

  Timer? _clientDebounce;
  Timer? _storeDebounce;

  bool _isClientFocused = false;
  bool _isStoreFocused = false;
  // --- ADVANCED SEARCH END ---

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {});
      }
    });

    _clientSearchController.addListener(_onClientSearchChanged);
    _storeSearchController.addListener(_onStoreSearchChanged);
    _clientFocusNode.addListener(() {
      setState(() => _isClientFocused = _clientFocusNode.hasFocus);
    });
    _storeFocusNode.addListener(() {
      setState(() => _isStoreFocused = _storeFocusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _clientSearchController.removeListener(_onClientSearchChanged);
    _storeSearchController.removeListener(_onStoreSearchChanged);
    _clientSearchController.dispose();
    _storeSearchController.dispose();
    _clientFocusNode.dispose();
    _storeFocusNode.dispose();
    _clientDebounce?.cancel();
    _storeDebounce?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  // --- ADVANCED SEARCH START ---
  void _onClientSearchChanged() {
    if (_clientDebounce?.isActive ?? false) _clientDebounce!.cancel();
    _clientDebounce = Timer(const Duration(milliseconds: 300), () {
      final query = _clientSearchController.text;
      final normalizedQuery = _normalize(query);
      setState(() {
        _clientSearchQuery = query;
        _clientSearchTokens = normalizedQuery.split(' ').where((t) => t.isNotEmpty).toList();
      });
    });
  }

  void _onStoreSearchChanged() {
    if (_storeDebounce?.isActive ?? false) _storeDebounce!.cancel();
    _storeDebounce = Timer(const Duration(milliseconds: 300), () {
      final query = _storeSearchController.text;
      final normalizedQuery = _normalize(query);
      setState(() {
        _storeSearchQuery = query;
        _storeSearchTokens = normalizedQuery.split(' ').where((t) => t.isNotEmpty).toList();
      });
    });
  }
  // --- ADVANCED SEARCH END ---

  Color _getAvatarColor(String text) {
    return Colors.primaries[text.hashCode % Colors.primaries.length].shade300;
  }

  // ✅ UPDATED: Added Filter for 'archived' status
  bool _matchesClient(Map data) {
    // 1. Safety Check: Hide Archived
    if (data['status'] == 'archived') return false;

    // 2. Service Filter
    final services = List<String>.from(data['services'] ?? []);
    final matchesService = _selectedServices.isEmpty ||
        services.any((s) => _selectedServices.contains(s));

    if (!matchesService) return false;

    // 3. Search Filter
    if (_clientSearchTokens.isEmpty) return true;

    final name = data['name'] as String? ?? '';
    final searchable = [
      _normalize(name),
      services.map(_normalize).join(' '),
    ].join(' ');

    return _clientSearchTokens.every((token) => searchable.contains(token));
  }

  bool _matchesStore(Map data) {
    // 1. Safety Check: Hide Archived (Consistent with Manage Stores)
    if (data['status'] == 'archived') return false;

    if (_storeSearchTokens.isEmpty) return true;

    final name = data['name'] as String? ?? '';
    final location = data['location'] as String? ?? '';

    final searchable = [
      _normalize(name),
      _normalize(location),
    ].join(' ');

    return _storeSearchTokens.every((token) => searchable.contains(token));
  }

  // ---------------------------------------------------------------------------
  // 🗑️ DELETE & ARCHIVE LOGIC
  // ---------------------------------------------------------------------------

  /// ✅ ACTION 1: Archive (Soft Delete) - Swipe LEFT
  Future<void> _archiveClient(BuildContext context, DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final clientName = data['name'] ?? 'ce client';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Archiver le client ?"),
        content: Text(
            "Êtes-vous sûr de vouloir archiver '$clientName' ?\n\n"
                "Il disparaîtra de la liste, mais l'historique et les magasins seront conservés."
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text("Archiver"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await doc.reference.update({
        'status': 'archived',
        'archivedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Client '$clientName' archivé."), backgroundColor: Colors.orange),
        );
      }
    }
  }

  /// ✅ ACTION 2: Hard Delete - Swipe RIGHT
  Future<void> _deleteClient(BuildContext context, DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final clientName = data['name'] ?? 'ce client';

    // 🛑 DANGER ALERT DIALOG
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Supprimer DÉFINITIVEMENT ?"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                "Vous allez supprimer '$clientName'.",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "⚠️ ATTENTION : Cela supprimera aussi l'accès à tous les magasins et équipements associés. Cette action est irréversible.",
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Annuler")
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("SUPPRIMER", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await doc.reference.delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Client supprimé définitivement."),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 📊 REPORT GENERATION LOGIC
  // ---------------------------------------------------------------------------
  Future<void> _handleGenerateReport(String clientId, String clientName) async {
    try {
      final DateTimeRange? dateRange = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialDateRange: DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 30)),
          end: DateTime.now(),
        ),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: kPrimaryColor,
                onPrimary: Colors.white,
                surface: kCardColor,
                onSurface: kTextPrimary,
              ),
            ),
            child: child!,
          );
        },
      );

      if (dateRange == null) return;

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: kPrimaryColor),
        ),
      );

      final reportService = ClientReportService();
      final reportData = await reportService.fetchReportData(
        clientId: clientId,
        clientName: clientName,
        dateRange: dateRange,
      );

      final pdfService = ClientReportPdfService();
      final pdfBytes = await pdfService.generateReport(reportData);

      if (mounted) Navigator.pop(context);

      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name:
        'Rapport_${clientName}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de la génération: $e"),
          backgroundColor: kErrorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const availableServices = ['Service Technique', 'Service IT'];

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth > 700;

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [kBackgroundColorTop, kBackgroundColorBottom],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            floatingActionButton: _buildAnimatedFab(),
            body: SafeArea(
              child: GestureDetector(
                onTap: () {
                  _clientFocusNode.unfocus();
                  _storeFocusNode.unfocus();
                },
                child: Column(
                  children: [
                    _buildHeader(),
                    _buildTabBar(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildClientTab(availableServices, isWide),
                          _buildStoreTab(isWide),
                        ],
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kCardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: kPrimaryColor.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: kTextPrimary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Clients & Magasins',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: kPrimaryColor.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: kTextSecondary,
          labelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          indicator: BoxDecoration(
            gradient: const LinearGradient(
              colors: [kPrimaryColor, Color(0xFFA08FFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: kPrimaryColor.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          tabs: const [
            Tab(text: 'Clients'),
            Tab(text: 'Magasins'),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSearchBar({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required IconData icon,
    required bool isFocused,
  }) {
    return AnimatedScale(
      scale: isFocused ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: isFocused
                  ? kPrimaryColor.withOpacity(0.15)
                  : kPrimaryColor.withOpacity(0.05),
              blurRadius: isFocused ? 25 : 15,
              offset: Offset(0, isFocused ? 8 : 5),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          style: GoogleFonts.poppins(color: kTextPrimary),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle:
            GoogleFonts.poppins(color: kTextSecondary.withOpacity(0.7)),
            prefixIcon: Container(
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [kPrimaryColor, kAccentColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: kPrimaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
              icon:
              const Icon(Icons.close_rounded, color: kTextSecondary),
              onPressed: () {
                controller.clear();
              },
              splashRadius: 20,
              tooltip: 'Effacer',
            )
                : null,
            border: InputBorder.none,
            contentPadding:
            const EdgeInsets.symmetric(vertical: 22, horizontal: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildClientTab(List<String> availableServices, bool isWide) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: _buildAdvancedSearchBar(
            controller: _clientSearchController,
            focusNode: _clientFocusNode,
            hintText: 'Rechercher un client ou service...',
            icon: Icons.search_rounded,
            isFocused: _isClientFocused,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: availableServices.map((svc) {
              final selected = _selectedServices.contains(svc);
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: FilterChip(
                  label: Text(svc),
                  labelStyle: GoogleFonts.poppins(
                    color: selected ? kPrimaryColor : kTextSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  selected: selected,
                  onSelected: (on) {
                    setState(() {
                      if (on)
                        _selectedServices.add(svc);
                      else
                        _selectedServices.remove(svc);
                    });
                  },
                  backgroundColor: kCardColor,
                  selectedColor: kPrimaryColor.withOpacity(0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: selected
                          ? kPrimaryColor
                          : kTextSecondary.withOpacity(0.2),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('clients')
                .orderBy('name')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: kPrimaryColor));
              }
              // ✅ Updated to use _matchesClient which now checks for Archived status
              final docs = snapshot.data?.docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                return _matchesClient(data);
              }).toList() ?? [];

              if (docs.isEmpty) {
                return _buildNoResultsCard();
              }

              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: isWide
                    ? _buildClientGrid(docs)
                    : _buildClientList(docs),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildClientList(List<QueryDocumentSnapshot> docs) {
    return ListView.builder(
      key: const ValueKey('client_list'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: docs.length,
      itemBuilder: (context, i) {
        final doc = docs[i];
        final data = doc.data() as Map<String, dynamic>;

        // ✅ ADDED SLIDABLE (SWIPE)
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Slidable(
            key: Key(doc.id),
            // Swipe RIGHT -> DELETE
            startActionPane: ActionPane(
              motion: const ScrollMotion(),
              children: [
                SlidableAction(
                  onPressed: (context) => _deleteClient(context, doc),
                  backgroundColor: Colors.red.shade100,
                  foregroundColor: Colors.red.shade900,
                  icon: Icons.delete_forever,
                  label: 'Supprimer',
                  borderRadius: BorderRadius.circular(24),
                ),
              ],
            ),
            // Swipe LEFT -> ARCHIVE
            endActionPane: ActionPane(
              motion: const ScrollMotion(),
              children: [
                SlidableAction(
                  onPressed: (context) => _archiveClient(context, doc),
                  backgroundColor: Colors.orange.shade100,
                  foregroundColor: Colors.orange.shade900,
                  icon: Icons.archive,
                  label: 'Archiver',
                  borderRadius: BorderRadius.circular(24),
                ),
              ],
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 400 + (i * 50)),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 30 * (1 - value)),
                  child: Opacity(opacity: value, child: child),
                );
              },
              child: _buildClientCard(doc, data),
            ),
          ),
        );
      },
    );
  }

  Widget _buildClientGrid(List<QueryDocumentSnapshot> docs) {
    return GridView.builder(
      key: const ValueKey('client_grid'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3.5,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: docs.length,
      itemBuilder: (context, i) {
        final doc = docs[i];
        final data = doc.data() as Map<String, dynamic>;

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 400 + (i * 50)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.9 + (0.1 * value),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: _buildClientCard(doc, data),
        );
      },
    );
  }

  Widget _buildClientCard(DocumentSnapshot doc, Map<String, dynamic> data) {
    final name = data['name'] as String? ?? '';
    final services = List<String>.from(data['services'] ?? []);

    return Container(
      // Margin handled by ListView padding/Slidable now for list, Grid for grid
      // Keeping internal decoration
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      ManageStoresPage(clientId: doc.id, clientName: name),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _getAvatarColor(name).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: CircleAvatar(
                        backgroundColor: _getAvatarColor(name),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHighlightText(
                            name,
                            _clientSearchQuery,
                            GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: kTextPrimary,
                              fontSize: 16,
                            ),
                            GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              color: kPrimaryColor,
                              fontSize: 16,
                              backgroundColor: kPrimaryColor.withOpacity(0.15),
                            ),
                          ),

                          if (data['nif'] != null || data['rc'] != null)
                            Padding(
                              padding:
                              const EdgeInsets.only(top: 2.0, bottom: 2.0),
                              child: Text(
                                "NIF: ${data['nif'] ?? '-'} | RC: ${data['rc'] ?? '-'}",
                                style: GoogleFonts.poppins(
                                  color: kTextSecondary,
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                          if (services.isNotEmpty)
                            Text(
                              'Services: ${services.join(', ')}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: kTextSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf_rounded,
                              color: kPrimaryColor),
                          tooltip: "Générer Rapport Global",
                          onPressed: () => _handleGenerateReport(doc.id, name),
                        ),

                        IconButton(
                          icon: Icon(Icons.edit_outlined,
                              color: kAccentColor.withOpacity(0.8)),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AddClientPage(
                                clientId: doc.id,
                                initialData: data,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: kPrimaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_forward_ios,
                              size: 14, color: kPrimaryColor),
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

  Widget _buildStoreTab(bool isWide) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: _buildAdvancedSearchBar(
            controller: _storeSearchController,
            focusNode: _storeFocusNode,
            hintText: 'Rechercher un magasin ou lieu...',
            icon: Icons.storefront_rounded,
            isFocused: _isStoreFocused,
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collectionGroup('stores')
                .orderBy('name')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: kPrimaryColor));
              }
              final docs = snapshot.data?.docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                return _matchesStore(data);
              }).toList() ?? [];

              if (docs.isEmpty) {
                return _buildNoResultsCard();
              }

              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: isWide
                    ? _buildStoreGrid(docs)
                    : _buildStoreList(docs),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStoreList(List<QueryDocumentSnapshot> docs) {
    return ListView.builder(
      key: const ValueKey('store_list'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      itemCount: docs.length,
      itemBuilder: (context, i) {
        final doc = docs[i];
        final data = doc.data() as Map<String, dynamic>;

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 400 + (i * 50)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 30 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: _buildStoreCard(doc, data),
        );
      },
    );
  }

  Widget _buildStoreGrid(List<QueryDocumentSnapshot> docs) {
    return GridView.builder(
      key: const ValueKey('store_grid'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3.5,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: docs.length,
      itemBuilder: (context, i) {
        final doc = docs[i];
        final data = doc.data() as Map<String, dynamic>;

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 400 + (i * 50)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.9 + (0.1 * value),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: _buildStoreCard(doc, data),
        );
      },
    );
  }

  Widget _buildStoreCard(DocumentSnapshot doc, Map<String, dynamic> data) {
    final name = data['name'] as String? ?? '';
    final location = data['location'] as String? ?? '';
    final clientId = doc.reference.parent.parent?.id;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: clientId != null
                  ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ManageStoresPage(
                    clientId: clientId,
                    clientName: '',
                  ),
                ),
              )
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _getAvatarColor(name).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: CircleAvatar(
                        backgroundColor: _getAvatarColor(name),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHighlightText(
                            name,
                            _storeSearchQuery,
                            GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: kTextPrimary,
                              fontSize: 16,
                            ),
                            GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              color: kPrimaryColor,
                              fontSize: 16,
                              backgroundColor: kPrimaryColor.withOpacity(0.15),
                            ),
                          ),
                          if (location.isNotEmpty)
                            _buildHighlightText(
                              'Lieu: $location',
                              _storeSearchQuery,
                              GoogleFonts.poppins(
                                color: kTextSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              GoogleFonts.poppins(
                                color: kPrimaryColor.withOpacity(0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                backgroundColor: kPrimaryColor.withOpacity(0.1),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (clientId != null)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_forward_ios,
                            size: 14, color: kPrimaryColor),
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

  Widget _buildAnimatedFab() {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      offset: _tabController.index == 0 ? Offset.zero : const Offset(0, 2),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _tabController.index == 0 ? 1.0 : 0.0,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [kPrimaryColor, kAccentColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: kPrimaryColor.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: FloatingActionButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddClientPage()),
            ),
            tooltip: 'Ajouter un client',
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            child: const Icon(Icons.add_rounded, size: 30),
          ),
        ),
      ),
    );
  }

  Widget _buildNoResultsCard() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: kPrimaryColor.withOpacity(0.07),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: kPrimaryColor.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun résultat',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Essayez de modifier vos termes de recherche.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: kTextSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _normalize(String s) {
    const diacritics =
        'ÀÁÂÃÄÅàáâãäåÒÓÔÕÖØòóôõöøÈÉÊËèéêëÇçÌÍÎÏìíîïÙÚÛÜùúûüÿÑñ';
    const nonDiacritics =
        'AAAAAAaaaaaaOOOOOOooooooEEEEeeeeCcIIIIiiiiUUUUuuuuuyNn';

    String normalized = s;
    for (int i = 0; i < diacritics.length; i++) {
      normalized = normalized.replaceAll(diacritics[i], nonDiacritics[i]);
    }
    return normalized.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Widget _buildHighlightText(
      String text,
      String query,
      TextStyle defaultStyle,
      TextStyle highlightStyle,
      ) {
    if (query.isEmpty) {
      return Text(text,
          style: defaultStyle, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    final normalizedText = _normalize(text);
    final queryTokens =
    _normalize(query).split(' ').where((t) => t.isNotEmpty).toList();

    if (queryTokens.isEmpty) {
      return Text(text,
          style: defaultStyle, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    List<TextSpan> spans = [];
    int start = 0;

    List<List<int>> allMatches = [];
    for (final token in queryTokens) {
      int index = normalizedText.indexOf(token, 0);
      while (index != -1) {
        allMatches.add([index, index + token.length]);
        index = normalizedText.indexOf(token, index + 1);
      }
    }

    if (allMatches.isEmpty) {
      return Text(text,
          style: defaultStyle, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    allMatches.sort((a, b) => a[0].compareTo(b[0]));
    List<List<int>> mergedMatches = [];
    if (allMatches.isNotEmpty) {
      mergedMatches.add(allMatches[0]);
      for (var i = 1; i < allMatches.length; i++) {
        List<int> current = allMatches[i];
        List<int> last = mergedMatches.last;
        if (current[0] <= last[1]) {
          last[1] = current[1] > last[1] ? current[1] : last[1];
        } else {
          mergedMatches.add(current);
        }
      }
    }

    for (final match in mergedMatches) {
      if (match[0] > start) {
        spans.add(TextSpan(
            text: text.substring(start, match[0]), style: defaultStyle));
      }
      final int end = match[1] < text.length ? match[1] : text.length;
      if (match[0] < end) {
        spans.add(TextSpan(
            text: text.substring(match[0], end), style: highlightStyle));
      }
      start = end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: defaultStyle));
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}