// lib/screens/administration/add_project_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart'; // ✅ PREMIUM UI ADDITION

// ----------------------------------------------------------------------
// 📦 LOCAL DATA MODELS
// ----------------------------------------------------------------------

class Client {
  final String id;
  final String name;
  Client({required this.id, required this.name});

  @override
  bool operator ==(Object other) => other is Client && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

class Store {
  final String id;
  final String name;
  final String location;
  Store({required this.id, required this.name, required this.location});

  @override
  bool operator ==(Object other) => other is Store && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

// ----------------------------------------------------------------------
// 🎨 THEME CONSTANTS (4K Premium 2026 Vibe)
// ----------------------------------------------------------------------
const Color kPrimaryColor = Color(0xFF4F46E5); // Indigo 600
const Color kPrimaryDark = Color(0xFF3730A3); // Indigo 800
const Color kBackgroundColor = Color(0xFFF5F7FA); // Modern Slate 50
const Color kSurfaceColor = Colors.white;
const Color kTextPrimary = Color(0xFF1E293B); // Slate 800
const Color kTextSecondary = Color(0xFF64748B); // Slate 500
const double kRadius = 24.0; // Premium 24px radius

class AddProjectPage extends StatefulWidget {
  const AddProjectPage({super.key});

  @override
  State<AddProjectPage> createState() => _AddProjectPageState();
}

class _AddProjectPageState extends State<AddProjectPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _requestController = TextEditingController();
  final _clientPhoneController = TextEditingController();
  final _clientSearchController = TextEditingController();
  final _storeSearchController = TextEditingController();

  // Controllers for Add Dialogs
  final _newClientNameController = TextEditingController();
  final _newStoreNameController = TextEditingController();
  final _newStoreLocationController = TextEditingController();

  // Data State
  Client? _selectedClient;
  Store? _selectedStore;
  List<Client> _clients = [];
  List<Store> _stores = [];

  // Project specific state
  bool _hasTechniqueModule = false;
  bool _hasItModule = false;

  // UI State
  bool _isLoading = false;
  bool _isFetchingClients = false;
  bool _isFetchingStores = false;

  @override
  void initState() {
    super.initState();
    _fetchClients();
  }

