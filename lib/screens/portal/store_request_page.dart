// lib/screens/portal/store_request_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart'; // Ensure you have this in pubspec.yaml
import 'package:flutter/foundation.dart' show kIsWeb;

class StoreRequestPage extends StatefulWidget {
  final String storeId;
  final String token;

  const StoreRequestPage({
    super.key,
    required this.storeId,
    required this.token,
  });

  @override
  State<StoreRequestPage> createState() => _StoreRequestPageState();
}

class _StoreRequestPageState extends State<StoreRequestPage> {
  // State
  bool _isLoading = true;
  bool _isValidSession = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  // Store Data
  DocumentSnapshot? _storeDoc;
  DocumentSnapshot? _clientDoc;
  List<QueryDocumentSnapshot> _equipmentList = [];

  // Form Fields
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  String? _selectedEquipmentId;
  String? _selectedEquipmentName;

  // Media
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _verifyAndLoadData();
  }

  /// 1. Security Check & Data Loading
  Future<void> _verifyAndLoadData() async {
    try {
      // A. Search for the store across all clients using Collection Group
      // Note: This requires a Firestore Index if you have many stores.
      // If it fails, check debug console for the index link.
      final storeQuery = await FirebaseFirestore.instance
          .collectionGroup('stores')
          .where(FieldPath.documentId, isEqualTo: widget.storeId)
          .get();

      if (storeQuery.docs.isEmpty) {
        throw "Magasin introuvable (ID invalide).";
      }

      final storeDoc = storeQuery.docs.first;
      final storeData = storeDoc.data() as Map<String, dynamic>;

      // B. Verify the Security Token
      if (storeData['qr_access_token'] != widget.token) {
        throw "Lien expiré ou non autorisé.";
      }

      // C. Load Parent Client Info
      // The store is at clients/{clientId}/stores/{storeId}
      // So parent().parent() gives us the client doc ref
      final clientRef = storeDoc.reference.parent.parent;
      if (clientRef == null) throw "Structure de données invalide.";

      final clientDoc = await clientRef.get();

      // D. Load Equipment List for Dropdown
      final equipmentQuery = await storeDoc.reference
          .collection('materiel_installe') // Matches your schema
          .get();

      if (mounted) {
        setState(() {
          _storeDoc = storeDoc;
          _clientDoc = clientDoc;
          _equipmentList = equipmentQuery.docs;
          _isValidSession = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isValidSession = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  /// 2. Image Picker Logic
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 50, // Optimize for mobile data
      );
      if (image != null) {
        setState(() => _selectedImage = image);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur caméra: $e")),
      );
    }
  }

  /// 3. Submit Logic
  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez décrire le problème.")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? imageUrl;

      // A. Upload Image if exists
      if (_selectedImage != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('interventions_media')
            .child('${const Uuid().v4()}.jpg');

        if (kIsWeb) {
          await storageRef.putData(await _selectedImage!.readAsBytes());
        } else {
          await storageRef.putFile(File(_selectedImage!.path));
        }
        imageUrl = await storageRef.getDownloadURL();
      }

      // B. Create Intervention Ticket
      // Matches your schema in add_intervention_page.dart
      final clientData = _clientDoc!.data() as Map<String, dynamic>;
      final storeData = _storeDoc!.data() as Map<String, dynamic>;

      await FirebaseFirestore.instance.collection('interventions').add({
        // Core linking fields
        'clientId': _clientDoc!.id,
        'clientName': clientData['name'] ?? 'Client Inconnu',
        'storeId': _storeDoc!.id,
        'storeName': storeData['name'] ?? 'Magasin Inconnu',
        'storeLocation': storeData['location'] ?? '',

        // Request Details
        'status': 'Nouvelle Demande', // Important trigger status
        'source': 'QR_Portal', // To track where it came from
        'priority': 'Moyenne', // Default
        'description': _descriptionController.text.trim(),
        'contactName': _contactController.text.trim(),

        // Asset Linking (Crucial for history)
        'equipmentId': _selectedEquipmentId,
        'equipmentName': _selectedEquipmentName,

        // Media
        'photos': imageUrl != null ? [imageUrl] : [],

        // Metadata
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': 'Portal Manager', // Since they aren't logged in
      });

      // C. Success UI
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Icon(Icons.check_circle, color: Colors.green, size: 50),
            content: const Text(
              "Votre demande a été envoyée !\n\nNos techniciens ont été notifiés.",
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  // Reset form for next request
                  setState(() {
                    _descriptionController.clear();
                    _selectedImage = null;
                    _selectedEquipmentId = null;
                    _isSubmitting = false;
                  });
                },
                child: const Text("OK"),
              )
            ],
          ),
        );
      }

    } catch (e) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur d'envoi: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 4. Loading State
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text("Vérification de l'accès sécurisé..."),
            ],
          ),
        ),
      );
    }

    // 5. Error State (Invalid Token)
    if (!_isValidSession) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.security, size: 80, color: Colors.red),
                const SizedBox(height: 24),
                Text(
                  "Accès Refusé",
                  style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage ?? "Ce QR code est invalide ou a été désactivé.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 6. Main Portal UI
    final storeName = (_storeDoc!.data() as Map<String, dynamic>)['name'] ?? 'Magasin';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text("Support: $storeName"),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        automaticallyImplyLeading: false, // No back button
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Scannez ce code pour signaler rapidement une panne dans le magasin $storeName.",
                        style: const TextStyle(color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Equipment Dropdown
              Text("Quel équipement est en panne ?", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text("Sélectionner un appareil (Optionnel)"),
                    value: _selectedEquipmentId,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text("Autre / Je ne sais pas"),
                      ),
                      ..._equipmentList.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return DropdownMenuItem(
                          value: doc.id,
                          child: Text("${data['nom']} (${data['marque'] ?? ''})"),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedEquipmentId = val;
                        if (val != null) {
                          final doc = _equipmentList.firstWhere((d) => d.id == val);
                          final data = doc.data() as Map<String, dynamic>;
                          _selectedEquipmentName = "${data['nom']} ${data['marque'] ?? ''}";
                        } else {
                          _selectedEquipmentName = null;
                        }
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Contact Name
              Text("Votre Nom / Poste", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _contactController,
                decoration: InputDecoration(
                  hintText: "Ex: Manager, Caisse 1...",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
                validator: (val) => val == null || val.isEmpty ? "Requis" : null,
              ),

              const SizedBox(height: 20),

              // Description
              Text("Description du problème", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: "Décrivez la panne (ex: L'écran ne s'allume pas, erreur 404...)",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
                validator: (val) => val == null || val.isEmpty ? "Requis" : null,
              ),

              const SizedBox(height: 20),

              // Photo Button
              Text("Photo (Optionnel)", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: kIsWeb
                        ? Image.network(_selectedImage!.path, fit: BoxFit.cover)
                        : Image.file(File(_selectedImage!.path), fit: BoxFit.cover),
                  )
                      : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text("Appuyer pour prendre une photo", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667EEA), // Brand Color
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    "ENVOYER LA DEMANDE",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}