// lib/screens/administration/add_livraison_page.dart

import 'dart:ui';
import 'dart:typed_data';
import 'package:boitex_info_app/models/selection_models.dart';
import 'package:boitex_info_app/screens/administration/global_product_search_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:developer';

import 'package:multi_select_flutter/multi_select_flutter.dart';

import 'package:boitex_info_app/services/livraison_pdf_service.dart';
// ✅ ADDED: Import for the Image Gallery
import 'package:boitex_info_app/widgets/image_gallery_page.dart';

class AddLivraisonPage extends StatefulWidget {
  final String? serviceType;
  final String? livraisonId;

  const AddLivraisonPage({super.key, this.serviceType, this.livraisonId});

  @override
  State<AddLivraisonPage> createState() => _AddLivraisonPageState();
}

class _AddLivraisonPageState extends State<AddLivraisonPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  String _deliveryMethod = 'Livraison Interne';
  SelectableItem? _selectedClient;
  SelectableItem? _selectedStore;
  List<ProductSelection> _selectedProducts = [];
  String? _selectedServiceType;

  List<SelectableItem> _selectedTechnicians = [];

  // ✅ ADDED: Image Cache Map
  final Map<String, List<String>> _productImagesCache = {};

  final _internalDeliveryAddressController = TextEditingController();
  final _externalCarrierNameController = TextEditingController();
  final _externalClientNameController = TextEditingController();
  final _externalClientPhoneController = TextEditingController();
  final _externalClientAddressController = TextEditingController();
  final _codAmountController = TextEditingController();

  List<SelectableItem> _clients = [];
  List<SelectableItem> _stores = [];
  List<SelectableItem> _technicians = [];

  bool _isLoadingClients = true;
  bool _isLoadingStores = false;
  bool _isLoadingTechnicians = true;
  bool _isLoadingPage = false;
  String? _clientError;

  bool _isUploading = false;
  String _loadingStatus = '';
  String _currentStatus = 'À Préparer';

  bool get _isEditMode => widget.livraisonId != null;

  late AnimationController _bgAnimationController;

  @override
  void initState() {
    super.initState();
    _selectedServiceType = widget.serviceType;
    if (_isEditMode) {
      _loadLivraisonData();
    }
    _fetchClients();
    _fetchTechnicians();

    _bgAnimationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    _internalDeliveryAddressController.dispose();
    _externalCarrierNameController.dispose();
    _externalClientNameController.dispose();
    _externalClientPhoneController.dispose();
    _externalClientAddressController.dispose();
    _codAmountController.dispose();
    super.dispose();
  }

  // --- DATA FETCHING & LOGIC ---

  // ✅ ADDED: Function to fetch a single product's images
  Future<void> _fetchSingleProductImage(String? productId) async {
    if (productId == null || _productImagesCache.containsKey(productId)) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('produits').doc(productId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['imageUrls'] != null) {
          final List<dynamic> urls = data['imageUrls'];
          if (mounted) {
            setState(() {
              _productImagesCache[productId] = urls.map((e) => e.toString()).toList();
            });
          }
        } else {
          if (mounted) setState(() => _productImagesCache[productId] = []);
        }
      }
    } catch (e) {
      debugPrint("Error fetching image for $productId: $e");
    }
  }

  Future<void> _loadLivraisonData() async {
    setState(() => _isLoadingPage = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('livraisons').doc(widget.livraisonId!).get();

      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur: Livraison non trouvée.'), backgroundColor: Colors.red));
          Navigator.pop(context);
        }
        return;
      }

      final data = doc.data() as Map<String, dynamic>;

      _currentStatus = data['status'] ?? 'À Préparer';
      _selectedServiceType = data['serviceType'];
      _deliveryMethod = data['deliveryMethod'] ?? 'Livraison Interne';
      _internalDeliveryAddressController.text = data['deliveryAddress'] ?? '';
      _externalCarrierNameController.text = data['externalCarrierName'] ?? '';
      _externalClientNameController.text = data['externalClientName'] ?? '';
      _externalClientPhoneController.text = data['externalClientPhone'] ?? '';
      _externalClientAddressController.text = data['externalClientAddress'] ?? '';
      _codAmountController.text = data['codAmount']?.toString() ?? '';

      if (data['clientId'] != null && data['clientName'] != null) {
        _selectedClient = SelectableItem(id: data['clientId'], name: data['clientName']);
        await _fetchStores(data['clientId']);
      }

      if (data['storeId'] != null) {
        final storeExists = _stores.any((store) => store.id == data['storeId']);
        if (storeExists) {
          _selectedStore = _stores.firstWhere((store) => store.id == data['storeId']);
        }
      }

      if (data['technicians'] != null && data['technicians'] is List) {
        final techList = data['technicians'] as List;
        _selectedTechnicians = techList.map((t) => SelectableItem(id: t['id'], name: t['name'])).toList();
      } else if (data['technicianId'] != null && data['technicianName'] != null) {
        _selectedTechnicians = [SelectableItem(id: data['technicianId'], name: data['technicianName'])];
      }

      if (data['products'] is List) {
        _selectedProducts = (data['products'] as List).map((p) => ProductSelection.fromJson(p as Map<String, dynamic>)).toList();
        // ✅ ADDED: Fetch images for all existing loaded products
        for (var product in _selectedProducts) {
          _fetchSingleProductImage(product.productId);
        }
      }

      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoadingPage = false);
    }
  }

  Future<void> _fetchClients() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    setState(() => _isLoadingClients = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('clients').get();
      final clients = snapshot.docs.map((doc) => SelectableItem(id: doc.id, name: doc['name'] as String)).toList();
      clients.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (mounted) setState(() => _clients = clients);
    } catch (e) {
      if (mounted) setState(() => _clientError = "Erreur: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoadingClients = false);
    }
  }

  Future<void> _fetchStores(String clientId) async {
    setState(() { _isLoadingStores = true; _selectedStore = null; _stores = []; });
    try {
      final snapshot = await FirebaseFirestore.instance.collection('clients').doc(clientId).collection('stores').get();
      final stores = snapshot.docs.map((doc) {
        final data = doc.data();
        final location = data.containsKey('location') ? data['location'] : '';
        return SelectableItem(id: doc.id, name: data['name'] as String, data: {'location': location});
      }).toList();
      if (mounted) setState(() => _stores = stores);
    } catch (e) {
      print('Error fetching stores: $e');
    } finally {
      if (mounted) setState(() => _isLoadingStores = false);
    }
  }

  Future<void> _fetchTechnicians() async {
    setState(() => _isLoadingTechnicians = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      final technicians = snapshot.docs.map((doc) => SelectableItem(id: doc.id, name: doc['displayName'] as String? ?? doc.id)).toList();
      if (mounted) setState(() => _technicians = technicians);
    } catch (e) {
      print('Error fetching technicians: $e');
    } finally {
      if (mounted) setState(() => _isLoadingTechnicians = false);
    }
  }

  // ===========================================================================
  // 🌟 ULTRA PREMIUM 4K DIALOGS (Fixed Overflows)
  // ===========================================================================

  InputDecoration _dialogInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(color: Colors.black54),
      filled: true,
      fillColor: Colors.white.withOpacity(0.6),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.8), width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.blueAccent, width: 2)),
    );
  }

  Future<void> _openCustomSelectDialog<T>({
    required String title,
    required List<T> items,
    required T? currentValue,
    required Function(T) onSelected,
  }) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              width: double.maxFinite,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.75),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 15))],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87), textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const BouncingScrollPhysics(),
                            itemCount: items.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.black.withOpacity(0.05)),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final isSelected = item == currentValue;
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    onSelected(item);
                                    Navigator.pop(context);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.toString(),
                                            style: GoogleFonts.inter(
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                              fontSize: 16,
                                              color: isSelected ? Colors.blueAccent.shade700 : Colors.black87,
                                            ),
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(Icons.check_circle_rounded, color: Colors.blueAccent, size: 24),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          backgroundColor: Colors.white.withOpacity(0.6),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text("Annuler", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 16)),
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

  Future<void> _openCustomMultiSelectDialog({
    required String title,
    required List<SelectableItem> items,
    required List<SelectableItem> currentSelections,
    required Function(List<SelectableItem>) onConfirm,
  }) async {
    List<SelectableItem> tempSelections = List.from(currentSelections);

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Container(
                  width: double.maxFinite,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 15))],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87), textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const BouncingScrollPhysics(),
                                itemCount: items.length,
                                separatorBuilder: (_, __) => Divider(height: 1, color: Colors.black.withOpacity(0.05)),
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  final isSelected = tempSelections.any((s) => s.id == item.id);
                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        setStateSB(() {
                                          if (isSelected) {
                                            tempSelections.removeWhere((s) => s.id == item.id);
                                          } else {
                                            tempSelections.add(item);
                                          }
                                        });
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.name,
                                                style: GoogleFonts.inter(
                                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                                  fontSize: 16,
                                                  color: isSelected ? Colors.blueAccent.shade700 : Colors.black87,
                                                ),
                                              ),
                                            ),
                                            AnimatedContainer(
                                              duration: const Duration(milliseconds: 200),
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isSelected ? Colors.blueAccent : Colors.transparent,
                                                border: Border.all(
                                                  color: isSelected ? Colors.blueAccent : Colors.black26,
                                                  width: 2,
                                                ),
                                              ),
                                              child: isSelected
                                                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                                                  : null,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  backgroundColor: Colors.white.withOpacity(0.6),
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: Text("Annuler", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 16)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: Colors.blueAccent,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: () {
                                  onConfirm(tempSelections);
                                  Navigator.pop(context);
                                },
                                child: Text("Valider", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addNewClient() async {
    final TextEditingController nameController = TextEditingController();
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, 10))],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Créer un Client', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87), textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                    decoration: _dialogInputDecoration('Nom du client'),
                    textCapitalization: TextCapitalization.words,
                    autofocus: true,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Annuler', style: GoogleFonts.inter(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () async {
                          final name = nameController.text.trim();
                          if (name.isNotEmpty) {
                            try {
                              final ref = await FirebaseFirestore.instance.collection('clients').add({
                                'name': name,
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                              final newItem = SelectableItem(id: ref.id, name: name);
                              setState(() {
                                _clients.add(newItem);
                                _clients.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                                _selectedClient = newItem;
                                _selectedStore = null;
                                _stores = [];
                                _internalDeliveryAddressController.clear();
                              });
                              Navigator.pop(context);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                            }
                          }
                        },
                        child: Text('Ajouter', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addNewStore() async {
    if (_selectedClient == null) return;
    final TextEditingController nameController = TextEditingController();
    final TextEditingController addressController = TextEditingController();

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, 10))],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Créer une Agence', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87), textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                    decoration: _dialogInputDecoration('Nom du magasin'),
                    textCapitalization: TextCapitalization.words,
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressController,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                    decoration: _dialogInputDecoration('Adresse / Localisation'),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Annuler', style: GoogleFonts.inter(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () async {
                          final name = nameController.text.trim();
                          final address = addressController.text.trim();
                          if (name.isNotEmpty) {
                            try {
                              final ref = await FirebaseFirestore.instance
                                  .collection('clients')
                                  .doc(_selectedClient!.id)
                                  .collection('stores')
                                  .add({'name': name, 'location': address, 'createdAt': FieldValue.serverTimestamp()});
                              final newItem = SelectableItem(id: ref.id, name: name, data: {'location': address});
                              setState(() {
                                _stores.add(newItem);
                                _selectedStore = newItem;
                                _internalDeliveryAddressController.text = address;
                              });
                              Navigator.pop(context);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                            }
                          }
                        },
                        child: Text('Ajouter', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openSearchDialog({
    required String title,
    required List<SelectableItem> items,
    required Function(SelectableItem) onSelected,
    required VoidCallback onAddPressed,
    required String addButtonLabel,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (BuildContext context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setStateSB) {
            final filteredItems = items.where((item) {
              final nameLower = item.name.toLowerCase();
              final queryLower = searchQuery.toLowerCase();
              return nameLower.contains(queryLower);
            }).toList();

            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Container(
                  width: double.maxFinite,
                  padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 15))],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87), textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        TextField(
                          autofocus: true,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 16),
                          decoration: InputDecoration(
                            hintText: 'Rechercher...',
                            hintStyle: GoogleFonts.inter(color: Colors.black45),
                            prefixIcon: const Icon(Icons.search_rounded, color: Colors.blueAccent),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.8),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                          ),
                          onChanged: (val) => setStateSB(() => searchQuery = val),
                        ),
                        const SizedBox(height: 16),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const BouncingScrollPhysics(),
                                itemCount: filteredItems.length + 1,
                                separatorBuilder: (_, __) => Divider(height: 1, color: Colors.black.withOpacity(0.05)),
                                itemBuilder: (context, index) {
                                  if (index == filteredItems.length) {
                                    return Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () { Navigator.pop(context); onAddPressed(); },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.add_circle_rounded, color: Colors.blueAccent, size: 24),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(addButtonLabel, style: GoogleFonts.inter(color: Colors.blueAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  final item = filteredItems[index];
                                  final subtitle = item.data != null && item.data!.containsKey('location') ? item.data!['location'] : null;
                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () { onSelected(item); Navigator.pop(context); },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 20),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(item.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87)),
                                            if (subtitle != null && subtitle.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(Icons.location_on, size: 14, color: Colors.black45),
                                                  const SizedBox(width: 4),
                                                  Expanded(child: Text(subtitle, style: GoogleFonts.inter(fontSize: 13, color: Colors.black54))),
                                                ],
                                              ),
                                            ]
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              backgroundColor: Colors.white.withOpacity(0.6),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: Text("Fermer", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 16)),
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
      },
    );
  }

  // ===========================================================================
  // BACKEND LOGIC
  // ===========================================================================

  Future<void> _openQuickSearch() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GlobalProductSearchPage(
          isSelectionMode: true,
          onProductSelected: (Map<String, dynamic> result) {
            setState(() {
              final newSelection = ProductSelection(
                productId: result['productId'],
                productName: result['productName'],
                quantity: result['quantity'] ?? 1,
                partNumber: result['partNumber'] ?? result['reference'],
                marque: result['marque'] ?? 'N/A',
                serialNumbers: [],
                isConsumable: result['isConsumable'] == true,
                isSoftware: result['isSoftware'] == true,
              );
              _selectedProducts.add(newSelection);
              // ✅ ADDED: Fetch the image as soon as the product is added!
              _fetchSingleProductImage(newSelection.productId);
            });
          },
        ),
      ),
    );
  }

  Future<String> _getNextBonLivraisonCode() async {
    final year = DateTime.now().year;
    final counterRef = FirebaseFirestore.instance.collection('counters').doc('livraison_counter_$year');

    final nextNumber = await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);
      if (!snapshot.exists) {
        transaction.set(counterRef, {'count': 1});
        return 1;
      } else {
        final data = snapshot.data();
        final count = data?['count'];
        final lastNumber = (count is num) ? count.toInt() : 0;
        final newNumber = lastNumber + 1;
        transaction.set(counterRef, {'count': newNumber});
        return newNumber;
      }
    });
    return 'BL-$nextNumber/$year';
  }

  Future<void> _saveLivraison() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Veuillez ajouter au moins un produit.', style: GoogleFonts.inter()),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isUploading = true;
      _loadingStatus = 'Sauvegarde en cours...';
    });

    try {
      final livraisonsCollection = FirebaseFirestore.instance.collection('livraisons');
      final docRef = _isEditMode ? livraisonsCollection.doc(widget.livraisonId!) : livraisonsCollection.doc();

      List<String> accessGroups = [];
      if (_selectedServiceType == 'Les Deux') {
        accessGroups = ['Service Technique', 'Service IT'];
      } else if (_selectedServiceType != null) {
        accessGroups = [_selectedServiceType!];
      }

      String statusToSave = _isEditMode ? _currentStatus : 'À Préparer';

      final deliveryData = <String, dynamic>{
        'clientId': _selectedClient!.id,
        'clientName': _selectedClient!.name,
        'storeId': _selectedStore?.id,
        'storeName': _selectedStore?.name,
        'deliveryAddress': _internalDeliveryAddressController.text.isNotEmpty
            ? _internalDeliveryAddressController.text
            : (_selectedStore?.data?['location'] ?? 'Siège Client / N/A'),
        'contactPerson': '',
        'contactPhone': '',
        'products': _selectedProducts.map((p) => p.toJson()).toList(),
        'status': statusToSave,
        'deliveryMethod': _deliveryMethod,
        'technicians': _deliveryMethod == 'Livraison Interne'
            ? _selectedTechnicians.map((t) => {'id': t.id, 'name': t.name}).toList()
            : [],
        'technicianId': _deliveryMethod == 'Livraison Interne' && _selectedTechnicians.isNotEmpty
            ? _selectedTechnicians.first.id : null,
        'technicianName': _deliveryMethod == 'Livraison Interne'
            ? _selectedTechnicians.map((t) => t.name).join(', ') : null,
        'externalCarrierName': _deliveryMethod == 'Livraison Externe' ? _externalCarrierNameController.text : null,
        'externalClientName': _deliveryMethod == 'Livraison Externe' ? _externalClientNameController.text : null,
        'externalClientPhone': _deliveryMethod == 'Livraison Externe' ? _externalClientPhoneController.text : null,
        'externalClientAddress': _deliveryMethod == 'Livraison Externe' ? _externalClientAddressController.text : null,
        'codAmount': _deliveryMethod == 'Livraison Externe' ? double.tryParse(_codAmountController.text) : null,
        'serviceType': _selectedServiceType,
        'accessGroups': accessGroups,
        'lastModifiedBy': user.displayName ?? user.email,
        'lastModifiedAt': FieldValue.serverTimestamp(),
      };

      if (_isEditMode) {
        await docRef.update(deliveryData);
      } else {
        final bonLivraisonCode = await _getNextBonLivraisonCode();
        final createData = {
          ...deliveryData,
          'bonLivraisonCode': bonLivraisonCode,
          'createdBy': user.displayName ?? user.email,
          'createdById': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        };
        await docRef.set(createData);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Livraison sauvegardée avec succès !', style: GoogleFonts.inter()),
          backgroundColor: Colors.greenAccent.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur lors de la sauvegarde: $e', style: GoogleFonts.inter()),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ===========================================================================
  // MAIN UI BUILDER
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.1),
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: Colors.white.withOpacity(0.1)),
          ),
        ),
        title: Text(
          _isEditMode ? 'Modifier la Livraison' : 'Créer une Livraison',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgAnimationController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(const Color(0xFFE2E2FF), const Color(0xFFF0E5FF), _bgAnimationController.value)!,
                      Color.lerp(const Color(0xFFF0E5FF), const Color(0xFFEAF5FF), _bgAnimationController.value)!,
                      Color.lerp(const Color(0xFFEAF5FF), const Color(0xFFE2E2FF), _bgAnimationController.value)!,
                    ],
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: _isLoadingPage
                ? Center(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const CircularProgressIndicator(color: Colors.blueAccent),
                ),
              ),
            )
                : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                  physics: const BouncingScrollPhysics(),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildGlassSection(
                          title: 'Informations Générales',
                          icon: Icons.info_outline_rounded,
                          children: [
                            if (widget.serviceType == null) ...[
                              _buildCustomDropdownField<String>(
                                label: 'Choisir le Service',
                                value: _selectedServiceType,
                                icon: Icons.layers_outlined,
                                onTap: () => _openCustomSelectDialog<String>(
                                  title: 'Sélectionner le Service',
                                  items: ['Service Technique', 'Service IT', 'Les Deux'],
                                  currentValue: _selectedServiceType,
                                  onSelected: (value) {
                                    setState(() {
                                      _selectedServiceType = value;
                                      _technicians = [];
                                      _selectedTechnicians = [];
                                    });
                                    _fetchTechnicians();
                                  },
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                            _buildCustomDropdownField<String>(
                              label: 'Méthode de livraison',
                              value: _deliveryMethod,
                              icon: Icons.local_shipping_outlined,
                              onTap: () => _openCustomSelectDialog<String>(
                                title: 'Méthode de livraison',
                                items: ['Livraison Interne', 'Livraison Externe'],
                                currentValue: _deliveryMethod,
                                onSelected: (value) {
                                  setState(() {
                                    _deliveryMethod = value;
                                    if (_deliveryMethod != 'Livraison Interne') {
                                      _selectedTechnicians = [];
                                    }
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (_deliveryMethod == 'Livraison Interne')
                              _buildGlassMultiSelect()
                            else ...[
                              _buildTextField(
                                controller: _externalCarrierNameController,
                                label: 'Nom du transporteur',
                                icon: Icons.business_outlined,
                                validator: (val) => val == null || val.isEmpty ? 'Requis' : null,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _externalClientNameController,
                                label: 'Client (Destinataire)',
                                icon: Icons.person_outline,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _externalClientPhoneController,
                                label: 'Téléphone',
                                icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _externalClientAddressController,
                                label: 'Adresse',
                                icon: Icons.map_outlined,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _codAmountController,
                                label: 'Montant à Encaisser (DZD)',
                                icon: Icons.payments_outlined,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildGlassSection(
                          title: 'Destination',
                          icon: Icons.location_on_outlined,
                          children: [
                            _buildSearchableDropdown(
                              label: 'Client Principal',
                              value: _selectedClient,
                              icon: Icons.business_center_outlined,
                              onClear: () {
                                setState(() {
                                  _selectedClient = null;
                                  _selectedStore = null;
                                  _stores = [];
                                  _internalDeliveryAddressController.clear();
                                });
                              },
                              onTap: () => _openSearchDialog(
                                title: 'Rechercher un Client',
                                items: _clients,
                                onSelected: (item) {
                                  setState(() {
                                    _selectedClient = item;
                                    _selectedStore = null;
                                    _stores = [];
                                    _internalDeliveryAddressController.clear();
                                  });
                                  _fetchStores(item.id);
                                },
                                onAddPressed: _addNewClient,
                                addButtonLabel: 'Créer un Client',
                              ),
                              validator: (val) => val == null ? 'Veuillez sélectionner un client' : null,
                            ),
                            if (_selectedClient != null) ...[
                              const SizedBox(height: 20),
                              _buildSearchableDropdown(
                                label: 'Magasin / Agence (Optionnel)',
                                value: _selectedStore,
                                icon: Icons.storefront_outlined,
                                onClear: () {
                                  setState(() {
                                    _selectedStore = null;
                                    _internalDeliveryAddressController.clear();
                                  });
                                },
                                onTap: () => _openSearchDialog(
                                  title: 'Rechercher un Magasin',
                                  items: _stores,
                                  onSelected: (item) => setState(() {
                                    _selectedStore = item;
                                    if (item.data != null && item.data!.containsKey('location')) {
                                      _internalDeliveryAddressController.text = item.data!['location'];
                                    }
                                  }),
                                  onAddPressed: _addNewStore,
                                  addButtonLabel: 'Créer une Agence',
                                ),
                              ),
                              if (_deliveryMethod == 'Livraison Interne') ...[
                                const SizedBox(height: 20),
                                _buildTextField(
                                    controller: _internalDeliveryAddressController,
                                    label: 'Adresse Exacte de Livraison',
                                    icon: Icons.place_outlined,
                                    validator: (val) => null),
                              ],
                            ]
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildGlassSection(
                          title: 'Contenu de la Livraison',
                          icon: Icons.inventory_2_outlined,
                          children: [
                            if (_selectedProducts.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20.0),
                                child: Center(
                                  child: Text(
                                    'Aucun produit scanné/ajouté.',
                                    style: GoogleFonts.inter(color: Colors.black54, fontSize: 16),
                                  ),
                                ),
                              )
                            else
                              ..._selectedProducts.asMap().entries.map((entry) => _buildProductItem(entry.value, entry.key)).toList(),
                            const SizedBox(height: 20),
                            Container(
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blueAccent.withOpacity(0.15),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    )
                                  ]
                              ),
                              child: OutlinedButton.icon(
                                onPressed: _openQuickSearch,
                                icon: const Icon(Icons.search_rounded, size: 22),
                                label: Text('Rechercher & Ajouter', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  backgroundColor: Colors.white.withOpacity(0.8),
                                  side: const BorderSide(color: Colors.blueAccent, width: 1.5),
                                  foregroundColor: Colors.blueAccent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                        if (_isUploading)
                          Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withOpacity(0.8)),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const CircularProgressIndicator(strokeWidth: 3),
                                      const SizedBox(height: 16),
                                      Text(
                                        _loadingStatus,
                                        style: GoogleFonts.outfit(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          _buildSubmitButton(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassSection({required String title, required IconData icon, required List<Widget> children}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.45),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 24,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                    ),
                    child: Icon(icon, color: Colors.blueAccent.shade700, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Divider(height: 1, thickness: 1.5, color: Colors.white70),
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.inter(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.black54),
        prefixIcon: Icon(icon, color: Colors.blueAccent.shade400),
        filled: true,
        fillColor: Colors.white.withOpacity(0.6),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.8), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),
    );
  }

  Widget _buildCustomDropdownField<T>({
    required String label,
    required T? value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextFormField(
          controller: TextEditingController(text: value?.toString() ?? ''),
          style: GoogleFonts.inter(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: GoogleFonts.inter(color: Colors.black54),
            prefixIcon: Icon(icon, color: Colors.blueAccent.shade400),
            suffixIcon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.blueAccent.shade400),
            filled: true,
            fillColor: Colors.white.withOpacity(0.6),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.8), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
            ),
          ),
          validator: (val) => (value == null || value.toString().isEmpty) ? 'Requis' : null,
        ),
      ),
    );
  }

  Widget _buildSearchableDropdown({
    required String label,
    required SelectableItem? value,
    required IconData icon,
    required VoidCallback onTap,
    VoidCallback? onClear,
    String? Function(SelectableItem?)? validator,
  }) {
    String text = '';
    if (value != null) {
      text = value.name;
      if (value.data != null && value.data!.containsKey('location') && value.data!['location'].toString().isNotEmpty) {
        text += ' - ${value.data!['location']}';
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextFormField(
          controller: TextEditingController(text: text),
          style: GoogleFonts.inter(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: GoogleFonts.inter(color: Colors.black54),
            prefixIcon: Icon(icon, color: Colors.blueAccent.shade400),
            suffixIcon: (value != null && onClear != null)
                ? IconButton(icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent), onPressed: onClear)
                : Icon(Icons.search_rounded, color: Colors.blueAccent.shade400),
            filled: true,
            fillColor: Colors.white.withOpacity(0.6),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.8), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
            ),
          ),
          validator: (val) => validator != null ? validator(value) : null,
        ),
      ),
    );
  }

  Widget _buildGlassMultiSelect() {
    return GestureDetector(
      onTap: () => _openCustomMultiSelectDialog(
        title: "Sélection Techniciens",
        items: _technicians,
        currentSelections: _selectedTechnicians,
        onConfirm: (selections) {
          setState(() {
            _selectedTechnicians = selections;
          });
        },
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
            left: 12,
            right: 12,
            top: _selectedTechnicians.isEmpty ? 16 : 12,
            bottom: _selectedTechnicians.isEmpty ? 16 : 12
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: _selectedTechnicians.isEmpty ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: _selectedTechnicians.isEmpty ? 0 : 6.0),
              child: Icon(Icons.people_alt_outlined, color: Colors.blueAccent.shade400),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _selectedTechnicians.isEmpty
                  ? Text(
                "Assigner des Techniciens",
                style: GoogleFonts.inter(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.w500),
              )
                  : Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: _selectedTechnicians.map((tech) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_rounded, size: 14, color: Colors.blueAccent),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            tech.name,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.blueAccent.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: _selectedTechnicians.isEmpty ? 0 : 6.0),
              child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.blueAccent.shade400),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ ADDED: Premium Leading widget to show fetched images!
  Widget _buildProductItem(ProductSelection item, int index) {
    final String? pId = item.productId;
    final List<String>? images = pId != null ? _productImagesCache[pId] : null;

    Widget leadingWidget;

    if (images != null && images.isNotEmpty) {
      leadingWidget = GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ImageGalleryPage(
                imageUrls: images,
                initialIndex: 0,
              ),
            ),
          );
        },
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 2),
            image: DecorationImage(
              image: NetworkImage(images.first),
              fit: BoxFit.cover,
            ),
          ),
          child: images.length > 1
              ? Align(
            alignment: Alignment.bottomRight,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(8), bottomRight: Radius.circular(10))
              ),
              child: const Icon(Icons.collections, color: Colors.white, size: 12),
            ),
          )
              : null,
        ),
      );
    } else {
      leadingWidget = Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.blueAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12), // Match the image radius perfectly
        ),
        child: const Icon(Icons.category_rounded, color: Colors.blueAccent),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))
          ]
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: leadingWidget, // ✅ USING THE NEW LEADING WIDGET
        title: Text(
          item.productName,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black87),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            'Quantité: ${item.quantity}',
            style: GoogleFonts.inter(color: Colors.black54, fontWeight: FontWeight.w500),
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 28),
          onPressed: () {
            setState(() {
              _selectedProducts.removeAt(index);
            });
          },
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 65,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF42A5F5), Color(0xFF1E88E5), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E88E5).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: 2,
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _saveLivraison,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isEditMode ? Icons.check_circle_outline_rounded : Icons.rocket_launch_rounded, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    _isEditMode ? 'Enregistrer Modifications' : 'Créer Bon de Livraison',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}