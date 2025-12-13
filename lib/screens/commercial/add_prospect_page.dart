// lib/screens/commercial/add_prospect_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:boitex_info_app/models/prospect.dart';

// Imports for Media & B2
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

// ⚡ Cloud Functions Import
import 'package:cloud_functions/cloud_functions.dart';

class AddProspectPage extends StatefulWidget {
  final Prospect? prospectToEdit;

  const AddProspectPage({super.key, this.prospectToEdit});

  @override
  State<AddProspectPage> createState() => _AddProspectPageState();
}

class _AddProspectPageState extends State<AddProspectPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers
  final _companyNameController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _roleController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _streetDetailsController = TextEditingController();
  final _notesController = TextEditingController();
  final _otherServiceController = TextEditingController();

  // Locations & Services
  String? _selectedCommune;
  final List<String> _communesAlger = [
    'Alger-Centre', "Sidi M'Hamed", 'El Madania', 'Belouizdad', 'Bab El Oued',
    'Bologhine', 'Casbah', 'Oued Koriche', 'Bir Mourad Raïs', 'El Biar',
    'Bouzareah', 'Birkhadem', 'El Harrach', 'Baraki', 'Oued Smar',
    'Bachdjerrah', 'Hussein Dey', 'Kouba', 'Bourouba', 'Dar El Beïda',
    'Bab Ezzouar', 'Ben Aknoun', 'Dely Ibrahim', 'Hammamet', 'Raïs Hamidou',
    'Djasr Kasentina', 'El Mouradia', 'Hydra', 'Mohammadia', 'Bordj El Kiffan',
    'El Magharia', 'Beni Messous', 'Les Eucalyptus', 'Birtouta', 'Tessala El Merdja',
    'Ouled Chebel', 'Sidi Moussa', 'Aïn Taya', 'Bordj El Bahri', 'El Marsa',
    "H'Raoua", 'Rouïba', 'Reghaïa', 'Aïn Benian', 'Staoueli',
    'Zeralda', 'Mahelma', 'Rahmania', 'Souidania', 'Cheraga',
    'Ouled Fayet', 'El Achour', 'Draria', 'Douera', 'Baba Hassen',
    'Khraicia', 'Saoula'
  ]..sort();

  String? _selectedServiceType;
  final List<String> _serviceTypes = [
    'Fast Food / Snack',
    'Restaurant',
    'Magasin de Vêtements',
    'Supermarché / Supérette',
    'Pharmacie',
    'Boulangerie',
    'Autre',
  ];

  // ⚡ PIPELINE STATUS
  String _selectedStatus = 'Nouveau';
  final List<String> _statusOptions = [
    'Nouveau',
    'Intéressé',
    'Gagné / Client',
    'Perdu',
  ];

  Position? _currentPosition;
  bool _gettingLocation = false;

  // Media
  List<File> _localFilesToUpload = [];
  bool _isUploadingMedia = false;

  List<String> _existingPhotoUrls = [];
  List<String> _existingVideoUrls = [];

  @override
  void initState() {
    super.initState();
    if (widget.prospectToEdit != null) {
      _initializeEditMode(widget.prospectToEdit!);
    }
  }

  void _initializeEditMode(Prospect p) {
    _companyNameController.text = p.companyName;
    _contactNameController.text = p.contactName;
    _roleController.text = p.role;
    _phoneController.text = p.phoneNumber;
    _emailController.text = p.email;
    _notesController.text = p.notes;

    // ⚡ Load existing status
    if (_statusOptions.contains(p.status)) {
      _selectedStatus = p.status;
    }

    if (p.latitude != null && p.longitude != null) {
      _currentPosition = Position(
          longitude: p.longitude!,
          latitude: p.latitude!,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0
      );
    }

    if (_communesAlger.contains(p.commune)) {
      _selectedCommune = p.commune;
    } else {
      _selectedCommune = null;
    }

    if (p.address.startsWith(p.commune)) {
      String details = p.address.substring(p.commune.length).trim();
      if (details.startsWith('- ')) {
        details = details.substring(2).trim();
      } else if (details.startsWith('-')) {
        details = details.substring(1).trim();
      }
      _streetDetailsController.text = details;
    } else {
      _streetDetailsController.text = p.address;
    }

    if (_serviceTypes.contains(p.serviceType)) {
      _selectedServiceType = p.serviceType;
    } else {
      _selectedServiceType = 'Autre';
      _otherServiceController.text = p.serviceType;
    }

    _existingPhotoUrls = List.from(p.photoUrls);
    _existingVideoUrls = List.from(p.videoUrls);
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _contactNameController.dispose();
    _roleController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _streetDetailsController.dispose();
    _notesController.dispose();
    _otherServiceController.dispose();
    super.dispose();
  }

  // --- ☁️ B2 HELPER FUNCTIONS ---
  Future<Map<String, dynamic>?> _getB2UploadCredentials() async {
    try {
      final result = await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('getB2UploadUrl')
          .call();

      return Map<String, dynamic>.from(result.data as Map);
    } catch (e) {
      debugPrint('Error calling Cloud Function: $e');
      return null;
    }
  }

  Future<String?> _uploadFileToB2(
      File file, Map<String, dynamic> b2Creds) async {
    try {
      final fileBytes = await file.readAsBytes();
      final sha1Hash = sha1.convert(fileBytes).toString();
      final uploadUri = Uri.parse(b2Creds['uploadUrl'] as String);
      final fileName = path.basename(file.path);

      String? mimeType;
      final extension = path.extension(fileName).toLowerCase();
      if (extension == '.jpg' || extension == '.jpeg') {
        mimeType = 'image/jpeg';
      } else if (extension == '.png') {
        mimeType = 'image/png';
      } else if (extension == '.mp4' || extension == '.mov') {
        mimeType = 'video/mp4';
      } else if (extension == '.pdf') {
        mimeType = 'application/pdf';
      } else {
        mimeType = 'b2/x-auto';
      }

      final resp = await http.post(
        uploadUri,
        headers: {
          'Authorization': b2Creds['authorizationToken'] as String,
          'X-Bz-File-Name': Uri.encodeComponent(fileName),
          'Content-Type': mimeType,
          'X-Bz-Content-Sha1': sha1Hash,
          'Content-Length': fileBytes.length.toString(),
        },
        body: fileBytes,
      );

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        final encodedPath = (body['fileName'] as String)
            .split('/')
            .map(Uri.encodeComponent)
            .join('/');
        return (b2Creds['downloadUrlPrefix'] as String) + encodedPath;
      } else {
        debugPrint('Failed to upload to B2: ${resp.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading file to B2: $e');
      return null;
    }
  }

  // --- 📂 MEDIA PICKER LOGIC ---
  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'mp4', 'mov', 'pdf'],
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        final newFiles = result.paths
            .where((p) => p != null)
            .map((p) => File(p!))
            .toList();
        _localFilesToUpload.addAll(newFiles);
      });
    }
  }

  Future<void> _capturePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? xFile = await picker.pickImage(source: ImageSource.camera);
    if (xFile != null) {
      setState(() {
        _localFilesToUpload.add(File(xFile.path));
      });
    }
  }

  Future<void> _captureVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? xFile = await picker.pickVideo(source: ImageSource.camera);
    if (xFile != null) {
      setState(() {
        _localFilesToUpload.add(File(xFile.path));
      });
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
        if (mounted)
          _showError("Permission de localisation refusée définitivement.");
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      if (mounted) _showError("Erreur GPS: $e");
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<Widget> _getLeadingIcon(String filePath) async {
    final extension = path.extension(filePath).toLowerCase();
    if (extension == '.jpg' || extension == '.jpeg' || extension == '.png') {
      return const Icon(Icons.image, color: Colors.green);
    } else if (extension == '.mp4' || extension == '.mov') {
      try {
        final thumbPath = await VideoThumbnail.thumbnailFile(
          video: filePath,
          imageFormat: ImageFormat.JPEG,
          maxHeight: 64,
          quality: 50,
        );
        if (thumbPath != null) {
          return Image.file(File(thumbPath),
              width: 40, height: 40, fit: BoxFit.cover);
        }
      } catch (e) {
        debugPrint('Thumbnail error: $e');
      }
      return const Icon(Icons.videocam, color: Colors.purple);
    } else if (extension == '.pdf') {
      return const Icon(Icons.picture_as_pdf, color: Colors.red);
    }
    return const Icon(Icons.insert_drive_file, color: Colors.blue);
  }

  Widget _buildMediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("📷 Photos & Médias"),
        const SizedBox(height: 10),

        if (_existingPhotoUrls.isNotEmpty || _existingVideoUrls.isNotEmpty) ...[
          const Text('Médias existants (sur le serveur) :',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 8),
          Container(
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ..._existingPhotoUrls.map((url) => _buildExistingMediaItem(url, true)),
                ..._existingVideoUrls.map((url) => _buildExistingMediaItem(url, false)),
              ],
            ),
          ),
          const Divider(),
        ],

        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isUploadingMedia ? null : _capturePhoto,
                icon: const Icon(Icons.photo_camera),
                label: const Text('Photo'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isUploadingMedia ? null : _captureVideo,
                icon: const Icon(Icons.videocam),
                label: const Text('Vidéo'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade600,
                    foregroundColor: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isUploadingMedia ? null : _pickFiles,
                icon: const Icon(Icons.attach_file),
                label: const Text('Fichier'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_localFilesToUpload.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Fichiers à envoyer:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const Divider(),
                ..._localFilesToUpload.asMap().entries.map((entry) {
                  final index = entry.key;
                  final file = entry.value;
                  return ListTile(
                    dense: true,
                    leading: FutureBuilder<Widget>(
                      future: _getLeadingIcon(file.path),
                      builder: (context, snapshot) {
                        return snapshot.data ?? const Icon(Icons.file_present);
                      },
                    ),
                    title: Text(path.basename(file.path),
                        overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => setState(
                              () => _localFilesToUpload.removeAt(index)),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildExistingMediaItem(String url, bool isPhoto) {
    return Stack(
      children: [
        Container(
          width: 80,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
            image: isPhoto
                ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
                : null,
            color: isPhoto ? null : Colors.black12,
          ),
          child: !isPhoto
              ? const Center(child: Icon(Icons.videocam, color: Colors.purple))
              : null,
        ),
        Positioned(
          top: 0,
          right: 4,
          child: InkWell(
            onTap: () {
              setState(() {
                if (isPhoto) {
                  _existingPhotoUrls.remove(url);
                } else {
                  _existingVideoUrls.remove(url);
                }
              });
            },
            child: const CircleAvatar(
              radius: 10,
              backgroundColor: Colors.red,
              child: Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF333333),
      ),
    );
  }

  // --- 💾 SAVE LOGIC ---
  Future<void> _saveProspect() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedServiceType == null) {
      _showError("Veuillez sélectionner un type d'activité.");
      return;
    }
    if (_selectedCommune == null) {
      _showError("Veuillez sélectionner une commune.");
      return;
    }

    setState(() {
      _isLoading = true;
      _isUploadingMedia = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Utilisateur non connecté");

      final prospectId = widget.prospectToEdit?.id ?? const Uuid().v4();

      String authorName = 'Commercial';

      if (widget.prospectToEdit != null) {
        authorName = widget.prospectToEdit!.authorName;
      } else {
        try {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          if (userDoc.exists) {
            final data = userDoc.data()!;
            if (data.containsKey('fullName')) {
              authorName = data['fullName'];
            } else if (data.containsKey('name')) {
              authorName = data['name'];
            }
          }
        } catch (e) {
          debugPrint('Could not fetch user name: $e');
        }
      }

      List<String> photoUrls = List.from(_existingPhotoUrls);
      List<String> videoUrls = List.from(_existingVideoUrls);

      if (_localFilesToUpload.isNotEmpty) {
        final b2Credentials = await _getB2UploadCredentials();
        if (b2Credentials == null) {
          throw Exception(
              'Impossible de récupérer les accès B2 pour le téléchargement.');
        }

        final uploadTasks = _localFilesToUpload.map((file) async {
          final url = await _uploadFileToB2(file, b2Credentials);
          if (url != null) {
            final ext = path.extension(file.path).toLowerCase();
            final isImage = ['.jpg', '.jpeg', '.png'].contains(ext);
            return MapEntry(isImage ? 'photo' : 'video', url);
          }
          return null;
        });

        final results = await Future.wait(uploadTasks);

        for (var result in results) {
          if (result != null) {
            if (result.key == 'photo') {
              photoUrls.add(result.value);
            } else {
              videoUrls.add(result.value);
            }
          }
        }
      }

      String fullAddress = _selectedCommune!;
      if (_streetDetailsController.text.isNotEmpty) {
        fullAddress += ' - ${_streetDetailsController.text.trim()}';
      }

      String finalServiceType = _selectedServiceType!;
      if (_selectedServiceType == 'Autre') {
        if (_otherServiceController.text.trim().isEmpty) {
          throw Exception("Veuillez préciser le type d'activité.");
        }
        finalServiceType = _otherServiceController.text.trim();
      }

      final newProspect = Prospect(
        id: prospectId,
        companyName: _companyNameController.text.trim(),
        contactName: _contactNameController.text.trim(),
        role: _roleController.text.trim(),
        serviceType: finalServiceType,
        phoneNumber: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        commune: _selectedCommune!,
        address: fullAddress,
        latitude: _currentPosition?.latitude ?? widget.prospectToEdit?.latitude,
        longitude: _currentPosition?.longitude ?? widget.prospectToEdit?.longitude,
        photoUrls: photoUrls,
        videoUrls: videoUrls,
        notes: _notesController.text.trim(),
        createdAt: widget.prospectToEdit?.createdAt ?? DateTime.now(),
        createdBy: widget.prospectToEdit?.createdBy ?? user.uid,
        authorName: authorName,
        status: _selectedStatus, // ⚡ SAVE STATUS
      );

      await FirebaseFirestore.instance
          .collection('prospects')
          .doc(prospectId)
          .set(newProspect.toMap(), SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.prospectToEdit != null ? "Prospect mis à jour !" : "Prospect enregistré !")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showError("Erreur lors de l'enregistrement: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUploadingMedia = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.prospectToEdit != null ? "Modifier Prospect" : "Nouveau Prospect"),
        backgroundColor: const Color(0xFFFF9966),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle("🏢 Identité"),
              const SizedBox(height: 10),

              // ⚡ NEW STATUS DROPDOWN
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: "État du Prospect (Pipeline)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.flag),
                ),
                value: _selectedStatus,
                items: _statusOptions.map((status) {
                  return DropdownMenuItem(value: status, child: Text(status));
                }).toList(),
                onChanged: (val) => setState(() => _selectedStatus = val!),
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _companyNameController,
                decoration: const InputDecoration(
                  labelText: "Nom de l'enseigne (Magasin)*",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.store),
                ),
                validator: (v) => v!.isEmpty ? "Requis" : null,
              ),
              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: "Type d'activité*",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                value: _selectedServiceType,
                items: _serviceTypes.map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (val) => setState(() => _selectedServiceType = val),
              ),

              if (_selectedServiceType == 'Autre') ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: _otherServiceController,
                  decoration: const InputDecoration(
                    labelText: "Précisez l'activité*",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit_note),
                  ),
                  validator: (v) => v!.isEmpty ? "Requis pour 'Autre'" : null,
                ),
              ],

              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _contactNameController,
                      decoration: const InputDecoration(
                        labelText: "Nom du contact",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _roleController,
                      decoration: const InputDecoration(
                        labelText: "Rôle (Gérant...)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              _buildSectionTitle("📍 Contact & Localisation"),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Téléphone*",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: (v) => v!.isEmpty ? "Requis" : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),

              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: "Commune (Wilaya d'Alger)*",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_city),
                ),
                value: _selectedCommune,
                items: _communesAlger.map((commune) {
                  return DropdownMenuItem(value: commune, child: Text(commune));
                }).toList(),
                onChanged: (val) => setState(() => _selectedCommune = val),
                validator: (val) => val == null ? "Veuillez choisir une commune" : null,
              ),

              const SizedBox(height: 10),
              TextFormField(
                controller: _streetDetailsController,
                decoration: const InputDecoration(
                  labelText: "Détails (Rue, Repère, Quartier)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.map),
                ),
              ),

              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pin_drop, color: Colors.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _currentPosition == null
                          ? const Text("Position GPS non définie")
                          : Text(
                        "Lat: ${_currentPosition!.latitude.toStringAsFixed(5)}\nLng: ${_currentPosition!.longitude.toStringAsFixed(5)}",
                        style:
                        const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    _gettingLocation
                        ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                        : ElevatedButton.icon(
                      onPressed: _getCurrentLocation,
                      icon: const Icon(Icons.my_location),
                      label: const Text("Localiser"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              TextFormField(
                controller: _notesController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: "Notes / Observations / Besoins",
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 15),

              _buildMediaSection(),

              const SizedBox(height: 30),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: (_isLoading || _isUploadingMedia) ? null : _saveProspect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9966),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                    _isUploadingMedia
                        ? "TÉLÉCHARGEMENT..."
                        : (widget.prospectToEdit != null ? "METTRE À JOUR" : "ENREGISTRER LE PROSPECT"),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}