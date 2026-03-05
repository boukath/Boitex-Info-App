// lib/screens/administration/add_store_page.dart

import 'dart:ui';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// Imports for your core logic
import 'package:boitex_info_app/screens/administration/add_client_page.dart' show ContactInfo;
import 'package:boitex_info_app/screens/widgets/location_picker_page.dart';
import 'package:boitex_info_app/models/service_contracts.dart';

// Imports for B2 Upload & URL Resolution
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';

// 🎨 --- 2026 PREMIUM APPLE COLORS & CONSTANTS --- 🎨
const kTextDark = Color(0xFF1D1D1F);
const kTextSecondary = Color(0xFF86868B);
const kAppleBlue = Color(0xFF007AFF);
const kAppleGreen = Color(0xFF34C759);
const kAppleRed = Color(0xFFFF3B30);
const double kRadius = 24.0;

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

  // Controllers
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();

  // ✅ GPS Link Controller
  final _gpsLinkController = TextEditingController();
  bool _isResolvingLink = false;

  // ✅ Maintenance Contract State
  bool _hasContract = false;
  DateTime? _contractStart;
  DateTime? _contractEnd;
  final _preventiveController = TextEditingController();
  final _correctiveController = TextEditingController();
  int _usedPreventive = 0;
  int _usedCorrective = 0;

  // State
  bool _isLoading = false;
  bool _isUploadingLogo = false;
  double? _latitude;
  double? _longitude;
  String? _logoUrl;
  List<ContactInfo> _contacts = [];

  final String _getB2UploadUrlCloudFunctionUrl = 'https://europe-west1-boitexinfo-63060.cloudfunctions.net/getB2UploadUrl';

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _nameController.text = widget.initialData!['name'] ?? '';
      _locationController.text = widget.initialData!['location'] ?? '';
      _latitude = widget.initialData!['latitude']?.toDouble();
      _longitude = widget.initialData!['longitude']?.toDouble();
      _logoUrl = widget.initialData!['logoUrl'];

      if (widget.initialData!['contacts'] != null) {
        _contacts = (widget.initialData!['contacts'] as List).map((c) => ContactInfo(
          label: c['label'] ?? '',
          type: c['type'] ?? 'Téléphone',
          value: c['value'] ?? '',
        )).toList();
      }

      // ✅ Restore Maintenance Contract Logic
      if (widget.initialData!['maintenance_contract'] != null) {
        _hasContract = true;
        final mc = widget.initialData!['maintenance_contract'] as Map<String, dynamic>;
        _contractStart = (mc['startDate'] as Timestamp?)?.toDate();
        _contractEnd = (mc['endDate'] as Timestamp?)?.toDate();
        _preventiveController.text = (mc['quotaPreventive'] ?? 0).toString();
        _correctiveController.text = (mc['quotaCorrective'] ?? 0).toString();
        _usedPreventive = mc['usedPreventive'] ?? 0;
        _usedCorrective = mc['usedCorrective'] ?? 0;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _gpsLinkController.dispose();
    _preventiveController.dispose();
    _correctiveController.dispose();
    super.dispose();
  }

  bool get _isEditMode => widget.storeId != null;

  // ----------------------------------------------------------------------
  // 🔗 GPS LINK PARSER LOGIC
  // ----------------------------------------------------------------------
  Future<void> _extractCoordinatesFromLink() async {
    String url = _gpsLinkController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isResolvingLink = true);

    try {
      // 1. Resolve Short Links (e.g. goo.gl, bit.ly)
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
      RegExp regExp = RegExp(r'(@|q=)([-+]?\d{1,2}\.\d+),([-+]?\d{1,3}\.\d+)');
      Match? match = regExp.firstMatch(url);

      if (match != null && match.groupCount >= 3) {
        setState(() {
          _latitude = double.parse(match.group(2)!);
          _longitude = double.parse(match.group(3)!);
          _gpsLinkController.clear(); // Clear on success
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Coordonnées extraites avec succès!"), backgroundColor: kAppleGreen));
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ Impossible de trouver les coordonnées dans ce lien."), backgroundColor: Colors.orange));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur lors de l'analyse : $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isResolvingLink = false);
    }
  }

  // ----------------------------------------------------------------------
  // ☁️ B2 LOGO UPLOAD LOGIC
  // ----------------------------------------------------------------------
  Future<Map<String, dynamic>?> _getB2UploadCredentials() async {
    try {
      final response = await http.get(Uri.parse(_getB2UploadUrlCloudFunctionUrl));
      if (response.statusCode == 200) return json.decode(response.body) as Map<String, dynamic>;
      return null;
    } catch (e) { return null; }
  }

  Future<String?> _uploadFileToB2(PlatformFile file, Map<String, dynamic> b2Creds) async {
    try {
      final fileName = 'stores_logos/${DateTime.now().millisecondsSinceEpoch}_${file.name.replaceAll(' ', '_')}';
      final Uint8List bytes = kIsWeb ? file.bytes! : await File(file.path!).readAsBytes();
      final sha1Hash = sha1.convert(bytes).toString();
      final uploadUri = Uri.parse(b2Creds['uploadUrl'] as String);

      var request = http.StreamedRequest('POST', uploadUri);
      request.headers.addAll({
        'Authorization': b2Creds['authorizationToken'] as String,
        'X-Bz-File-Name': Uri.encodeComponent(fileName),
        'Content-Type': 'b2/x-auto',
        'X-Bz-Content-Sha1': sha1Hash,
        'Content-Length': file.size.toString(),
      });

      request.sink.add(bytes);
      request.sink.close();

      final response = await request.send();
      if (response.statusCode == 200) {
        final body = json.decode(await response.stream.bytesToString()) as Map<String, dynamic>;
        return (b2Creds['downloadUrlPrefix'] as String) + body['fileName'].toString().split('/').map(Uri.encodeComponent).join('/');
      }
      return null;
    } catch (e) { return null; }
  }

  Future<void> _pickAndUploadLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: kIsWeb);
      if (result == null || result.files.isEmpty) return;

      setState(() => _isUploadingLogo = true);
      final file = result.files.first;
      final b2Credentials = await _getB2UploadCredentials();

      if (b2Credentials != null) {
        final url = await _uploadFileToB2(file, b2Credentials);
        if (url != null) setState(() => _logoUrl = url);
      }
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
    }
  }

  // ----------------------------------------------------------------------
  // 📍 LOCATION, DATES & SUBMIT LOGIC
  // ----------------------------------------------------------------------
  Future<void> _pickLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LocationPickerPage(initialLat: _latitude, initialLng: _longitude)),
    );
    if (result != null && result is Map<String, double>) {
      setState(() { _latitude = result['latitude']; _longitude = result['longitude']; });
    }
  }

  Future<void> _pickContractDate(bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_contractStart ?? now) : (_contractEnd ?? now.add(const Duration(days: 365))),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        if (isStart) _contractStart = picked; else _contractEnd = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // Contract Validation
    if (_hasContract && (_contractStart == null || _contractEnd == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner les dates de début et fin du contrat.'), backgroundColor: kAppleRed));
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final storeData = {
        'name': _nameController.text.trim(),
        'location': _locationController.text.trim(),
        'latitude': _latitude,
        'longitude': _longitude,
        'logoUrl': _logoUrl,
        'contacts': _contacts.map((c) => {'label': c.label, 'type': c.type, 'value': c.value}).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // ✅ Inject Maintenance Contract Logic
      if (_hasContract) {
        storeData['maintenance_contract'] = {
          'startDate': Timestamp.fromDate(_contractStart!),
          'endDate': Timestamp.fromDate(_contractEnd!),
          'quotaPreventive': int.tryParse(_preventiveController.text) ?? 0,
          'quotaCorrective': int.tryParse(_correctiveController.text) ?? 0,
          'usedPreventive': _usedPreventive,
          'usedCorrective': _usedCorrective,
        };
      } else {
        storeData['maintenance_contract'] = null; // Clears it if turned off
      }

      final collection = FirebaseFirestore.instance.collection('clients').doc(widget.clientId).collection('stores');

      if (_isEditMode) {
        await collection.doc(widget.storeId).update(storeData);
      } else {
        storeData['createdAt'] = FieldValue.serverTimestamp();
        await collection.add(storeData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Magasin enregistré avec succès!'), backgroundColor: kAppleGreen));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: kAppleRed));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ----------------------------------------------------------------------
  // 🎨 UI BUILDERS (GLASSMORPHISM)
  // ----------------------------------------------------------------------
  Widget _buildGlassContainer({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Padding(padding: padding ?? const EdgeInsets.all(20), child: child),
        ),
      ),
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: GoogleFonts.inter(color: kTextDark, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(color: kTextSecondary),
          prefixIcon: Icon(icon, color: kTextSecondary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        validator: validator,
      ),
    );
  }

  void _showAddContactDialog() {
    // Add logic here to show a dialog and append to _contacts
  }

  @override
  Widget build(BuildContext context) {
    // ✅ RESPONSIVE CHECK: Determine if we are on a mobile-sized screen
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Colourful Mesh Gradient Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  stops: [0.0, 0.3, 0.7, 1.0],
                  colors: [
                    Color(0xFFFEE1E8), // Soft Pink
                    Color(0xFFE8F1F5), // White-ish Blue
                    Color(0xFF8EC5FC), // Sky Blue
                    Color(0xFFE0C3FC), // Soft Lilac
                  ],
                ),
              ),
            ),
          ),

          // 2. Extra Global Blur Layer
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(color: Colors.white.withOpacity(0.2)),
            ),
          ),

          // 3. Main Content
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // --- APP BAR ---
              SliverAppBar(
                expandedHeight: 120.0,
                floating: false,
                pinned: true,
                backgroundColor: Colors.transparent,
                iconTheme: const IconThemeData(color: kTextDark),
                flexibleSpace: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: FlexibleSpaceBar(
                      centerTitle: true,
                      title: Text(
                        _isEditMode ? "Modifier le Magasin" : "Nouveau Magasin",
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: kTextDark, fontSize: 18, letterSpacing: -0.5),
                      ),
                      background: Container(color: Colors.white.withOpacity(0.2)),
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 650),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            // --- LOGO UPLOAD ---
                            Center(
                              child: GestureDetector(
                                onTap: _isUploadingLogo ? null : _pickAndUploadLogo,
                                child: _buildGlassContainer(
                                  padding: const EdgeInsets.all(4),
                                  child: Container(
                                    width: 120, height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.5),
                                      image: _logoUrl != null ? DecorationImage(image: NetworkImage(_logoUrl!), fit: BoxFit.cover) : null,
                                    ),
                                    child: _isUploadingLogo
                                        ? const Center(child: CircularProgressIndicator(color: kAppleBlue))
                                        : _logoUrl == null
                                        ? const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_photo_alternate_rounded, color: kAppleBlue, size: 32),
                                        SizedBox(height: 8),
                                        Text("Logo", style: TextStyle(color: kAppleBlue, fontWeight: FontWeight.bold)),
                                      ],
                                    )
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // --- INFOS GÉNÉRALES ---
                            Text("INFORMATIONS GÉNÉRALES", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: kTextSecondary, letterSpacing: 1.2)),
                            const SizedBox(height: 12),
                            _buildGlassContainer(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  _buildGlassTextField(
                                    controller: _nameController,
                                    label: "Nom du Magasin/Site *",
                                    icon: Icons.storefront_rounded,
                                    validator: (v) => v!.isEmpty ? 'Requis' : null,
                                  ),
                                  _buildGlassTextField(
                                    controller: _locationController,
                                    label: "Adresse complète",
                                    icon: Icons.map_rounded,
                                    maxLines: 2,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),

                            // --- LOCALISATION GPS ---
                            Text("COORDONNÉES GPS", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: kTextSecondary, letterSpacing: 1.2)),
                            const SizedBox(height: 12),
                            _buildGlassContainer(
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(color: (_latitude != null) ? kAppleGreen.withOpacity(0.1) : kAppleRed.withOpacity(0.1), shape: BoxShape.circle),
                                        child: Icon(Icons.location_on_rounded, color: (_latitude != null) ? kAppleGreen : kAppleRed, size: 24),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text((_latitude != null) ? "Position Enregistrée" : "Position Manquante", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: kTextDark)),
                                            if (_latitude != null)
                                              Text("${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}", style: GoogleFonts.inter(color: kTextSecondary, fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_location_alt_rounded, color: kAppleBlue),
                                        onPressed: _pickLocation,
                                        style: IconButton.styleFrom(backgroundColor: kAppleBlue.withOpacity(0.1)),
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Divider(height: 1, color: Colors.black.withOpacity(0.05)),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildGlassTextField(
                                          controller: _gpsLinkController,
                                          label: "Coller un lien Google Maps ici",
                                          icon: Icons.link_rounded,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 16),
                                        height: 54, // Matches TextField height
                                        child: ElevatedButton(
                                          onPressed: _isResolvingLink ? null : _extractCoordinatesFromLink,
                                          style: ElevatedButton.styleFrom(backgroundColor: kAppleBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                          child: _isResolvingLink
                                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                              : const Icon(Icons.search_rounded, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),

                            // --- CONTRAT DE MAINTENANCE ---
                            Text("CONTRAT DE MAINTENANCE", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: kTextSecondary, letterSpacing: 1.2)),
                            const SizedBox(height: 12),
                            _buildGlassContainer(
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.shield_rounded, color: Colors.teal),
                                          const SizedBox(width: 12),
                                          Text("Activer le Contrat", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: kTextDark)),
                                        ],
                                      ),
                                      Switch.adaptive(
                                        value: _hasContract,
                                        activeColor: Colors.teal,
                                        onChanged: (v) => setState(() => _hasContract = v),
                                      ),
                                    ],
                                  ),

                                  // Expanded Contract Settings
                                  if (_hasContract) ...[
                                    const SizedBox(height: 16),
                                    Divider(height: 1, color: Colors.black.withOpacity(0.05)),
                                    const SizedBox(height: 16),

                                    // ✅ RESPONSIVE DATES
                                    if (isMobile)
                                      Column(
                                        children: [
                                          _buildDateCard(true),
                                          const SizedBox(height: 12),
                                          _buildDateCard(false),
                                        ],
                                      )
                                    else
                                      Row(
                                        children: [
                                          Expanded(child: _buildDateCard(true)),
                                          const SizedBox(width: 12),
                                          Expanded(child: _buildDateCard(false)),
                                        ],
                                      ),

                                    const SizedBox(height: 16),

                                    // ✅ RESPONSIVE QUOTAS
                                    if (isMobile)
                                      Column(
                                        children: [
                                          _buildGlassTextField(
                                            controller: _preventiveController,
                                            label: "Quota Préventif",
                                            icon: Icons.event_available_rounded,
                                            keyboardType: TextInputType.number,
                                          ),
                                          _buildGlassTextField(
                                            controller: _correctiveController,
                                            label: "Quota Curatif",
                                            icon: Icons.build_circle_rounded,
                                            keyboardType: TextInputType.number,
                                          ),
                                        ],
                                      )
                                    else
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildGlassTextField(
                                              controller: _preventiveController,
                                              label: "Quota Préventif",
                                              icon: Icons.event_available_rounded,
                                              keyboardType: TextInputType.number,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _buildGlassTextField(
                                              controller: _correctiveController,
                                              label: "Quota Curatif",
                                              icon: Icons.build_circle_rounded,
                                              keyboardType: TextInputType.number,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ]
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),

                            // --- CONTACTS ---
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("CONTACTS SUR SITE", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: kTextSecondary, letterSpacing: 1.2)),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_rounded, color: kAppleBlue),
                                  onPressed: _showAddContactDialog,
                                )
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_contacts.isEmpty)
                              _buildGlassContainer(
                                child: Center(child: Text("Aucun contact enregistré.", style: GoogleFonts.inter(color: kTextSecondary))),
                              ),
                            const SizedBox(height: 40),

                            // --- SUBMIT BUTTON ---
                            SizedBox(
                              width: double.infinity,
                              height: 60,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _submitForm,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kTextDark,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
                                ),
                                child: _isLoading
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : Text(_isEditMode ? "Enregistrer les modifications" : "Créer le Magasin", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
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
            ],
          ),
        ],
      ),
    );
  }

  // ✅ Extracted the Date Card to keep the code clean and reusable
  Widget _buildDateCard(bool isStart) {
    final DateTime? date = isStart ? _contractStart : _contractEnd;
    return InkWell(
      onTap: () => _pickContractDate(isStart),
      child: Container(
        width: double.infinity, // Ensures full width on mobile
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.6))
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isStart ? "Date de Début" : "Date de Fin", style: GoogleFonts.inter(fontSize: 11, color: kTextSecondary)),
            const SizedBox(height: 4),
            Text(date != null ? DateFormat('dd/MM/yyyy').format(date) : "Sélectionner", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: kTextDark)),
          ],
        ),
      ),
    );
  }
}