// lib/screens/service_technique/add_sav_ticket_page.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/models/sav_ticket.dart';
import 'package:boitex_info_app/screens/administration/product_scanner_page.dart';
import 'package:signature/signature.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:boitex_info_app/services/sav_draft_service.dart';
import 'package:boitex_info_app/screens/service_technique/sav_drafts_list_page.dart';
import 'package:boitex_info_app/screens/administration/global_product_search_page.dart';
import 'package:boitex_info_app/models/selection_models.dart';

// 🚀 IMPORT THE OMNIBAR
import 'package:boitex_info_app/widgets/intervention_omnibar.dart';

// --- GLASSMORPHISM HELPER WIDGET (LIGHT THEME) ---
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double opacity;

  const GlassCard({
    Key? key,
    required this.child,
    this.padding,
    this.borderRadius = 24.0,
    this.opacity = 0.6,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                spreadRadius: -5,
              )
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// 🚀 NEW: CUSTOM ANIMATED GRADIENT SEGMENTED CONTROL 🚀
class AnimatedGradientSegmentedControl extends StatelessWidget {
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;
  final List<Color> activeGradient;

  const AnimatedGradientSegmentedControl({
    Key? key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.activeGradient,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final keys = items.keys.toList();
    final selectedIndex = keys.indexOf(value);

    return Container(
      height: 56,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / keys.length;

          return Stack(
            children: [
              // Animated Gradient Thumb
              AnimatedPositioned(
                duration: const Duration(milliseconds: 350),
                curve: Curves.fastLinearToSlowEaseIn, // Snappy Apple-style bounce
                left: selectedIndex * itemWidth,
                top: 0,
                bottom: 0,
                width: itemWidth,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: activeGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: activeGradient.first.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              // Clickable Text Areas
              Row(
                children: keys.map((key) {
                  final isSelected = value == key;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(key),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? Colors.white : Colors.black54,
                            letterSpacing: 0.3,
                          ),
                          child: Text(items[key]!),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Class to manage individual row inputs
class TicketItemEditor {
  final Key key = UniqueKey();
  final String productId;
  final String productName;
  final TextEditingController serialController;
  final TextEditingController problemController;

  TicketItemEditor({
    required this.productId,
    required this.productName,
    String? initialSerial,
    String? initialProblem,
  })  : serialController = TextEditingController(text: initialSerial),
        problemController = TextEditingController(text: initialProblem);

  void dispose() {
    serialController.dispose();
    problemController.dispose();
  }
}

class UserViewModel {
  final String id;
  final String name;
  UserViewModel({required this.id, required this.name});
}

class AddSavTicketPage extends StatefulWidget {
  final String serviceType;
  const AddSavTicketPage({super.key, required this.serviceType});

  @override
  State<AddSavTicketPage> createState() => _AddSavTicketPageState();
}

class _AddSavTicketPageState extends State<AddSavTicketPage> {
  final _formKey = GlobalKey<FormState>();

  String _selectedTicketType = 'standard';
  String _creationMode = 'individual';
  String? _currentDraftId;

  List<SelectableItem> _clients = [];
  List<SelectableItem> _stores = [];
  bool _isLoadingClients = true;
  bool _isLoadingStores = false;
  SelectableItem? _selectedClient;
  SelectableItem? _selectedStore;

  List<UserViewModel> _availableTechnicians = [];
  bool _isLoadingTechnicians = true;
  List<UserViewModel> _selectedTechnicians = [];

  final _managerNameController = TextEditingController();
  final _managerEmailController = TextEditingController();
  DateTime? _pickupDate;
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  List<File> _attachedFiles = [];
  bool _isLoading = false;

  final List<TicketItemEditor> _itemEditors = [];

  final String _getB2UploadUrlCloudFunctionUrl =
      'https://europe-west1-boitexinfo-63060.cloudfunctions.net/getB2UploadUrl';

  final _draftService = SavDraftService();

  @override
  void initState() {
    super.initState();
    _fetchClients();
    _fetchAvailableTechnicians();
  }

  @override
  void dispose() {
    _managerNameController.dispose();
    _managerEmailController.dispose();
    _signatureController.dispose();
    for (var editor in _itemEditors) {
      editor.dispose();
    }
    super.dispose();
  }

  // --- DATA FETCHING ---
  Future<void> _fetchClients() async {
    setState(() => _isLoadingClients = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('clients')
          .where('services', arrayContains: widget.serviceType)
          .get();

      final clients = snapshot.docs
          .map((doc) => SelectableItem(id: doc.id, name: doc['name']))
          .toList();

      clients.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (mounted) {
        setState(() {
          _clients = clients;
          _isLoadingClients = false;
          if (_selectedClient != null && !_clients.any((c) => c.id == _selectedClient!.id)) {
            _selectedClient = null;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingClients = false);
    }
  }

  Future<void> _fetchStoresForClient(String clientId) async {
    setState(() {
      _isLoadingStores = true;
      _stores = [];
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('clients')
          .doc(clientId)
          .collection('stores')
          .get();

      final stores = snapshot.docs.map((doc) {
        final data = doc.data();
        return SelectableItem(
            id: doc.id,
            name: data['name'],
            data: {'location': data['location'] ?? ''}
        );
      }).toList();

      stores.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (mounted) {
        setState(() {
          _stores = stores;
          _isLoadingStores = false;
          if (_selectedStore != null && !stores.any((s) => s.id == _selectedStore!.id)) {
            _selectedStore = null;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStores = false);
    }
  }

  Future<void> _fetchAvailableTechnicians() async {
    setState(() => _isLoadingTechnicians = true);
    try {
      final includedRoles = [
        'Admin', 'Responsable Administratif', 'Responsable Commercial',
        'Responsable Technique', 'Responsable IT', 'Chef de Projet',
        'Technicien ST', 'Technicien IT'
      ];
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: includedRoles)
          .orderBy('role')
          .orderBy('displayName')
          .get();
      final users = snapshot.docs
          .map((doc) => UserViewModel(id: doc.id, name: doc['displayName']))
          .toList();
      if (mounted) {
        setState(() {
          _availableTechnicians = users;
          _isLoadingTechnicians = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingTechnicians = false);
    }
  }

  // 🚀 IOS FULL-SCREEN SEARCH SHEET
  void _openIOSSearchSheet({
    required String title,
    required List<SelectableItem> items,
    required Function(SelectableItem) onSelected,
    required VoidCallback onAddPressed,
    required String addButtonLabel,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setStateSB) {
            final filteredItems = items.where((item) {
              final nameLower = item.name.toLowerCase();
              final queryLower = searchQuery.toLowerCase();
              return nameLower.contains(queryLower);
            }).toList();

            return FractionallySizedBox(
              heightFactor: 0.88,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 12, bottom: 8),
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: CupertinoSearchTextField(
                            placeholder: 'Rechercher...',
                            onChanged: (val) => setStateSB(() => searchQuery = val),
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: filteredItems.length + 1,
                            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                            itemBuilder: (context, index) {
                              if (index == filteredItems.length) {
                                return ListTile(
                                  leading: const Icon(CupertinoIcons.add_circled_solid, color: Colors.blueAccent),
                                  title: Text(addButtonLabel, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                                  onTap: () {
                                    Navigator.pop(context);
                                    onAddPressed();
                                  },
                                );
                              }
                              final item = filteredItems[index];
                              final subtitle = item.data != null && item.data!.containsKey('location') ? item.data!['location'] : null;
                              return ListTile(
                                title: Text(item.name, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                                subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(color: Colors.black54)) : null,
                                trailing: const Icon(CupertinoIcons.chevron_forward, color: Colors.black26, size: 18),
                                onTap: () {
                                  onSelected(item);
                                  Navigator.pop(context);
                                },
                              );
                            },
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

  // 🚀 IOS TECHNICIAN SELECTOR
  void _openIOSTechnicianSelector() {
    List<UserViewModel> tempSelected = List.from(_selectedTechnicians);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return FractionallySizedBox(
              heightFactor: 0.75,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.black12)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Annuler', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
                              ),
                              const Text('Techniciens', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                              TextButton(
                                onPressed: () {
                                  setState(() => _selectedTechnicians = tempSelected);
                                  Navigator.pop(context);
                                },
                                child: const Text('Valider', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: _availableTechnicians.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                            itemBuilder: (context, index) {
                              final tech = _availableTechnicians[index];
                              final isSelected = tempSelected.any((t) => t.id == tech.id);

                              return ListTile(
                                title: Text(tech.name, style: TextStyle(color: isSelected ? Colors.blueAccent : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                trailing: isSelected ? const Icon(CupertinoIcons.checkmark_alt, color: Colors.blueAccent) : null,
                                onTap: () {
                                  setStateSB(() {
                                    if (isSelected) {
                                      tempSelected.removeWhere((t) => t.id == tech.id);
                                    } else {
                                      tempSelected.add(tech);
                                    }
                                  });
                                },
                              );
                            },
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

  // --- QUICK ADD LOGIC ---
  Future<void> _addNewClient() async {
    final TextEditingController nameController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Nouveau Client', style: TextStyle(color: Colors.black87)),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.black87),
          decoration: InputDecoration(labelText: 'Nom du client', labelStyle: const TextStyle(color: Colors.black54), filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler', style: TextStyle(color: Colors.black54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                try {
                  final ref = await FirebaseFirestore.instance.collection('clients').add({
                    'name': name,
                    'createdAt': FieldValue.serverTimestamp(),
                    'services': [widget.serviceType],
                  });
                  final newItem = SelectableItem(id: ref.id, name: name);
                  setState(() {
                    _clients.add(newItem);
                    _clients.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                    _selectedClient = newItem;
                    _selectedStore = null;
                    _stores = [];
                  });
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                }
              }
            },
            child: const Text('Ajouter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _addNewStore() async {
    if (_selectedClient == null) return;
    final TextEditingController nameController = TextEditingController();
    final TextEditingController addressController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Nouveau Magasin', style: TextStyle(color: Colors.black87)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, style: const TextStyle(color: Colors.black87), decoration: InputDecoration(labelText: 'Nom du magasin', labelStyle: const TextStyle(color: Colors.black54), filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            const SizedBox(height: 10),
            TextField(controller: addressController, style: const TextStyle(color: Colors.black87), decoration: InputDecoration(labelText: 'Adresse / Localisation', labelStyle: const TextStyle(color: Colors.black54), filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler', style: TextStyle(color: Colors.black54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              final name = nameController.text.trim();
              final address = addressController.text.trim();
              if (name.isNotEmpty) {
                try {
                  final ref = await FirebaseFirestore.instance
                      .collection('clients')
                      .doc(_selectedClient!.id)
                      .collection('stores')
                      .add({
                    'name': name,
                    'location': address,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  final newItem = SelectableItem(id: ref.id, name: name, data: {'location': address});
                  setState(() {
                    _stores.add(newItem);
                    _selectedStore = newItem;
                  });
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                }
              }
            },
            child: const Text('Ajouter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- PRODUCT SEARCH ---
  Future<void> _openProductSearch() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GlobalProductSearchPage(
          isSelectionMode: true,
          onProductSelected: (Map<String, dynamic> result) {
            final String? pid = result['id'] ?? result['productId'];
            final String? pname = result['nom'] ?? result['productName'];
            final int qty = result['quantity'] ?? 1;

            if (pid != null && pname != null) {
              setState(() {
                for (int i = 0; i < qty; i++) {
                  _itemEditors.add(TicketItemEditor(
                    productId: pid,
                    productName: pname,
                  ));
                }
              });
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Ajouté: $pname (x$qty)', style: const TextStyle(color: Colors.white)),
                  backgroundColor: Colors.green.shade600,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  // --- OTHER HELPERS ---
  void _removeEditor(int index) {
    setState(() {
      _itemEditors[index].dispose();
      _itemEditors.removeAt(index);
    });
  }

  Future<void> _scanSerialForEditor(int index) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => const ProductScannerPage(),
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _itemEditors[index].serialController.text = result;
      });
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    DateTime tempPickedDate = _pickupDate ?? now;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext builder) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            height: 320,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.05), width: 1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Annuler', style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                      const Text(
                        'Date de Récupération',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => _pickupDate = tempPickedDate);
                          Navigator.of(context).pop();
                        },
                        child: const Text('Confirmer', style: TextStyle(color: Colors.blueAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: tempPickedDate,
                    minimumDate: DateTime(2020),
                    maximumDate: now,
                    onDateTimeChanged: (DateTime newDate) {
                      tempPickedDate = newDate;
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true
    );
    if (result != null) {
      setState(() {
        final newFiles = result.files.where((f) => f.path != null).map((f) => File(f.path!));
        for (var file in newFiles) {
          if (!_attachedFiles.any((e) => e.path == file.path)) {
            _attachedFiles.add(file);
          }
        }
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _attachedFiles.removeAt(index);
    });
  }

  bool _isVideoPath(String filePath) {
    final p = filePath.toLowerCase();
    return p.endsWith('.mp4') || p.endsWith('.mov') || p.endsWith('.avi') || p.endsWith('.mkv');
  }

  bool _isImagePath(String filePath) {
    final p = filePath.toLowerCase();
    return p.endsWith('.jpg') || p.endsWith('.jpeg') || p.endsWith('.png') || p.endsWith('.gif') || p.endsWith('.webp');
  }

  Future<Map<String, dynamic>?> _getB2UploadCredentials() async {
    try {
      final response = await http.get(Uri.parse(_getB2UploadUrlCloudFunctionUrl));
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> _uploadBytesToB2(Uint8List bytes, String fileName, Map<String, dynamic> b2Creds) async {
    try {
      final sha1Hash = sha1.convert(bytes).toString();
      final uploadUri = Uri.parse(b2Creds['uploadUrl']);

      final resp = await http.post(
        uploadUri,
        headers: {
          'Authorization': b2Creds['authorizationToken'],
          'X-Bz-File-Name': Uri.encodeComponent(fileName),
          'Content-Type': 'image/png',
          'X-Bz-Content-Sha1': sha1Hash,
          'Content-Length': bytes.length.toString(),
        },
        body: bytes,
      );
      if (resp.statusCode == 200) {
        final body = json.decode(resp.body);
        final encodedPath = (body['fileName'] as String).split('/').map(Uri.encodeComponent).join('/');
        return (b2Creds['downloadUrlPrefix']) + encodedPath;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> _uploadFileToB2(File file, Map<String, dynamic> b2Creds) async {
    try {
      final fileBytes = await file.readAsBytes();
      final sha1Hash = sha1.convert(fileBytes).toString();
      final uploadUri = Uri.parse(b2Creds['uploadUrl']);
      final fileName = path.basename(file.path);
      final resp = await http.post(
        uploadUri,
        headers: {
          'Authorization': b2Creds['authorizationToken'],
          'X-Bz-File-Name': Uri.encodeComponent(fileName),
          'Content-Type': 'b2/x-auto',
          'X-Bz-Content-Sha1': sha1Hash,
          'Content-Length': fileBytes.length.toString(),
        },
        body: fileBytes,
      );
      if (resp.statusCode == 200) {
        final body = json.decode(resp.body);
        final encodedPath = (body['fileName'] as String).split('/').map(Uri.encodeComponent).join('/');
        return (b2Creds['downloadUrlPrefix']) + encodedPath;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveTicket() async {
    if (_selectedClient == null || _managerNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Veuillez remplir les infos client/gérant.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))));
      return;
    }

    if (_itemEditors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('La liste des appareils est vide.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.orangeAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))));
      return;
    }

    setState(() => _isLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      String? storeName;
      if (_selectedStore != null) {
        storeName = '${_selectedStore!.name} - ${_selectedStore!.data?['location'] ?? ''}';
      }

      final int itemsToCreate = _creationMode == 'grouped' ? 1 : _itemEditors.length;
      final year = DateTime.now().year;
      final counterRef = FirebaseFirestore.instance.collection('counters').doc('sav_tickets_$year');

      final int startCount = await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(counterRef);
        final current = (snap.data()?['count'] as int?) ?? 0;
        final nextEnd = current + itemsToCreate;
        tx.set(counterRef, {'count': nextEnd}, SetOptions(merge: true));
        return current + 1;
      });

      final b2Credentials = await _getB2UploadCredentials();

      String sigUrl = '';
      if (_signatureController.isNotEmpty && b2Credentials != null) {
        final sigData = await _signatureController.toPngBytes();
        if (sigData != null) {
          final fileName = 'sav_signatures/BATCH-${startCount}_$year.png';
          final uploadedUrl = await _uploadBytesToB2(sigData, fileName, b2Credentials);
          if (uploadedUrl != null) {
            sigUrl = uploadedUrl;
          }
        }
      }

      List<String> mediaUrls = [];
      String? attachedFileUrl;

      if (b2Credentials != null) {
        for (var file in _attachedFiles) {
          final url = await _uploadFileToB2(file, b2Credentials);
          if (url != null) {
            if (_isImagePath(file.path) || _isVideoPath(file.path)) {
              mediaUrls.add(url);
            } else {
              attachedFileUrl = url;
            }
          }
        }
      }

      final batch = FirebaseFirestore.instance.batch();
      final ticketsCollection = FirebaseFirestore.instance.collection('sav_tickets');

      if (_creationMode == 'grouped') {
        final codeStr = 'SAV-$startCount/$year';
        final savItems = _itemEditors.map((e) => SavProductItem(
          productId: e.productId,
          productName: e.productName,
          serialNumber: e.serialController.text,
          problemDescription: e.problemController.text,
        )).toList();

        final ticket = SavTicket(
          serviceType: widget.serviceType,
          savCode: codeStr,
          clientId: _selectedClient!.id,
          clientName: _selectedClient!.name,
          storeId: _selectedStore?.id,
          storeName: storeName,
          pickupDate: _pickupDate ?? DateTime.now(),
          pickupTechnicianIds: _selectedTechnicians.map((u) => u.id).toList(),
          pickupTechnicianNames: _selectedTechnicians.map((u) => u.name).toList(),
          productName: 'Lot de ${_itemEditors.length} Appareils',
          serialNumber: 'VOIR LISTE',
          problemDescription: 'Voir liste des appareils ci-dessous',
          multiProducts: savItems,
          itemPhotoUrls: mediaUrls,
          storeManagerName: _managerNameController.text,
          storeManagerEmail: _managerEmailController.text.isEmpty ? null : _managerEmailController.text,
          storeManagerSignatureUrl: sigUrl,
          status: _selectedTicketType == 'removal' ? 'Dépose' : 'Nouveau',
          ticketType: _selectedTicketType,
          createdBy: 'Current User',
          createdAt: DateTime.now(),
          uploadedFileUrl: attachedFileUrl,
        );
        batch.set(ticketsCollection.doc(), ticket.toJson());

      } else {
        for (int i = 0; i < _itemEditors.length; i++) {
          final e = _itemEditors[i];
          final currentCodeNumber = startCount + i;
          final codeStr = 'SAV-$currentCodeNumber/$year';

          final ticket = SavTicket(
            serviceType: widget.serviceType,
            savCode: codeStr,
            clientId: _selectedClient!.id,
            clientName: _selectedClient!.name,
            storeId: _selectedStore?.id,
            storeName: storeName,
            pickupDate: _pickupDate ?? DateTime.now(),
            pickupTechnicianIds: _selectedTechnicians.map((u) => u.id).toList(),
            pickupTechnicianNames: _selectedTechnicians.map((u) => u.name).toList(),
            productName: e.productName,
            serialNumber: e.serialController.text,
            problemDescription: e.problemController.text,
            multiProducts: [],
            itemPhotoUrls: mediaUrls,
            storeManagerName: _managerNameController.text,
            storeManagerEmail: _managerEmailController.text.isEmpty ? null : _managerEmailController.text,
            storeManagerSignatureUrl: sigUrl,
            status: _selectedTicketType == 'removal' ? 'Dépose' : 'Nouveau',
            ticketType: _selectedTicketType,
            createdBy: 'Current User',
            createdAt: DateTime.now(),
            uploadedFileUrl: attachedFileUrl,
          );
          batch.set(ticketsCollection.doc(), ticket.toJson());
        }
      }

      await batch.commit();

      if (_currentDraftId != null) {
        await _draftService.deleteDraft(_currentDraftId!);
      }

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(_creationMode == 'grouped' ? 'SAV Groupé créé !' : '${_itemEditors.length} SAV créés !', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        );
        navigator.pop();
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Erreur: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))));
        setState(() => _isLoading = false);
      }
    }
  }

  // --- DRAFTS ---
  Future<void> _openDraftsList() async {
    final SavDraft? selectedDraft = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SavDraftsListPage()),
    );

    if (selectedDraft != null) {
      _restoreDraft(selectedDraft);
    }
  }

  Future<void> _restoreDraft(SavDraft draft) async {
    setState(() {
      _currentDraftId = draft.id;
      if (draft.clientId != null) {
        _selectedClient = SelectableItem(id: draft.clientId!, name: draft.clientName ?? 'Client Inconnu');
      }
      _managerNameController.text = draft.managerName ?? '';
      _managerEmailController.text = draft.managerEmail ?? '';
      _selectedTicketType = draft.ticketType;
      _creationMode = draft.creationMode;
    });

    if (draft.clientId != null) {
      await _fetchStoresForClient(draft.clientId!);
    }

    if (draft.storeId != null && mounted) {
      setState(() {
        try {
          _selectedStore = _stores.firstWhere((s) => s.id == draft.storeId);
        } catch (e) {
          _selectedStore = SelectableItem(id: draft.storeId!, name: 'Magasin (ID: ${draft.storeId})');
        }
      });
    }

    if (mounted) {
      setState(() {
        if (draft.technicianIds.isNotEmpty) {
          _selectedTechnicians = _availableTechnicians
              .where((u) => draft.technicianIds.contains(u.id))
              .toList();
        }

        _itemEditors.clear();
        for (var item in draft.items) {
          _itemEditors.add(TicketItemEditor(
            productId: item['productId']!,
            productName: item['productName']!,
            initialSerial: item['serialNumber'],
            initialProblem: item['problemDescription'],
          ));
        }

        _attachedFiles = draft.mediaPaths
            .map((path) => File(path))
            .where((file) => file.existsSync())
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Brouillon chargé.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))));
    }
  }

  Future<void> _saveDraftLogic() async {
    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Sélectionner un client.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.orangeAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))));
      return;
    }

    final String draftId = _currentDraftId ?? const Uuid().v4();

    final draft = SavDraft(
      id: draftId,
      date: DateTime.now(),
      clientId: _selectedClient!.id,
      clientName: _selectedClient!.name,
      storeId: _selectedStore?.id,
      managerName: _managerNameController.text,
      managerEmail: _managerEmailController.text,
      ticketType: _selectedTicketType,
      creationMode: _creationMode,
      items: _itemEditors.map((editor) => {
        'productId': editor.productId,
        'productName': editor.productName,
        'serialNumber': editor.serialController.text,
        'problemDescription': editor.problemController.text,
      }).toList(),
      mediaPaths: _attachedFiles.map((f) => f.path).toList(),
      technicianIds: _selectedTechnicians.map((u) => u.id).toList(),
    );

    await _draftService.saveDraft(draft);
    setState(() => _currentDraftId = draftId);
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Brouillon sauvegardé !', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))));
  }

  // --- WIDGETS ---

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.black87, fontSize: 16),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: const TextStyle(color: Colors.black54),
          prefixIcon: Icon(icon, color: Colors.black54),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
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
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: AbsorbPointer(
          child: TextFormField(
            controller: TextEditingController(text: text),
            style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(color: Colors.black54),
              prefixIcon: Icon(icon, color: Colors.black54),
              suffixIcon: (value != null && onClear != null)
                  ? IconButton(icon: const Icon(Icons.clear, color: Colors.redAccent), onPressed: onClear)
                  : const Icon(CupertinoIcons.chevron_down, color: Colors.black54),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Nouveau SAV (${widget.serviceType})', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 1.2)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.white.withOpacity(0.5)),
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.folder_special), tooltip: "Brouillons", onPressed: _openDraftsList),
          IconButton(icon: const Icon(Icons.cloud_upload_outlined), tooltip: "Sauvegarder Brouillon", onPressed: _saveDraftLogic),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF3F4F6),
              Color(0xFFE8EDF2),
              Color(0xFFFDEBEE),
              Color(0xFFF5F7FA),
            ],
            stops: [0.0, 0.4, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- CLIENT SECTION ---
                      const Text('Informations Client', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 16),
                      GlassCard(
                        child: Column(
                          children: [

                            // 🚀 THE OMNIBAR FOR CLIENT SELECTION
                            Row(
                              children: [
                                Expanded(
                                  child: InterventionOmnibar(
                                    onItemSelected: (result) {
                                      setState(() {
                                        _selectedClient = SelectableItem(id: result.id, name: result.title);
                                        _selectedStore = null;
                                        _stores = [];
                                      });
                                      _fetchStoresForClient(result.id);
                                    },
                                    onClear: () {
                                      setState(() {
                                        _selectedClient = null;
                                        _selectedStore = null;
                                        _stores = [];
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  height: 56,
                                  width: 56,
                                  decoration: BoxDecoration(
                                      color: Colors.blueAccent,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(color: Colors.blueAccent.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
                                      ]
                                  ),
                                  child: IconButton(
                                    icon: const Icon(CupertinoIcons.add, color: Colors.white, size: 26),
                                    tooltip: 'Nouveau Client',
                                    onPressed: _addNewClient,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),
                            if (_selectedClient != null) ...[
                              _buildSearchableDropdown(
                                label: 'Magasin (Optionnel)',
                                value: _selectedStore,
                                icon: Icons.store_mall_directory_rounded,
                                onClear: () => setState(() => _selectedStore = null),
                                onTap: () => _openIOSSearchSheet(
                                  title: 'Rechercher un Magasin',
                                  items: _stores,
                                  onSelected: (item) => setState(() => _selectedStore = item),
                                  onAddPressed: _addNewStore,
                                  addButtonLabel: 'Nouveau Magasin',
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            _buildGlassTextField(
                              controller: _managerNameController,
                              labelText: 'Nom du Gérant / Contact',
                              icon: Icons.person_pin_rounded,
                            ),
                            const SizedBox(height: 16),
                            _buildGlassTextField(
                              controller: _managerEmailController,
                              labelText: 'Email (Optionnel)',
                              icon: Icons.alternate_email_rounded,
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // --- CONFIGURATION SECTION ---
                      const Text('Configuration du Billet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 16),
                      GlassCard(
                        child: Column(
                          children: [
                            // 🚀 THE ANIMATED CUSTOM APPLE GRADIENT TOGGLE (TYPE) 🚀
                            AnimatedGradientSegmentedControl(
                              value: _selectedTicketType,
                              items: const {
                                'standard': 'Atelier',
                                'removal': 'Sur site',
                              },
                              activeGradient: const [Color(0xFF007AFF), Color(0xFF5AC8FA)], // Apple Blue to Cyan
                              onChanged: (value) {
                                setState(() => _selectedTicketType = value);
                              },
                            ),
                            const SizedBox(height: 16),

                            // 🚀 THE ANIMATED CUSTOM APPLE GRADIENT TOGGLE (MODE) 🚀
                            AnimatedGradientSegmentedControl(
                              value: _creationMode,
                              items: const {
                                'individual': 'Individuel',
                                'grouped': 'Groupé',
                              },
                              activeGradient: const [Color(0xFFAF52DE), Color(0xFFFF2D55)], // Apple Purple to Pink
                              onChanged: (value) {
                                setState(() => _creationMode = value);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // --- PRODUCTS LIST SECTION ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text('Appareils à Récupérer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87), overflow: TextOverflow.ellipsis),
                          ),
                          IconButton(
                            onPressed: _openProductSearch,
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(colors: [Color(0xFF007AFF), Color(0xFF0056D6)]),
                                boxShadow: [BoxShadow(color: const Color(0xFF007AFF).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
                              ),
                              child: const Icon(Icons.add, color: Colors.white, size: 24),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (_itemEditors.isEmpty)
                        GestureDetector(
                          onTap: _openProductSearch,
                          child: GlassCard(
                            opacity: 0.3,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 30),
                              child: const Column(
                                children: [
                                  Icon(Icons.inventory_2_rounded, size: 60, color: Colors.black26),
                                  SizedBox(height: 12),
                                  Text("Aucun appareil ajouté", style: TextStyle(color: Colors.black54, fontSize: 16)),
                                  SizedBox(height: 8),
                                  Text("Appuyez pour ajouter", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _itemEditors.length,
                          itemBuilder: (context, index) {
                            final editor = _itemEditors[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: GlassCard(
                                key: editor.key,
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blueAccent.withOpacity(0.1)),
                                          child: Text('${index + 1}', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            editor.productName,
                                            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(CupertinoIcons.minus_circle_fill, color: Colors.redAccent, size: 28),
                                          onPressed: () => _removeEditor(index),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
                                      child: TextField(
                                        controller: editor.serialController,
                                        style: const TextStyle(color: Colors.black87),
                                        decoration: InputDecoration(
                                          labelText: 'Numéro de Série',
                                          labelStyle: const TextStyle(color: Colors.black54),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                          suffixIcon: IconButton(
                                            icon: const Icon(CupertinoIcons.barcode_viewfinder, color: Colors.blueAccent),
                                            onPressed: () => _scanSerialForEditor(index),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
                                      child: TextField(
                                        controller: editor.problemController,
                                        style: const TextStyle(color: Colors.black87),
                                        maxLines: 2,
                                        decoration: InputDecoration(
                                          labelText: 'Description de la Panne',
                                          labelStyle: const TextStyle(color: Colors.black54),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 32),

                      // --- DETAILS SECTION ---
                      const Text('Détails', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 16),
                      GlassCard(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _selectDate,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
                                child: Row(
                                  children: [
                                    const Icon(CupertinoIcons.calendar, color: Colors.black54),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        _pickupDate == null ? 'Sélectionner la Date' : DateFormat('dd MMMM yyyy', 'fr_FR').format(_pickupDate!),
                                        style: TextStyle(color: _pickupDate == null ? Colors.black54 : Colors.black87, fontSize: 16),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: _openIOSTechnicianSelector,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
                                child: Row(
                                  children: [
                                    const Icon(CupertinoIcons.person_3_fill, color: Colors.black54),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        _selectedTechnicians.isEmpty
                                            ? 'Assigner les Techniciens'
                                            : _selectedTechnicians.map((t) => t.name).join(', '),
                                        style: TextStyle(
                                            color: _selectedTechnicians.isEmpty ? Colors.black54 : Colors.blueAccent,
                                            fontSize: 16,
                                            fontWeight: _selectedTechnicians.isEmpty ? FontWeight.normal : FontWeight.bold
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Icon(CupertinoIcons.chevron_down, color: Colors.black54, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // --- UNIFIED MEDIA & DOCUMENTS ATTACHMENTS ---
                      const Text('Fichiers & Médias', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 16),
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.blueAccent,
                                  backgroundColor: Colors.blueAccent.withOpacity(0.1),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: _pickFiles,
                                icon: const Icon(CupertinoIcons.cloud_upload),
                                label: const Text('Ajouter des Fichiers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),

                            if (_attachedFiles.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: List.generate(_attachedFiles.length, (index) {
                                  final file = _attachedFiles[index];
                                  final isImage = _isImagePath(file.path);
                                  final isVideo = _isVideoPath(file.path);

                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.7),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.black12),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: isImage
                                              ? Image.file(file, fit: BoxFit.cover)
                                              : isVideo
                                              ? const Icon(Icons.videocam_rounded, color: Colors.black54, size: 40)
                                              : Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.insert_drive_file_rounded, color: Colors.black54, size: 32),
                                              const SizedBox(height: 4),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                                child: Text(
                                                  path.basename(file.path),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(fontSize: 10, color: Colors.black87),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: -6,
                                        right: -6,
                                        child: GestureDetector(
                                          onTap: () => _removeFile(index),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.redAccent,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // --- SIGNATURE SECTION ---
                      const Text('Signature du Gérant', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 16),
                      GlassCard(
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Signature(
                                controller: _signatureController,
                                backgroundColor: Colors.white,
                                height: 180,
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _signatureController.clear(),
                                icon: const Icon(CupertinoIcons.clear_thick, color: Colors.redAccent, size: 18),
                                label: const Text('Effacer', style: TextStyle(color: Colors.redAccent)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),

                      // --- SUBMIT BUTTON ---
                      Container(
                        width: double.infinity,
                        height: 65,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF007AFF), Color(0xFF0056D6)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF007AFF).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _saveTicket,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          icon: _isLoading ? const SizedBox.shrink() : const Icon(CupertinoIcons.check_mark_circled_solid, size: 28, color: Colors.white),
                          label: _isLoading
                              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                              : Flexible(
                            child: Text(
                              _creationMode == 'grouped' ? 'VALIDER LE SAV GROUPÉ' : 'VALIDER ${_itemEditors.length} SAV',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}