  @override
  void dispose() {
    _requestController.dispose();
    _clientPhoneController.dispose();
    _clientSearchController.dispose();
    _storeSearchController.dispose();
    _newClientNameController.dispose();
    _newStoreNameController.dispose();
    _newStoreLocationController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------------
  // ⚙️ LOGIC METHODS (PRESERVED)
  // ----------------------------------------------------------------------

  Future<void> _fetchClients() async {
    setState(() => _isFetchingClients = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('clients').orderBy('name').get();
      _clients = snapshot.docs.map((doc) {
        return Client(id: doc.id, name: doc.data()['name'] ?? 'N/A');
      }).toList();
    } catch (e) {
      debugPrint('Error fetching clients: $e');
    } finally {
      if (mounted) setState(() => _isFetchingClients = false);
    }
  }

  Future<void> _fetchStores(String clientId) async {
    setState(() {
      _isFetchingStores = true;
      _selectedStore = null;
      _storeSearchController.clear();
      _stores = [];
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('clients')
          .doc(clientId)
          .collection('stores')
          .orderBy('name')
          .get();
      _stores = snapshot.docs.map((doc) {
        final data = doc.data();
        return Store(
          id: doc.id,
          name: data['name'] ?? 'N/A',
          location: data['location'] ?? 'N/A',
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching stores: $e');
    } finally {
      if (mounted) setState(() => _isFetchingStores = false);
    }
  }

  Future<void> _saveProject() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedClient == null || _selectedStore == null) {
      _showSnack('Veuillez sélectionner un client et un magasin.', Colors.redAccent);
      return;
    }

    if (!_hasTechniqueModule && !_hasItModule) {
      _showSnack('Veuillez sélectionner au moins un module (Technique ou IT).', Colors.redAccent);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user?.uid).get();
      final createdByName = userDoc.data()?['displayName'] ?? 'N/A';

      String serviceType = '';
      if (_hasTechniqueModule && _hasItModule) {
        serviceType = 'Service Technique & IT';
      } else if (_hasTechniqueModule) {
        serviceType = 'Service Technique';
      } else if (_hasItModule) {
        serviceType = 'Service IT';
      }

      await FirebaseFirestore.instance.collection('projects').add({
        'clientName': _selectedClient!.name,
        'clientId': _selectedClient!.id,
        'storeName': _selectedStore!.name,
        'storeId': _selectedStore!.id,
        'storeLocation': _selectedStore!.location,
        'hasTechniqueModule': _hasTechniqueModule,
        'hasItModule': _hasItModule,
        'serviceType': serviceType,
        'initialRequest': _requestController.text.trim(),
        'clientPhone': _clientPhoneController.text.trim(),
        'status': 'Nouvelle Demande',
        'createdAt': FieldValue.serverTimestamp(),
        'createdByUid': user?.uid,
        'createdByName': createdByName,
      });

      if (mounted) {
        _showSnack('Projet créé avec succès!', kPrimaryColor);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Erreur lors de la création: $e', Colors.redAccent);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // --- Add Dialogs ---

  Future<void> _showAddClientDialog() async {
    _newClientNameController.clear();
    await _showGenericDialog("Ajouter un Client", "Nom du Client", _newClientNameController, () async {
      final docRef = await FirebaseFirestore.instance.collection('clients').add({
        'name': _newClientNameController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      final newClient = Client(id: docRef.id, name: _newClientNameController.text.trim());
      await _fetchClients();
      setState(() {
        _selectedClient = newClient;
        _clientSearchController.text = newClient.name;
        _fetchStores(newClient.id);
      });
    });
  }

  Future<void> _showAddStoreDialog() async {
    if (_selectedClient == null) return;
    _newStoreNameController.clear();
    _newStoreLocationController.clear();

    await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
          title: Text("Ajouter Magasin", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _newStoreNameController,
                decoration: _inputDecoration("Nom du Magasin", Icons.storefront_rounded),
                style: GoogleFonts.inter(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newStoreLocationController,
                decoration: _inputDecoration("Ville / Localisation", Icons.location_city_rounded),
                style: GoogleFonts.inter(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Annuler", style: GoogleFonts.inter(color: kTextSecondary))),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () async {
                  if(_newStoreNameController.text.isEmpty) return;
                  await FirebaseFirestore.instance.collection('clients').doc(_selectedClient!.id).collection('stores').add({
                    'name': _newStoreNameController.text.trim(),
                    'location': _newStoreLocationController.text.trim(),
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  await _fetchStores(_selectedClient!.id);
                  Navigator.pop(ctx);
                }, child: Text("Enregistrer", style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
          ],
        )
    );
  }

  Future<void> _showGenericDialog(String title, String label, TextEditingController controller, Function onSave) async {
    final formKey = GlobalKey<FormState>();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            style: GoogleFonts.inter(),
            decoration: _inputDecoration(label, Icons.edit_rounded),
            validator: (v) => v!.isEmpty ? 'Requis' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Annuler', style: GoogleFonts.inter(color: kTextSecondary))),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await onSave();
                Navigator.of(ctx).pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text('Enregistrer', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------------
  // 🖥️ UI BUILDER
  // ----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: kSurfaceColor,
        foregroundColor: kTextPrimary,
        centerTitle: true,
        title: Text(
          'Créer un Projet',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.black.withOpacity(0.05), height: 1),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle("Informations Client", Icons.business_rounded),
              _buildClientCard(),

              const SizedBox(height: 24),
              _buildSectionTitle("Modules du Projet", Icons.extension_rounded),
              _buildModulesCard(),

              const SizedBox(height: 24),
              _buildSectionTitle("Détails de la Demande", Icons.assignment_rounded),
              _buildDetailsCard(),

              const SizedBox(height: 40),
              _buildSaveButton(),
              const SizedBox(height: 60), // Extra scroll space
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 8),
      child: Row(
        children: [
          Icon(icon, color: kPrimaryColor, size: 20),
          const SizedBox(width: 10),
          Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: kTextPrimary)),
        ],
      ),
    );
  }

  Widget _buildClientCard() {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildModernSelect<Client>(
            label: "Client",
            hint: "Rechercher un client...",
            items: _clients,
            selectedItem: _selectedClient,
            isLoading: _isFetchingClients,
            onSelected: (c) {
              setState(() {
                _selectedClient = c;
                _clientSearchController.text = c.name;
                _fetchStores(c.id);
              });
            },
            onAdd: _showAddClientDialog,
            itemLabel: (c) => c.name,
          ),

          const SizedBox(height: 20),

          _buildModernSelect<Store>(
            label: "Magasin",
            hint: "Sélectionner un magasin...",
            items: _stores,
            selectedItem: _selectedStore,
            isLoading: _isFetchingStores,
            enabled: _selectedClient != null,
            onSelected: (s) {
              setState(() {
                _selectedStore = s;
                _storeSearchController.text = '${s.name} (${s.location})';
              });
            },
            onAdd: _showAddStoreDialog,
            itemLabel: (s) => "${s.name} (${s.location})",
          ),
        ],
      ),
    );
  }

  Widget _buildModernSelect<T>({
    required String label,
    required String hint,
    required List<T> items,
    required T? selectedItem,
    required Function(T) onSelected,
    required Function() onAdd,
    required String Function(T) itemLabel,
    bool isLoading = false,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: (enabled && !isLoading) ? () {
                  _showSearchableBottomSheet(
                    title: "Sélectionner $label",
                    items: items,
                    itemLabel: itemLabel,
                    onSelected: onSelected,
                  );
                } : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    color: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black.withOpacity(0.04)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                          label == "Client" ? Icons.business_rounded : Icons.storefront_rounded,
                          color: enabled ? kTextSecondary : Colors.grey.shade400,
                          size: 20
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          selectedItem != null ? itemLabel(selectedItem) : hint,
                          style: GoogleFonts.inter(
                              color: selectedItem != null ? kTextPrimary : kTextSecondary,
                              fontWeight: selectedItem != null ? FontWeight.w600 : FontWeight.normal,
                              fontSize: 15
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isLoading)
                        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      else
                        Icon(Icons.keyboard_arrow_down_rounded, color: enabled ? kTextSecondary : Colors.grey.shade300),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: enabled ? onAdd : null,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: enabled ? kPrimaryColor.withOpacity(0.1) : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.add_rounded, color: enabled ? kPrimaryColor : Colors.grey, size: 22),
              ),
            )
          ],
        ),
      ],
    );
  }

  Future<void> _showSearchableBottomSheet<T>({
    required String title,
    required List<T> items,
    required String Function(T) itemLabel,
    required Function(T) onSelected,
  }) {
    return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) {
          return _SearchableListSheet<T>(
              title: title,
              items: items,
              itemLabel: itemLabel,
              onSelected: onSelected
          );
        }
    );
  }

  Widget _buildModulesCard() {
    return Column(
      children: [
        _buildModuleToggle(
          title: "Service Technique",
          subtitle: "Antivols, caméras, comptage, etc.",
          icon: Icons.engineering_rounded,
          value: _hasTechniqueModule,
          activeColor: const Color(0xFF4F46E5), // Indigo
          onChanged: (val) => setState(() => _hasTechniqueModule = val),
        ),
        const SizedBox(height: 12),
        _buildModuleToggle(
          title: "Service IT",
          subtitle: "Réseau, TPV, bornes, affichage.",
          icon: Icons.router_rounded,
          value: _hasItModule,
          activeColor: const Color(0xFF0EA5E9), // Sky Blue
          onChanged: (val) => setState(() => _hasItModule = val),
        ),
      ],
    );
  }

  Widget _buildModuleToggle({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Color activeColor,
    required Function(bool) onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: value ? activeColor.withOpacity(0.05) : kSurfaceColor,
          borderRadius: BorderRadius.circular(kRadius),
          border: Border.all(
            color: value ? activeColor.withOpacity(0.5) : Colors.black.withOpacity(0.05),
            width: value ? 1.5 : 1,
          ),
          boxShadow: value ? [] : [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: value ? activeColor : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: value ? Colors.white : kTextSecondary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: value ? activeColor : kTextPrimary)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: GoogleFonts.inter(color: kTextSecondary, fontSize: 13)),
                ],
              ),
            ),
            Switch(
              value: value,
              activeColor: activeColor,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          TextFormField(
            controller: _clientPhoneController,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.inter(),
            decoration: _inputDecoration("Téléphone du Client (optionnel)", Icons.phone_rounded),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _requestController,
            maxLines: 5,
            style: GoogleFonts.inter(height: 1.5),
            decoration: _inputDecoration("Description de la Demande", Icons.description_rounded).copyWith(
              alignLabelWithHint: true,
            ),
            validator: (v) => v!.isEmpty ? 'Veuillez décrire la demande' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveProject,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
          shadowColor: kPrimaryColor.withOpacity(0.4),
        ),
        child: _isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
            : Text(
          "Créer le Projet",
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // --- STYLING HELPERS ---

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: kSurfaceColor,
      borderRadius: BorderRadius.circular(kRadius),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 8)),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: kTextSecondary, size: 20),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: kPrimaryColor, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      labelStyle: GoogleFonts.inter(color: kTextSecondary),
    );
  }
}

