// lib/screens/service_technique/add_sav_ticket_page.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/models/sav_ticket.dart';
import 'package:boitex_info_app/screens/widgets/scanner_page.dart';
import 'package:signature/signature.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
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
// ✅ IMPORT Selection Models
import 'package:boitex_info_app/models/selection_models.dart';

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

  // ✅ UPDATED: Use SelectableItem for Clients/Stores
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
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  List<File> _pickedMediaFiles = [];
  File? _attachedFile;

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
          // Validate existing selection
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
      // Note: We deliberately do NOT clear _selectedStore here to avoid UI flickering during restore,
      // but we will validate it after fetch.
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
          // If the currently selected store is not in the new list, clear it
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

  // ✅ --- SEARCH DIALOG LOGIC ---

  void _openSearchDialog({
    required String title,
    required List<SelectableItem> items,
    required Function(SelectableItem) onSelected,
    required VoidCallback onAddPressed,
    required String addButtonLabel,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setStateSB) {
            final filteredItems = items.where((item) {
              final nameLower = item.name.toLowerCase();
              final queryLower = searchQuery.toLowerCase();
              return nameLower.contains(queryLower);
            }).toList();

            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Rechercher...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        setStateSB(() => searchQuery = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredItems.length + 1,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          if (index == filteredItems.length) {
                            return ListTile(
                              leading: const Icon(Icons.add_circle, color: Colors.blue),
                              title: Text(addButtonLabel, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                              onTap: () {
                                Navigator.pop(context);
                                onAddPressed();
                              },
                            );
                          }
                          final item = filteredItems[index];
                          final subtitle = item.data != null && item.data!.containsKey('location') ? item.data!['location'] : null;
                          return ListTile(
                            title: Text(item.name),
                            subtitle: subtitle != null ? Text(subtitle) : null,
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
              actions: [
                TextButton(
                  child: const Text("Fermer"),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ✅ --- QUICK ADD LOGIC ---

  Future<void> _addNewClient() async {
    final TextEditingController nameController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouveau Client'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Nom du client', border: OutlineInputBorder()),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
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
            child: const Text('Ajouter'),
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
        title: const Text('Nouveau Magasin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nom du magasin', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Adresse / Localisation', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
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
            child: const Text('Ajouter'),
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

            if (pid != null && pname != null) {
              setState(() {
                _itemEditors.add(TicketItemEditor(
                  productId: pid,
                  productName: pname,
                ));
              });
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Ajouté: $pname'), duration: const Duration(milliseconds: 800), behavior: SnackBarBehavior.floating),
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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ScannerPage(
          onScan: (result) {
            setState(() {
              _itemEditors[index].serialController.text = result;
            });
          },
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickupDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _pickupDate) {
      setState(() => _pickupDate = picked);
    }
  }

  Future<void> _pickMediaFiles() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.media, allowMultiple: true);
    if (result != null) {
      setState(() {
        _pickedMediaFiles = result.files.where((f) => f.path != null).map((f) => File(f.path!)).toList();
      });
    }
  }

  Future<void> _pickAttachedFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any, allowMultiple: false);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _attachedFile = File(result.files.single.path!);
      });
    }
  }

  // --- SAVE LOGIC ---

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez remplir les infos client/gérant.')));
      return;
    }

    if (_itemEditors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La liste des appareils est vide.')));
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

      String sigUrl = '';
      if (_signatureController.isNotEmpty) {
        final sigData = await _signatureController.toPngBytes();
        if (sigData != null) {
          final sigRef = FirebaseStorage.instance.ref('sav_signatures/BATCH-${startCount}_$year.png');
          await sigRef.putData(sigData);
          sigUrl = await sigRef.getDownloadURL();
        }
      }

      final b2Credentials = await _getB2UploadCredentials();
      List<String> mediaUrls = [];
      String? attachedFileUrl;

      if (b2Credentials != null) {
        for (var file in _pickedMediaFiles) {
          final url = await _uploadFileToB2(file, b2Credentials);
          if (url != null) mediaUrls.add(url);
        }
        if (_attachedFile != null) {
          attachedFileUrl = await _uploadFileToB2(_attachedFile!, b2Credentials);
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
          SnackBar(content: Text(_creationMode == 'grouped' ? 'SAV Groupé créé !' : '${_itemEditors.length} SAV créés !')),
        );
        navigator.pop();
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Erreur: $e')));
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
    // 1. Set Initial Data (Sync)
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

    // 2. Fetch Stores (Async) if client is present
    if (draft.clientId != null) {
      await _fetchStoresForClient(draft.clientId!);
    }

    // 3. Set Store (Sync, after fetch)
    if (draft.storeId != null && mounted) {
      setState(() {
        // Try to find the store object from the fetched list to get accurate details
        try {
          _selectedStore = _stores.firstWhere((s) => s.id == draft.storeId);
        } catch (e) {
          // Fallback if store not found in list
          _selectedStore = SelectableItem(id: draft.storeId!, name: 'Magasin (ID: ${draft.storeId})');
        }
      });
    }

    // 4. Restore Items and other fields
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

        _pickedMediaFiles = draft.mediaPaths
            .map((path) => File(path))
            .where((file) => file.existsSync())
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Brouillon chargé.')));
    }
  }

  // --- DRAFT SAVE ---
  Future<void> _saveDraftLogic() async {
    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sélectionner un client.')));
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
      mediaPaths: _pickedMediaFiles.map((f) => f.path).toList(),
      technicianIds: _selectedTechnicians.map((u) => u.id).toList(),
    );

    await _draftService.saveDraft(draft);
    setState(() => _currentDraftId = draftId);
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Brouillon sauvegardé !')));
  }

  // --- WIDGETS ---

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
      child: AbsorbPointer(
        child: TextFormField(
          controller: TextEditingController(text: text),
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: Colors.grey[600]),
            suffixIcon: (value != null && onClear != null)
                ? IconButton(icon: const Icon(Icons.clear, color: Colors.red), onPressed: onClear)
                : const Icon(Icons.arrow_drop_down),
            filled: true,
            fillColor: Colors.grey[200],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton(String label, String value, IconData icon) {
    final isSelected = _creationMode == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _creationMode = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.orange : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected ? null : Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isVideoPath(String filePath) {
    final p = filePath.toLowerCase();
    return p.endsWith('.mp4') || p.endsWith('.mov') || p.endsWith('.avi') || p.endsWith('.mkv');
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Colors.orange;
    final defaultBorder = OutlineInputBorder(
      borderSide: BorderSide(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(12),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Nouveau SAV (${widget.serviceType})'),
        backgroundColor: primaryColor,
        actions: [
          IconButton(icon: const Icon(Icons.folder_open), onPressed: _openDraftsList),
          IconButton(icon: const Icon(Icons.save_outlined), onPressed: _saveDraftLogic),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Informations Client',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
              const SizedBox(height: 16),

              // ✅ REPLACED: Searchable Client Dropdown
              _buildSearchableDropdown(
                label: 'Client',
                value: _selectedClient,
                icon: Icons.person_outline,
                onClear: () {
                  setState(() {
                    _selectedClient = null;
                    _selectedStore = null;
                    _stores = [];
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
                    });
                    _fetchStoresForClient(item.id);
                  },
                  onAddPressed: _addNewClient,
                  addButtonLabel: '+ Nouveau Client',
                ),
              ),

              const SizedBox(height: 12),

              // ✅ REPLACED: Searchable Store Dropdown
              if (_selectedClient != null)
                _buildSearchableDropdown(
                  label: 'Magasin (Optionnel)',
                  value: _selectedStore,
                  icon: Icons.store_outlined,
                  onClear: () => setState(() => _selectedStore = null),
                  onTap: () => _openSearchDialog(
                    title: 'Rechercher un Magasin',
                    items: _stores,
                    onSelected: (item) => setState(() => _selectedStore = item),
                    onAddPressed: _addNewStore,
                    addButtonLabel: '+ Nouveau Magasin',
                  ),
                ),

              const SizedBox(height: 12),
              TextFormField(
                controller: _managerNameController,
                decoration: InputDecoration(labelText: 'Nom du Gérant/Contact', border: defaultBorder, prefixIcon: const Icon(Icons.badge_outlined)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _managerEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: 'Email (Optionnel)', border: defaultBorder, prefixIcon: const Icon(Icons.alternate_email_rounded)),
              ),
              const SizedBox(height: 16),

              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedTicketType,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.blue),
                    items: const [
                      DropdownMenuItem(value: 'standard', child: Text('Réparation Standard (Atelier)')),
                      DropdownMenuItem(value: 'removal', child: Text('Dépose Matériel (Laissé sur site)')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _selectedTicketType = value);
                    },
                  ),
                ),
              ),

              Container(
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _buildModeButton('Individuel (1 SAV/Article)', 'individual', Icons.list),
                    const SizedBox(width: 4),
                    _buildModeButton('Groupé (1 SAV Global)', 'grouped', Icons.folder_copy_outlined),
                  ],
                ),
              ),

              const Divider(height: 24),
              const Text('Appareils à Récupérer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openProductSearch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue.shade800,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.blue.shade200)),
                  ),
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: const Text('AJOUTER DES APPAREILS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 16),

              if (_itemEditors.isEmpty)
                Container(
                  padding: const EdgeInsets.all(30),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300, style: BorderStyle.none),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text("Aucun appareil ajouté", style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _itemEditors.length,
                  itemBuilder: (context, index) {
                    final editor = _itemEditors[index];
                    return Card(
                      key: editor.key,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.blue.shade100,
                                  child: Text('${index + 1}', style: TextStyle(color: Colors.blue.shade800, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(editor.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red, size: 20),
                                  onPressed: () => _removeEditor(index),
                                ),
                              ],
                            ),
                            const Divider(),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: editor.serialController,
                                    decoration: InputDecoration(
                                      labelText: 'Numéro de Série',
                                      isDense: true,
                                      border: const OutlineInputBorder(),
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.qr_code_scanner),
                                        onPressed: () => _scanSerialForEditor(index),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: editor.problemController,
                              decoration: const InputDecoration(labelText: 'Description Panne', isDense: true, border: OutlineInputBorder()),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

              const Divider(height: 24),
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: InputDecoration(labelText: 'Date de récupération', border: defaultBorder, prefixIcon: const Icon(Icons.calendar_today_outlined)),
                  child: Text(_pickupDate == null ? 'Sélectionner une date' : DateFormat('dd MMMM yyyy', 'fr_FR').format(_pickupDate!)),
                ),
              ),
              const SizedBox(height: 16),
              MultiSelectDialogField<UserViewModel>(
                items: _availableTechnicians.map((u) => MultiSelectItem<UserViewModel>(u, u.name)).toList(),
                title: const Text('Techniciens'),
                buttonText: _isLoadingTechnicians ? const Text('Chargement...') : const Text('Assigner techniciens'),
                onConfirm: (results) => setState(() => _selectedTechnicians = results),
                chipDisplay: MultiSelectChipDisplay(chipColor: primaryColor.withOpacity(0.1), textStyle: const TextStyle(color: primaryColor)),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                validator: (vals) => vals == null || vals.isEmpty ? 'Assigner au moins un' : null,
              ),

              const Divider(height: 30),
              OutlinedButton.icon(
                onPressed: _pickMediaFiles,
                icon: const Icon(Icons.perm_media_outlined),
                label: Text('Photos/Vidéos Globales (${_pickedMediaFiles.length})'),
              ),
              if (_pickedMediaFiles.isNotEmpty)
                Container(
                  height: 80,
                  margin: const EdgeInsets.only(top: 8),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _pickedMediaFiles.length,
                    itemBuilder: (context, index) {
                      final file = _pickedMediaFiles[index];
                      final isVideo = _isVideoPath(file.path);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(borderRadius: BorderRadius.circular(8), child: isVideo ? Container(width: 80, color: Colors.black, child: const Icon(Icons.videocam, color: Colors.white)) : Image.file(file, width: 80, height: 80, fit: BoxFit.cover)),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickAttachedFile,
                      icon: const Icon(Icons.attach_file),
                      label: Text(_attachedFile == null ? 'Joindre un Fichier (Optionnel)' : 'Fichier joint: ${path.basename(_attachedFile!.path)}'),
                    ),
                  ),
                  if (_attachedFile != null)
                    IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() => _attachedFile = null)),
                ],
              ),

              const Divider(height: 40),
              const Text('Signature du Gérant/Contact', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
              const SizedBox(height: 8),
              Container(
                height: 120,
                decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(12)),
                child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Signature(controller: _signatureController, backgroundColor: Colors.grey.shade100)),
              ),
              Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => _signatureController.clear(), child: const Text('Effacer'))),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveTicket,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.check_circle_outline),
                  label: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(_creationMode == 'grouped' ? 'VALIDER 1 SAV GROUPÉ (${_itemEditors.length} Articles)' : 'VALIDER ${_itemEditors.length} SAV INDIVIDUELS'),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}