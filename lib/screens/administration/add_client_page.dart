// lib/screens/administration/add_client_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:boitex_info_app/utils/search_utils.dart';

// 🎨 --- 2026 PREMIUM APPLE COLORS & CONSTANTS --- 🎨
const Color kBgColor = Color(0xFFF2F2F7); // iOS System Background
const Color kSurfaceColor = Colors.white;
const Color kTextDark = Color(0xFF1D1D1F);
const Color kTextSecondary = Color(0xFF86868B);
const Color kAppleBlue = Color(0xFF007AFF);
const Color kAppleRed = Color(0xFFFF3B30);
const Color kAppleGreen = Color(0xFF34C759);
const double kRadius = 24.0;

// ✅ ContactInfo Model
class ContactInfo {
  String type; // 'Téléphone' ou 'E-mail'
  String label; // Ex: 'Facturation', 'Technique', 'Principal'
  String value; // Le numéro ou l'adresse e-mail

  final String id;

  ContactInfo({
    required this.type,
    required this.label,
    required this.value,
    String? id,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  IconData get icon {
    switch (type) {
      case 'E-mail':
        return Icons.email_rounded;
      case 'Fax':
        return Icons.fax_rounded;
      default:
        return Icons.phone_rounded;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'label': label,
      'value': value,
    };
  }

  factory ContactInfo.fromMap(Map<String, dynamic> map, String id) {
    return ContactInfo(
      type: map['type'] ?? 'Téléphone',
      label: map['label'] ?? '',
      value: map['value'] ?? '',
      id: id,
    );
  }
}

class AddClientPage extends StatefulWidget {
  final String? clientId;
  final Map<String, dynamic>? initialData;
  final String? preselectedServiceType;

  const AddClientPage({
    super.key,
    this.clientId,
    this.initialData,
    this.preselectedServiceType,
  });

  @override
  State<AddClientPage> createState() => _AddClientPageState();
}

class _AddClientPageState extends State<AddClientPage> {
  final _formKey = GlobalKey<FormState>();

  // Basic Info Controllers
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _mapsLinkController = TextEditingController(); // ✅ NEW MAPS LINK
  final _brandsController = TextEditingController();

  // Controllers for Business Identifiers
  final _rcController = TextEditingController();
  final _artController = TextEditingController();
  final _fiscController = TextEditingController();

  final Map<String, bool> _services = {
    'Service Technique': false,
    'Service IT': false,
  };

  List<ContactInfo> _contacts = [];

  bool _isLoading = false;
  bool get _isEditMode => widget.clientId != null;

  @override
  void initState() {
    super.initState();

    if (widget.preselectedServiceType != null) {
      if (_services.containsKey(widget.preselectedServiceType)) {
        _services[widget.preselectedServiceType!] = true;
      }
    }

    if (widget.initialData != null) {
      _populateData(widget.initialData!);
    } else if (_isEditMode) {
      _loadClientData();
    } else {
      _addContact();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _mapsLinkController.dispose();
    _brandsController.dispose();
    _rcController.dispose();
    _artController.dispose();
    _fiscController.dispose();
    super.dispose();
  }

  void _populateData(Map<String, dynamic> data) {
    _nameController.text = data['name'] ?? '';
    _addressController.text = data['location'] ?? data['address'] ?? '';
    _mapsLinkController.text = data['mapsLink'] ?? ''; // ✅ Load maps link
    _rcController.text = data['rc'] ?? '';
    _artController.text = data['art'] ?? '';
    _fiscController.text = data['nif'] ?? '';

    if (data['brands'] != null) {
      final List<dynamic> brands = data['brands'];
      _brandsController.text = brands.join(', ');
    }

    if (data['services'] != null) {
      final servicesList = List<String>.from(data['services']);
      setState(() {
        _services['Service Technique'] = servicesList.contains('Service Technique');
        _services['Service IT'] = servicesList.contains('Service IT');
      });
    }

    if (data['contacts'] != null) {
      final List<dynamic> contactsData = data['contacts'];
      setState(() {
        _contacts = contactsData.map((c) => ContactInfo.fromMap(c as Map<String, dynamic>, DateTime.now().millisecondsSinceEpoch.toString())).toList();
      });
    } else if (_contacts.isEmpty) {
      _addContact();
    }
  }

  Future<void> _loadClientData() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('clients').doc(widget.clientId).get();
      if (doc.exists) {
        _populateData(doc.data()!);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e', style: GoogleFonts.inter())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addContact() {
    setState(() {
      _contacts.add(ContactInfo(type: 'Téléphone', label: '', value: ''));
    });
  }

  void _removeContact(int index) {
    setState(() {
      _contacts.removeAt(index);
    });
  }

  String _generateSlug(String input) {
    String slug = input.trim().toLowerCase();
    const withDia = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÖØòóôõöøÈÉÊËèéêëÇçÌÍÎÏìíîïÙÚÛÜùúûüÿÑñ';
    const withoutDia = 'AAAAAAaaaaaaOOOOOOooooooEEEEeeeeCcIIIIiiiiUUUUuuuuuyNn';

    for (int i = 0; i < withDia.length; i++) {
      slug = slug.replaceAll(withDia[i], withoutDia[i]);
    }
    slug = slug.replaceAll(RegExp(r'[^a-z0-9]'), '_');
    slug = slug.replaceAll(RegExp(r'_+'), '_');
    if (slug.startsWith('_')) slug = slug.substring(1);
    if (slug.endsWith('_')) slug = slug.substring(0, slug.length - 1);

    return slug;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final selectedServices = _services.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();

      List<String> brandsList = _brandsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      List<String> termsToIndex = [
        _nameController.text.trim(),
        ...brandsList,
      ];

      final searchKeywords = generateSearchKeywords(termsToIndex);
      final slug = _generateSlug(_nameController.text);

      final clientData = {
        'name': _nameController.text.trim(),
        'location': _addressController.text.trim(),
        'mapsLink': _mapsLinkController.text.trim(), // ✅ Save Maps Link
        'services': selectedServices,
        'brands': brandsList,
        'search_keywords': searchKeywords,
        'rc': _rcController.text.trim(),
        'art': _artController.text.trim(),
        'nif': _fiscController.text.trim(),
        'contacts': _contacts.map((c) => c.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
        'slug': slug,
      };

      if (_isEditMode) {
        await FirebaseFirestore.instance.collection('clients').doc(widget.clientId).update(clientData);
      } else {
        if (slug.isEmpty) throw "Le nom de l'entreprise est invalide.";

        final docRef = FirebaseFirestore.instance.collection('clients').doc(slug);
        final docSnapshot = await docRef.get();

        if (docSnapshot.exists) {
          throw "Ce client existe déjà ! (ID: $slug).\nVeuillez vérifier la liste.";
        }

        final legacyCheck = await FirebaseFirestore.instance.collection('clients').where('slug', isEqualTo: slug).limit(1).get();

        if (legacyCheck.docs.isNotEmpty) {
          final oldId = legacyCheck.docs.first.id;
          throw "Ce client existe déjà dans l'ancien système !\n(ID: $oldId)";
        }

        clientData['createdAt'] = FieldValue.serverTimestamp();
        await docRef.set(clientData);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e', style: GoogleFonts.inter()),
            backgroundColor: kAppleRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // 🎨 APPLE / IOS UI BUILDERS
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: kBgColor,
        iconTheme: const IconThemeData(color: kTextDark),
        centerTitle: true,
        title: Text(
          _isEditMode ? 'Modifier Client' : 'Nouveau Client',
          style: GoogleFonts.inter(color: kTextDark, fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kAppleBlue))
          : Form(
        key: _formKey,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            _buildSectionHeader("Identité"),
            _buildSettingsGroup(
              children: [
                _buildPremiumTextField(
                  controller: _nameController,
                  label: "Nom de l'entreprise",
                  icon: Icons.business_rounded,
                  isFirst: true,
                  validator: (value) => value!.isEmpty ? 'Requis' : null,
                ),
                _buildPremiumTextField(
                  controller: _brandsController,
                  label: "Marques (Zara, Bershka...)",
                  icon: Icons.sell_rounded,
                  isLast: true,
                ),
              ],
            ),

            const SizedBox(height: 24),
            _buildSectionHeader("Siège Social & Localisation"),
            _buildSettingsGroup(
              children: [
                _buildPremiumTextField(
                  controller: _addressController,
                  label: "Adresse Textuelle",
                  icon: Icons.map_rounded,
                  isFirst: true,
                ),
                _buildPremiumTextField(
                  controller: _mapsLinkController,
                  label: "Lien Google Maps (URL)",
                  icon: Icons.location_on_rounded,
                  isLast: true,
                  keyboardType: TextInputType.url,
                ),
              ],
            ),

            const SizedBox(height: 24),
            _buildSectionHeader("Informations Légales"),
            _buildSettingsGroup(
              children: [
                _buildPremiumTextField(
                  controller: _rcController,
                  label: "N° RC",
                  icon: Icons.confirmation_number_rounded,
                  isFirst: true,
                ),
                _buildPremiumTextField(
                  controller: _artController,
                  label: "N° ART",
                  icon: Icons.numbers_rounded,
                ),
                _buildPremiumTextField(
                  controller: _fiscController,
                  label: "N° FISC (NIF)",
                  icon: Icons.account_balance_rounded,
                  isLast: true,
                  keyboardType: TextInputType.number,
                ),
              ],
            ),

            const SizedBox(height: 24),
            _buildSectionHeader("Services Concernés"),
            _buildSettingsGroup(
              children: [
                _buildToggleRow(
                  title: "Service Technique",
                  icon: Icons.engineering_rounded,
                  iconColor: const Color(0xFF4F46E5), // Indigo
                  value: _services['Service Technique']!,
                  onChanged: (val) => setState(() => _services['Service Technique'] = val),
                  isFirst: true,
                ),
                _buildToggleRow(
                  title: "Service IT",
                  icon: Icons.router_rounded,
                  iconColor: const Color(0xFF0EA5E9), // Sky Blue
                  value: _services['Service IT']!,
                  onChanged: (val) => setState(() => _services['Service IT'] = val),
                  isLast: true,
                ),
              ],
            ),

            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8, top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("CONTACTS", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: kTextSecondary, letterSpacing: 1.2)),
                  GestureDetector(
                    onTap: _addContact,
                    child: Text("Ajouter", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: kAppleBlue)),
                  )
                ],
              ),
            ),

            if (_contacts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text("Aucun contact ajouté.", style: GoogleFonts.inter(color: kTextSecondary, fontStyle: FontStyle.italic)),
              ),

            ..._contacts.asMap().entries.map((entry) {
              int index = entry.key;
              ContactInfo contact = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: kSurfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildContactDropdown(contact),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              initialValue: contact.label,
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                hintText: 'Poste (ex: DG)',
                                hintStyle: GoogleFonts.inter(color: kTextSecondary),
                                border: InputBorder.none,
                              ),
                              onChanged: (val) => contact.label = val,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: kAppleRed),
                            onPressed: () => _removeContact(index),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      Divider(height: 1, color: Colors.black.withOpacity(0.05)),
                      TextFormField(
                        initialValue: contact.value,
                        style: GoogleFonts.inter(),
                        decoration: InputDecoration(
                          hintText: contact.type == 'E-mail' ? 'Adresse E-mail' : 'Numéro de téléphone',
                          hintStyle: GoogleFonts.inter(color: kTextSecondary),
                          prefixIcon: Icon(contact.icon, color: kTextSecondary, size: 20),
                          border: InputBorder.none,
                        ),
                        keyboardType: contact.type == 'E-mail' ? TextInputType.emailAddress : TextInputType.phone,
                        onChanged: (val) => contact.value = val,
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kTextDark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: Text(_isEditMode ? 'Enregistrer les modifications' : 'Ajouter le client', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8, top: 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: kTextSecondary, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildSettingsGroup({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(kRadius),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildPremiumTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isFirst = false,
    bool isLast = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      children: [
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(color: kTextDark, fontWeight: FontWeight.w500),
          validator: validator,
          decoration: InputDecoration(
            hintText: label,
            hintStyle: GoogleFonts.inter(color: kTextSecondary),
            prefixIcon: Icon(icon, color: kTextSecondary, size: 22),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
        if (!isLast) Divider(height: 1, color: Colors.black.withOpacity(0.05), indent: 50),
      ],
    );
  }

  Widget _buildToggleRow({
    required String title,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required Function(bool) onChanged,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: kTextDark))),
              Switch.adaptive(
                value: value,
                activeColor: iconColor,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: Colors.black.withOpacity(0.05), indent: 60),
      ],
    );
  }

  Widget _buildContactDropdown(ContactInfo contact) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: kBgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: contact.type,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kTextSecondary, size: 16),
          items: ['Téléphone', 'E-mail', 'Fax', 'Autre']
              .map((t) => DropdownMenuItem(value: t, child: Text(t, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500))))
              .toList(),
          onChanged: (val) => setState(() => contact.type = val!),
        ),
      ),
    );
  }
}