// lib/screens/administration/add_store_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http; // ✅ ADDED FOR LINK RESOLVING
import 'package:intl/intl.dart'; // ✅ NEW: For Date Formatting
import 'package:boitex_info_app/screens/administration/add_client_page.dart' show ContactInfo;
import 'package:boitex_info_app/screens/widgets/location_picker_page.dart';
import 'package:latlong2/latlong.dart';

// ✅ NEW: Import Service Contracts
import 'package:boitex_info_app/models/service_contracts.dart';

class AddStorePage extends StatefulWidget {
  final String clientId;
  final String? storeId;
  final Map<String, dynamic>? initialData;

  const AddStorePage({
    super.key,
    required this.clientId,
    this.storeId,
    this.initialData,
  });

  @override
  State<AddStorePage> createState() => _AddStorePageState();
}

class _AddStorePageState extends State<AddStorePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _locationController;

  // GPS & Map Controllers
  late TextEditingController _latController;
  late TextEditingController _lngController;

  // ✅ NEW: Link Controller
  late TextEditingController _linkController;

  bool _isLoading = false;
  late bool _isEditMode;
  List<ContactInfo> _storeContacts = [];
  bool _gettingLocation = false;
  bool _isResolvingLink = false; // Loading state for link extraction

  // ✅ NEW: Contract State
  bool _hasContract = false;
  String _contractType = 'Standard';
  DateTime? _contractStartDate;
  DateTime? _contractEndDate;
  final TextEditingController _contractDocUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.storeId != null;
    _nameController = TextEditingController();
    _locationController = TextEditingController();
    _latController = TextEditingController();
    _lngController = TextEditingController();
    _linkController = TextEditingController(); // Init link controller

    // Pre-fill form if editing
    if (_isEditMode && widget.initialData != null) {
      _nameController.text = widget.initialData!['name'] ?? '';
      _locationController.text = widget.initialData!['location'] ?? '';

      if (widget.initialData!['latitude'] != null) {
        _latController.text = widget.initialData!['latitude'].toString();
      }
      if (widget.initialData!['longitude'] != null) {
        _lngController.text = widget.initialData!['longitude'].toString();
      }

      final List<dynamic> contactsData = widget.initialData!['storeContacts'] ?? [];
      _storeContacts = contactsData
          .asMap()
          .entries
          .map((entry) => ContactInfo.fromMap(entry.value as Map<String, dynamic>, entry.key.toString()))
          .toList();

      // ✅ NEW: Load Contract Data
      if (widget.initialData!['maintenance_contract'] != null) {
        try {
          final contractMap = widget.initialData!['maintenance_contract'];
          final contract = MaintenanceContract.fromMap(contractMap);
          _hasContract = true; // If data exists, assume tracking is on
          _contractType = contract.type;
          _contractStartDate = contract.startDate;
          _contractEndDate = contract.endDate;
          _contractDocUrlController.text = contract.docUrl ?? '';
        } catch (e) {
          print("Error loading contract: $e");
        }
      }
    }

    // Default dates if new or not set
    if (_contractStartDate == null) {
      _contractStartDate = DateTime.now();
      _contractEndDate = DateTime.now().add(const Duration(days: 365));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _linkController.dispose();
    _contractDocUrlController.dispose();
    super.dispose();
  }

  // --- 🔗 GOOGLE MAPS LINK PARSER ---
  Future<void> _extractCoordinatesFromLink() async {
    String url = _linkController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isResolvingLink = true);

    try {
      // 1. Resolve Short Links (e.g. https://maps.app.goo.gl/...)
      if (url.contains('goo.gl') || url.contains('maps.app.goo.gl') || url.contains('bit.ly')) {
        final client = http.Client();
        var request = http.Request('HEAD', Uri.parse(url));
        request.followRedirects = false;
        var response = await client.send(request);
        if (response.headers['location'] != null) {
          url = response.headers['location']!;
        }
      }

      // 2. Regex to find coordinates in the full URL
      // Matches patterns like @36.75,3.04 or q=36.75,3.04
      RegExp regExp = RegExp(r'(@|q=)([-+]?\d{1,2}\.\d+),([-+]?\d{1,3}\.\d+)');
      Match? match = regExp.firstMatch(url);

      if (match != null && match.groupCount >= 3) {
        String lat = match.group(2)!;
        String lng = match.group(3)!;

        setState(() {
          _latController.text = lat;
          _lngController.text = lng;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ Coordonnées extraites avec succès !")),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("❌ Impossible de trouver les coordonnées dans ce lien."),
                backgroundColor: Colors.orange
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de l'analyse : $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isResolvingLink = false);
    }
  }

  // --- 📍 GPS LOGIC ---
  Future<void> _getCurrentLocation() async {
    setState(() => _gettingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) _showError("Veuillez activer la localisation (GPS).");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) _showError("Permission de localisation refusée.");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) _showError("Permission de localisation refusée définitivement.");
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latController.text = position.latitude.toString();
        _lngController.text = position.longitude.toString();
      });

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("📍 Position GPS récupérée avec succès"))
        );
      }
    } catch (e) {
      if (mounted) _showError("Erreur GPS: $e");
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  // --- 🗺️ MAP PICKER LOGIC ---
  Future<void> _pickOnMap() async {
    double? currentLat = double.tryParse(_latController.text);
    double? currentLng = double.tryParse(_lngController.text);

    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerPage(
          initialLat: currentLat,
          initialLng: currentLng,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _latController.text = result.latitude.toString();
        _lngController.text = result.longitude.toString();
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // ✅ NEW: Date Picker Helper
  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? _contractStartDate : _contractEndDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _contractStartDate = picked;
          // Auto adjust end date if it's before start
          if (_contractEndDate != null && _contractEndDate!.isBefore(picked)) {
            _contractEndDate = picked.add(const Duration(days: 365));
          }
        } else {
          _contractEndDate = picked;
        }
      });
    }
  }

  // ... (Contact Dialog Logic) ...
  Future<void> _showContactDialog({ContactInfo? existingContact, int? index}) async {
    final GlobalKey<FormState> dialogFormKey = GlobalKey<FormState>();
    String type = existingContact?.type ?? 'Téléphone';
    final labelController = TextEditingController(text: existingContact?.label ?? '');
    final valueController = TextEditingController(text: existingContact?.value ?? '');

    final result = await showDialog<ContactInfo>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(existingContact == null ? 'Ajouter Contact Magasin' : 'Modifier Contact Magasin'),
                content: Form(
                  key: dialogFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: type,
                        items: ['Téléphone', 'E-mail']
                            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            type = value!;
                          });
                        },
                        decoration: const InputDecoration(labelText: 'Type'),
                      ),
                      TextFormField(
                        controller: labelController,
                        decoration: const InputDecoration(labelText: 'Étiquette (Ex: Manager)'),
                        validator: (value) => value == null || value.isEmpty ? 'Étiquette requise' : null,
                      ),
                      TextFormField(
                        controller: valueController,
                        decoration: InputDecoration(labelText: type == 'Téléphone' ? 'Numéro' : 'Adresse E-mail'),
                        keyboardType: type == 'Téléphone' ? TextInputType.phone : TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Valeur requise';
                          }
                          if (type == 'E-mail' && !value.contains('@')) {
                            return 'E-mail invalide';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Annuler'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (dialogFormKey.currentState!.validate()) {
                        Navigator.of(context).pop(ContactInfo(
                          type: type,
                          label: labelController.text.trim(),
                          value: valueController.text.trim(),
                          id: existingContact?.id,
                        ));
                      }
                    },
                    child: const Text('Enregistrer'),
                  ),
                ],
              );
            }
        );
      },
    );

    if (result != null) {
      setState(() {
        if (existingContact != null && index != null) {
          _storeContacts[index] = result;
        } else {
          _storeContacts.add(result);
        }
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {

      // ✅ NEW: Validate Contract Dates if enabled
      if (_hasContract && (_contractStartDate == null || _contractEndDate == null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez définir les dates du contrat'), backgroundColor: Colors.red),
        );
        return;
      }

      setState(() { _isLoading = true; });

      final List<Map<String, dynamic>> contactsForDb = _storeContacts.map((c) => c.toMap()).toList();

      double? lat = double.tryParse(_latController.text);
      double? lng = double.tryParse(_lngController.text);

      // ✅ NEW: Prepare Contract Data
      Map<String, dynamic>? contractData;
      if (_hasContract) {
        final contract = MaintenanceContract(
          id: widget.initialData?['maintenance_contract']?['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
          type: _contractType,
          startDate: _contractStartDate!,
          endDate: _contractEndDate!,
          isActive: true, // If saved here, it is considered active
          docUrl: _contractDocUrlController.text.trim().isEmpty ? null : _contractDocUrlController.text.trim(),
        );
        contractData = contract.toMap();
      }

      final storeData = {
        'name': _nameController.text.trim(),
        'location': _locationController.text.trim(),
        'latitude': lat,
        'longitude': lng,
        'storeContacts': contactsForDb,

        // ✅ IMPORTANT: Soft Delete Support
        // If it's a new store, force 'active'. If editing, keep existing or fallback to active.
        'status': _isEditMode ? (widget.initialData?['status'] ?? 'active') : 'active',

        // ✅ NEW: Save or Remove Contract
        'maintenance_contract': _hasContract ? contractData : FieldValue.delete(),
      };

      // ✅ Add creation timestamp only for new stores
      if (!_isEditMode) {
        storeData['createdAt'] = FieldValue.serverTimestamp();
      }

      try {
        final storeCollectionRef = FirebaseFirestore.instance
            .collection('clients')
            .doc(widget.clientId)
            .collection('stores');

        if (_isEditMode) {
          await storeCollectionRef.doc(widget.storeId!).update(storeData);
        } else {
          await storeCollectionRef.add(storeData);
        }

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_isEditMode ? 'Magasin mis à jour' : 'Magasin ajouté'))
          );
        }
      } catch (e) {
        print("Erreur lors de l'enregistrement du magasin: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red)
          );
        }
      } finally {
        if(mounted) {
          setState(() { _isLoading = false; });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Colors.teal;
    final defaultBorder = OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12.0)
    );
    final focusedBorder = OutlineInputBorder(
        borderSide: BorderSide(color: primaryColor, width: 2.0),
        borderRadius: BorderRadius.circular(12.0)
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Modifier Magasin' : 'Ajouter Magasin'),
        backgroundColor: primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nom du Magasin (ex: Zara)',
                  enabledBorder: defaultBorder,
                  focusedBorder: focusedBorder,
                  floatingLabelStyle: const TextStyle(color: primaryColor),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Veuillez entrer un nom' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'Emplacement (ex: Bab Ezzouar Mall)',
                  enabledBorder: defaultBorder,
                  focusedBorder: focusedBorder,
                  floatingLabelStyle: const TextStyle(color: primaryColor),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Veuillez entrer un emplacement' : null,
              ),
              const SizedBox(height: 24),

              // ✅ 3. ENHANCED GPS SECTION
              const Text('Géolocalisation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    // --- A. Google Maps Link Input ---
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _linkController,
                            decoration: const InputDecoration(
                              labelText: 'Coller un lien Google Maps',
                              hintText: 'https://maps.app.goo.gl/...',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              prefixIcon: Icon(Icons.link),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isResolvingLink ? null : _extractCoordinatesFromLink,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          ),
                          child: _isResolvingLink
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text("Extraire"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),

                    // --- B. Lat/Long Inputs ---
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Latitude',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _lngController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Longitude',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // --- C. Action Buttons ---
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _gettingLocation ? null : _getCurrentLocation,
                            icon: _gettingLocation
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.my_location),
                            label: const Text("GPS Actuel"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _pickOnMap,
                            icon: const Icon(Icons.map),
                            label: const Text("Sur la Carte"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Divider(),

              // --- ✅ NEW: Contrat de Maintenance ---
              const Text("Contrat de Maintenance", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Contrat Actif", style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text("Ce magasin dispose-t-il d'un contrat de maintenance ?"),
                value: _hasContract,
                onChanged: (val) => setState(() => _hasContract = val),
                activeColor: primaryColor,
              ),

              if (_hasContract) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _contractType,
                        decoration: const InputDecoration(labelText: 'Type de Contrat', filled: true, fillColor: Colors.white),
                        items: ['Standard', 'Gold', 'Platinum', 'Préventif', 'Sur Devis']
                            .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => _contractType = v!),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _pickDate(true),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Date de Début',
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: Icon(Icons.calendar_today, size: 18),
                                ),
                                child: Text(_contractStartDate != null
                                    ? DateFormat('dd/MM/yyyy').format(_contractStartDate!)
                                    : 'Choisir'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () => _pickDate(false),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Date de Fin',
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: Icon(Icons.event_busy, size: 18),
                                ),
                                child: Text(_contractEndDate != null
                                    ? DateFormat('dd/MM/yyyy').format(_contractEndDate!)
                                    : 'Choisir'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _contractDocUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Lien du document (PDF/Drive)',
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: Icon(Icons.attach_file),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              const Divider(),

              const Text('Contacts du Magasin:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              if (_storeContacts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(child: Text('Aucun contact ajouté.', style: TextStyle(color: Colors.grey))),
                ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _storeContacts.length,
                itemBuilder: (context, index) {
                  final contact = _storeContacts[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(contact.icon, color: primaryColor),
                      title: Text(contact.value),
                      subtitle: Text(contact.label),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.orange),
                            tooltip: 'Modifier',
                            onPressed: () => _showContactDialog(existingContact: contact, index: index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: 'Supprimer',
                            onPressed: () {
                              setState(() {
                                _storeContacts.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Center(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter un Contact Magasin'),
                  onPressed: () => _showContactDialog(),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(_isEditMode ? Icons.save : Icons.add_business_outlined),
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                  ),
                  label: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : Text(_isEditMode ? 'Enregistrer les Modifications' : 'Enregistrer le Magasin'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}