// ----------------------------------------------------------------------
// 🔎 SEARCHABLE SHEET WIDGET (Premium Style)
// ----------------------------------------------------------------------

class _SearchableListSheet<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final String Function(T) itemLabel;
  final Function(T) onSelected;

  const _SearchableListSheet({
    required this.title,
    required this.items,
    required this.itemLabel,
    required this.onSelected,
  });

  @override
  State<_SearchableListSheet<T>> createState() => _SearchableListSheetState<T>();
}

class _SearchableListSheetState<T> extends State<_SearchableListSheet<T>> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final filteredItems = widget.items.where((item) {
      final label = widget.itemLabel(item).toLowerCase();
      return label.contains(_searchQuery.toLowerCase());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7, // 70% height
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Handle Bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          Text(widget.title, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: kTextPrimary)),
          const SizedBox(height: 24),

          // Search Bar
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            style: GoogleFonts.inter(),
            decoration: InputDecoration(
              hintText: "Rechercher...",
              hintStyle: GoogleFonts.inter(color: kTextSecondary),
              prefixIcon: const Icon(Icons.search_rounded, color: kTextSecondary),
              filled: true,
              fillColor: kBackgroundColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 16),

          // List
          Expanded(
            child: filteredItems.isEmpty
                ? Center(child: Text("Aucun résultat", style: GoogleFonts.inter(color: kTextSecondary)))
                : ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: filteredItems.length,
              separatorBuilder: (_,__) => Divider(height: 1, color: Colors.black.withOpacity(0.05)),
              itemBuilder: (context, index) {
                final item = filteredItems[index];
                return ListTile(
                  title: Text(widget.itemLabel(item), style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: kTextPrimary)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  onTap: () {
                    widget.onSelected(item);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}