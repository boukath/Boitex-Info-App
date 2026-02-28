// lib/screens/administration/store_equipment_page.dart

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:boitex_info_app/screens/administration/add_store_equipment_page.dart';
import 'package:boitex_info_app/screens/administration/store_equipment_details_page.dart';
import 'package:boitex_info_app/screens/administration/add_store_page.dart';
import 'package:boitex_info_app/models/service_contracts.dart';

// ✅ Imports for the detailed history pages & models
import 'package:boitex_info_app/screens/administration/livraison_details_page.dart';
import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';
import 'package:boitex_info_app/screens/service_technique/installation_details_page.dart';
import 'package:boitex_info_app/screens/service_technique/sav_ticket_details_page.dart';
import 'package:boitex_info_app/models/sav_ticket.dart';
import 'package:boitex_info_app/utils/user_roles.dart';

// ✅ Import Image Gallery for Full Screen Images
import 'package:boitex_info_app/widgets/image_gallery_page.dart';

class StoreEquipmentPage extends StatefulWidget {
  final String clientId;
  final String storeId;
  final String storeName;
  final String? logoUrl;

  const StoreEquipmentPage({
    super.key,
    required this.clientId,
    required this.storeId,
    required this.storeName,
    this.logoUrl,
  });

  @override
  State<StoreEquipmentPage> createState() => _StoreEquipmentPageState();
}

class _StoreEquipmentPageState extends State<StoreEquipmentPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'Tous';

  late Future<List<Map<String, String>>> _contactsFuture;

  // B2 UPLOAD STATE VARIABLES
  bool _isUploading = false;
  String? _localLogoUrl;
  String? _localCoverUrl;
  StreamSubscription<DocumentSnapshot>? _storeSubscription;
  final String _getB2UploadUrlCloudFunctionUrl = 'https://europe-west1-boitexinfo-63060.cloudfunctions.net/getB2UploadUrl';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

    _contactsFuture = _fetchStoreContacts();

    _localLogoUrl = widget.logoUrl;
    _storeSubscription = FirebaseFirestore.instance
        .collection('clients')
        .doc(widget.clientId)
        .collection('stores')
        .doc(widget.storeId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          _localLogoUrl = data['logoUrl'] ?? widget.logoUrl;
          _localCoverUrl = data['coverUrl'];
        });
      }
    });

    _syncFromDeliveries();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _storeSubscription?.cancel();
    super.dispose();
  }

  // ==============================================================================
  // 📸 BACKBLAZE B2 IMAGE UPLOAD LOGIC
  // ==============================================================================
  Future<void> _pickAndUploadImage({required bool isCover}) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final Uint8List bytes = await image.readAsBytes();
      final authResponse = await http.get(Uri.parse(_getB2UploadUrlCloudFunctionUrl));
      if (authResponse.statusCode != 200) throw "Auth B2 Failed";
      final creds = json.decode(authResponse.body);

      final folder = isCover ? 'store_covers' : 'store_logos';
      final fileName = '$folder/${widget.clientId}/${widget.storeId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final sha1Hash = sha1.convert(bytes).toString();

      final uploadResponse = await http.post(
        Uri.parse(creds['uploadUrl']),
        headers: {
          'Authorization': creds['authorizationToken'],
          'X-Bz-File-Name': Uri.encodeComponent(fileName),
          'Content-Type': 'image/jpeg',
          'X-Bz-Content-Sha1': sha1Hash,
          'Content-Length': bytes.length.toString(),
        },
        body: bytes,
      );

      if (uploadResponse.statusCode == 200) {
        final body = json.decode(uploadResponse.body);
        final downloadUrl = creds['downloadUrlPrefix'] + Uri.encodeComponent(body['fileName']);

        await FirebaseFirestore.instance
            .collection('clients')
            .doc(widget.clientId)
            .collection('stores')
            .doc(widget.storeId)
            .update({
          isCover ? 'coverUrl' : 'logoUrl': downloadUrl,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("${isCover ? 'Couverture' : 'Logo'} mis à jour !"), backgroundColor: Colors.green),
          );
        }
      } else {
        throw "B2 Error: ${uploadResponse.body}";
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur d'envoi"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ==============================================================================
  // 🔄 AUTO-IMPORT LOGIC (The Lazy Sync)
  // ==============================================================================
  Future<void> _syncFromDeliveries() async {
    try {
      final deliveriesSnapshot = await FirebaseFirestore.instance
          .collection('livraisons')
          .where('clientId', isEqualTo: widget.clientId)
          .where('storeId', isEqualTo: widget.storeId)
          .where('status', whereIn: ['Livré', 'Livraison Partielle'])
          .get();

      if (deliveriesSnapshot.docs.isEmpty) return;

      final equipmentRef = FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .collection('stores')
          .doc(widget.storeId)
          .collection('materiel_installe');

      final equipmentSnapshot = await equipmentRef.get();
      final Set<String> existingSerials = equipmentSnapshot.docs
          .map((doc) => doc.data()['serialNumber']?.toString().trim().toUpperCase())
          .where((s) => s != null)
          .cast<String>()
          .toSet();

      final batch = FirebaseFirestore.instance.batch();
      int addedCount = 0;

      for (var doc in deliveriesSnapshot.docs) {
        final data = doc.data();
        final List products = data['products'] ?? [];
        final String deliveryId = doc.id;

        Timestamp? deliveryDate = data['completedAt'] ?? data['createdAt'];

        for (var item in products) {
          List<dynamic> serialsToAdd = [];

          if (item['deliveredSerials'] != null && (item['deliveredSerials'] as List).isNotEmpty) {
            serialsToAdd = item['deliveredSerials'];
          } else if (item['serialNumbers'] != null && (item['serialNumbers'] as List).isNotEmpty) {
            int deliveredQty = item['deliveredQuantity'] ?? item['quantity'] ?? 0;
            if (deliveredQty > 0) {
              serialsToAdd = (item['serialNumbers'] as List).take(deliveredQty).toList();
            }
          }

          for (var serial in serialsToAdd) {
            final String serialStr = serial.toString().trim();
            final String serialCheck = serialStr.toUpperCase();

            if (!existingSerials.contains(serialCheck) && serialStr.isNotEmpty && serialStr != 'N/A') {
              final newDoc = equipmentRef.doc();
              batch.set(newDoc, {
                'name': item['productName'] ?? 'Équipement',
                'category': item['category'] ?? 'N/A',
                'marque': item['marque'] ?? 'N/A',
                'reference': item['partNumber'] ?? item['reference'] ?? 'N/A',
                'serialNumber': serialStr,
                'installDate': deliveryDate ?? FieldValue.serverTimestamp(),
                'status': 'Installé',
                'source': 'Livraison',
                'firstSeenInstallationId': deliveryId,
                'warrantyEnd': null,
                'addedBy': 'Auto-Sync',
                'createdAt': FieldValue.serverTimestamp(),
              });

              existingSerials.add(serialCheck);
              addedCount++;
            }
          }
        }
      }

      if (addedCount > 0) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint("Error syncing deliveries: $e");
    }
  }

  Future<String> _resolveProductName(Map<String, dynamic> data) async {
    String currentName = data['nom'] ?? data['name'] ?? 'Produit Inconnu';
    String? productId = data['productId'] ?? data['id'];

    const List<String> genericNames = ['Produit Inconnu', 'Equipment Inconnu', 'N/A', 'Matériel'];

    if (genericNames.contains(currentName) && productId != null && productId.isNotEmpty) {
      try {
        final productDoc = await FirebaseFirestore.instance.collection('produits').doc(productId).get();
        if (productDoc.exists) return productDoc.data()?['nom'] ?? currentName;
      } catch (_) {}
    }
    return currentName;
  }

  Future<void> _deleteEquipment(String equipmentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous vraiment supprimer cet équipement ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('clients')
            .doc(widget.clientId)
            .collection('stores')
            .doc(widget.storeId)
            .collection('materiel_installe')
            .doc(equipmentId)
            .delete();
      } catch (_) {}
    }
  }

  EquipmentWarranty? _getWarranty(Map<String, dynamic> data) {
    EquipmentWarranty? warranty;
    if (data['warranty'] != null) {
      try {
        warranty = EquipmentWarranty.fromMap(data['warranty']);
      } catch (_) {}
    }
    final Timestamp? ts = data['installDate'] ?? data['installationDate'];
    if (warranty == null && ts != null) {
      warranty = EquipmentWarranty.defaultOneYear(ts.toDate());
    }
    return warranty;
  }

  Future<List<Map<String, String>>> _fetchStoreContacts() async {
    List<Map<String, String>> contacts = [];
    Set<String> uniqueKeys = {};

    void addContact(String? name, String? phone, String? email) {
      final n = (name?.trim() ?? '').isEmpty ? 'Inconnu' : name!.trim();
      final p = (phone?.trim() ?? '').isEmpty ? 'Non renseigné' : phone!.trim();
      final e = (email?.trim() ?? '').isEmpty ? 'Non renseigné' : email!.trim();

      if (n == 'Inconnu' && p == 'Non renseigné' && e == 'Non renseigné') return;
      final key = '${n.toLowerCase()}_${p.toLowerCase()}';
      if (!uniqueKeys.contains(key)) {
        uniqueKeys.add(key);
        contacts.add({'name': n, 'phone': p, 'email': e});
      }
    }

    try {
      final interventions = await FirebaseFirestore.instance.collection('interventions').where('storeId', isEqualTo: widget.storeId).get();
      for (var doc in interventions.docs) {
        addContact(doc.data()['managerName'], doc.data()['managerPhone'], doc.data()['managerEmail']);
      }

      final installations = await FirebaseFirestore.instance.collection('installations').where('storeId', isEqualTo: widget.storeId).get();
      for (var doc in installations.docs) {
        addContact(doc.data()['managerName'] ?? doc.data()['contactName'], doc.data()['managerPhone'] ?? doc.data()['contactPhone'], doc.data()['managerEmail'] ?? doc.data()['contactEmail']);
      }
    } catch (_) {}

    return contacts;
  }

  // ==============================================================================
  // 🕒 HISTORY LOGIC (FULL AUDIT TRAIL)
  // ==============================================================================
  Future<List<Map<String, dynamic>>> _fetchStoreHistory() async {
    List<Map<String, dynamic>> history = [];

    try {
      // 1. Fetch Interventions (Only 'Terminé' or 'Clôturé')
      final interventions = await FirebaseFirestore.instance
          .collection('interventions')
          .where('storeId', isEqualTo: widget.storeId)
          .where('status', whereIn: ['Terminé', 'Clôturé', 'Facturé'])
          .get();

      for (var doc in interventions.docs) {
        final data = doc.data();
        List<String> techs = List<String>.from(data['assignedTechnicians'] ?? []);
        List<String> media = List<String>.from(data['mediaUrls'] ?? []);

        history.add({
          'id': doc.id,
          'doc': doc,
          'type': 'Intervention',
          'code': data['interventionCode'] ?? 'N/A',
          'date': data['scheduledAt'] ?? data['createdAt'],
          'status': data['status'],
          'technicians': techs,
          'primaryDescTitle': 'Diagnostic',
          'primaryDesc': data['diagnostic'] ?? 'Aucun diagnostic',
          'secondaryDescTitle': 'Travail Effectué',
          'secondaryDesc': data['workDone'] ?? 'Aucun détail',
          'mediaUrls': media,
          'signatureUrl': data['signatureUrl'],
          'icon': Icons.build_circle_outlined,
          'color': Colors.blueAccent,
        });
      }

      // 2. Fetch Installations
      final installations = await FirebaseFirestore.instance
          .collection('installations')
          .where('storeId', isEqualTo: widget.storeId)
          .get();

      for (var doc in installations.docs) {
        final data = doc.data();
        List<String> techs = List<String>.from(data['assignedTechnicianNames'] ?? []);
        List<String> media = List<String>.from(data['mediaUrls'] ?? []);
        final products = data['orderedProducts'] as List? ?? [];

        history.add({
          'id': doc.id,
          'doc': doc,
          'type': 'Installation',
          'code': data['installationCode'] ?? 'N/A',
          'date': data['completedAt'] ?? data['installationDate'] ?? data['createdAt'],
          'status': data['status'] ?? 'Inconnu',
          'technicians': techs,
          'primaryDescTitle': 'Demande Initiale',
          'primaryDesc': data['initialRequest'] ?? 'Aucune demande',
          'secondaryDescTitle': 'Notes',
          'secondaryDesc': data['notes'] ?? 'Aucune note',
          'extraInfo': '${products.length} produit(s) installé(s)',
          'mediaUrls': media,
          'signatureUrl': data['signatureUrl'],
          'icon': Icons.handyman_outlined,
          'color': Colors.teal,
        });
      }

      // 3. Fetch Livraisons
      final livraisons = await FirebaseFirestore.instance
          .collection('livraisons')
          .where('storeId', isEqualTo: widget.storeId)
          .get();

      for (var doc in livraisons.docs) {
        final data = doc.data();
        List<String> techs = [];
        if (data['technicians'] != null) {
          for (var t in data['technicians']) {
            if (t['name'] != null) techs.add(t['name']);
          }
        } else if (data['technicianName'] != null) {
          techs.add(data['technicianName']);
        }

        final products = data['products'] as List? ?? [];

        history.add({
          'id': doc.id,
          'type': 'Livraison',
          'code': data['bonLivraisonCode'] ?? 'N/A',
          'date': data['completedAt'] ?? data['createdAt'],
          'status': data['status'] ?? 'Inconnu',
          'technicians': techs,
          'primaryDescTitle': 'Détails',
          'primaryDesc': 'Livraison de ${products.length} référence(s).',
          'signatureUrl': data['signatureUrl'],
          'icon': Icons.local_shipping_outlined,
          'color': Colors.green,
        });
      }

      // 4. Fetch SAV
      final savs = await FirebaseFirestore.instance
          .collection('sav_tickets')
          .where('storeId', isEqualTo: widget.storeId)
          .get();

      for (var doc in savs.docs) {
        final data = doc.data();
        List<String> techs = List<String>.from(data['pickupTechnicianNames'] ?? []);
        List<String> media = List<String>.from(data['itemPhotoUrls'] ?? []);
        if (data['returnPhotoUrl'] != null && data['returnPhotoUrl'].toString().isNotEmpty) {
          media.add(data['returnPhotoUrl']);
        }

        final ticket = SavTicket.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);

        history.add({
          'id': doc.id,
          'ticket': ticket,
          'type': 'SAV',
          'code': data['savCode'] ?? 'N/A',
          'date': data['pickupDate'] ?? data['createdAt'],
          'status': data['status'] ?? 'Inconnu',
          'technicians': techs,
          'primaryDescTitle': 'Problème Signalé',
          'primaryDesc': data['problemDescription'] ?? 'Non spécifié',
          'secondaryDescTitle': 'Rapport Technicien',
          'secondaryDesc': data['technicianReport'] ?? 'Aucun rapport',
          'extraInfo': 'Produit: ${data['productName'] ?? 'Inconnu'}',
          'mediaUrls': media,
          'signatureUrl': data['returnSignatureUrl'] ?? data['storeManagerSignatureUrl'],
          'icon': Icons.support_agent_outlined,
          'color': Colors.orange,
        });
      }

      history.sort((a, b) {
        final Timestamp? tA = a['date'] as Timestamp?;
        final Timestamp? tB = b['date'] as Timestamp?;
        if (tA == null) return 1;
        if (tB == null) return -1;
        return tB.compareTo(tA);
      });

    } catch (e) {
      debugPrint("Error fetching full history: $e");
    }

    return history;
  }

  // ==============================================================================
  // 🎨 UI BUILDERS - COMPONENTS
  // ==============================================================================

  Widget _buildActionCircle(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(color: const Color(0xFF667EEA).withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: const Color(0xFF667EEA)),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF475569))),
        ],
      ),
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const SizedBox(height: 4),
            Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.1)),
          ],
        ),
      ),
    );
  }

  // ✅ SMART LAYOUT - NO TRANSFORM.TRANSLATE OVERFLOWS
  Widget _buildHeroHeader() {
    return SliverToBoxAdapter(
      child: Container(
        color: const Color(0xFFF8FAFC),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // 📸 CLICKABLE LOGO IMAGE
                      GestureDetector(
                        onTap: () {
                          if (_localLogoUrl != null) {
                            Navigator.push(context, MaterialPageRoute(
                                builder: (_) => ImageGalleryPage(imageUrls: [_localLogoUrl!], initialIndex: 0)
                            ));
                          }
                        },
                        child: Container(
                          height: 85,
                          width: 85,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
                            image: _localLogoUrl != null ? DecorationImage(image: NetworkImage(_localLogoUrl!), fit: BoxFit.cover) : null,
                          ),
                          child: _localLogoUrl == null ? const Icon(Icons.storefront, size: 40, color: Colors.grey) : null,
                        ),
                      ),
                      // Edit Logo Button
                      Positioned(
                        bottom: 0,
                        right: -4,
                        child: GestureDetector(
                          onTap: () => _pickAndUploadImage(isCover: false),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.storeName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)), maxLines: 2, overflow: TextOverflow.ellipsis),
                          Row(
                            children: [
                              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              const Text("Actif", style: TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Quick Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionCircle(Icons.phone_outlined, "Appeler", () {}),
                _buildActionCircle(Icons.map_outlined, "Itinéraire", () {}),
                _buildActionCircle(Icons.edit_outlined, "Éditer", () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddStorePage(clientId: widget.clientId, storeId: widget.storeId)))),
                _buildActionCircle(Icons.add_box_outlined, "Ajouter", () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddStoreEquipmentPage(clientId: widget.clientId, storeId: widget.storeId)))),
              ],
            ),

            const SizedBox(height: 24),

            // Live KPI Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('clients').doc(widget.clientId).collection('stores').doc(widget.storeId).collection('materiel_installe').snapshots(),
                builder: (context, snapshot) {
                  int total = 0;
                  int validWarranty = 0;
                  if (snapshot.hasData) {
                    total = snapshot.data!.docs.length;
                    for (var doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final warranty = _getWarranty(data);
                      if (warranty != null && warranty.isValid) validWarranty++;
                    }
                  }
                  String warrantyRate = total == 0 ? "0%" : "${((validWarranty / total) * 100).toStringAsFixed(0)}%";
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildKPICard("Total Équipements", total.toString(), Icons.inventory_2_outlined, const Color(0xFF667EEA)),
                      const SizedBox(width: 12),
                      _buildKPICard("Taux de Garantie", warrantyRate, Icons.verified_user_outlined, Colors.green),
                      const SizedBox(width: 12),
                      _buildKPICard("Dernière Visite", "Récemment", Icons.history, Colors.orange),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('clients').doc(widget.clientId).collection('stores').doc(widget.storeId).snapshots(),
          builder: (context, snapshot) {
            final data = (snapshot.hasData && snapshot.data!.exists) ? snapshot.data!.data() as Map<String, dynamic> : {};
            final String address = data['adresse'] ?? data['address'] ?? 'Adresse non renseignée';
            final double? lat = data['latitude'] ?? data['storeLatitude'];
            final double? lng = data['longitude'] ?? data['storeLongitude'];

            Future<void> openGoogleMaps() async {
              Uri mapUrl;
              if (lat != null && lng != null) {
                mapUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
              } else {
                final String searchQuery = Uri.encodeComponent('${widget.storeName} $address');
                mapUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$searchQuery');
              }
              if (await canLaunchUrl(mapUrl)) {
                await launchUrl(mapUrl, mode: LaunchMode.externalApplication);
              } else {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Impossible d'ouvrir Google Maps.")));
              }
            }

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Localisation", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on_outlined, color: Colors.redAccent, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(address, style: const TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.4))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: openGoogleMaps,
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                        color: Color(0xFFE2E8F0),
                        image: DecorationImage(
                          image: AssetImage('assets/images/map_placeholder.png'),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(Colors.black12, BlendMode.darken),
                        ),
                      ),
                      child: Center(
                        child: ElevatedButton.icon(
                          onPressed: openGoogleMaps,
                          icon: const Icon(Icons.map, size: 16),
                          label: const Text("Ouvrir dans Maps", style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.95),
                            foregroundColor: const Color(0xFF1E293B),
                            elevation: 8,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text("Répertoire (Contacts Historiques)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        ),
        FutureBuilder<List<Map<String, String>>>(
          future: _contactsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(32.0), child: Center(child: CircularProgressIndicator()));
            if (!snapshot.hasData || snapshot.data!.isEmpty) return _buildEmptyState("Aucun contact trouvé", Icons.group_off_outlined);
            final contacts = snapshot.data!;
            return Column(
              children: contacts.map((contact) {
                final String name = contact['name']!;
                final String phone = contact['phone']!;
                final String email = contact['email']!;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFF667EEA).withOpacity(0.15),
                            child: Text(name != 'Inconnu' && name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Color(0xFF667EEA), fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
                        ],
                      ),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
                      GestureDetector(
                        onTap: phone != 'Non renseigné' ? () => launchUrl(Uri.parse('tel:$phone')) : null,
                        child: _buildContactRow(Icons.phone_outlined, phone, "Téléphone", isLink: phone != 'Non renseigné'),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: email != 'Non renseigné' ? () => launchUrl(Uri.parse('mailto:$email')) : null,
                        child: _buildContactRow(Icons.email_outlined, email, "Email", isLink: email != 'Non renseigné'),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildContactRow(IconData icon, String value, String label, {bool isLink = false}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 20, color: isLink ? const Color(0xFF667EEA) : const Color(0xFF64748B)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isLink ? const Color(0xFF667EEA) : const Color(0xFF1E293B))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEquipmentTab() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Rechercher un S/N ou modèle...",
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['Tous', 'Sous Garantie', 'Expirée'].map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(filter, style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade700, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          selected: isSelected,
                          selectedColor: const Color(0xFF667EEA),
                          backgroundColor: Colors.white,
                          side: BorderSide(color: isSelected ? const Color(0xFF667EEA) : Colors.grey.shade300),
                          onSelected: (val) => setState(() => _selectedFilter = filter),
                        ),
                      );
                    }).toList(),
                  ),
                )
              ],
            ),
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('clients').doc(widget.clientId).collection('stores').doc(widget.storeId).collection('materiel_installe').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return SliverFillRemaining(child: _buildEmptyState("Aucun équipement installé", Icons.inventory_2_outlined));

            var docs = snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final serial = (data['serialNumber'] ?? '').toString().toLowerCase();
              final name = (data['name'] ?? data['nom'] ?? '').toString().toLowerCase();

              if (_searchQuery.isNotEmpty && !serial.contains(_searchQuery) && !name.contains(_searchQuery)) return false;
              if (_selectedFilter != 'Tous') {
                final warranty = _getWarranty(data);
                if (_selectedFilter == 'Sous Garantie' && (warranty == null || !warranty.isValid)) return false;
                if (_selectedFilter == 'Expirée' && (warranty != null && warranty.isValid)) return false;
              }
              return true;
            }).toList();

            docs.sort((a, b) {
              final Timestamp? tA = (a.data() as Map)['installDate'] ?? (a.data() as Map)['createdAt'];
              final Timestamp? tB = (b.data() as Map)['installDate'] ?? (b.data() as Map)['createdAt'];
              if (tA == null) return 1;
              if (tB == null) return -1;
              return tB.compareTo(tA);
            });

            if (docs.isEmpty) return SliverFillRemaining(child: _buildEmptyState("Aucun résultat pour cette recherche.", Icons.search_off));

            return SliverPadding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final id = docs[index].id;
                    final String serial = data['serialNumber'] ?? data['serial'] ?? 'S/N Inconnu';
                    final Timestamp? installDate = (data['installDate'] ?? data['installationDate']) as Timestamp?;
                    final String? imageUrl = data['image'];
                    final warranty = _getWarranty(data);

                    return Slidable(
                      key: ValueKey(id),
                      endActionPane: ActionPane(
                        motion: const ScrollMotion(),
                        children: [
                          SlidableAction(
                            onPressed: (_) => _deleteEquipment(id),
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            icon: Icons.delete,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ],
                      ),
                      child: GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreEquipmentDetailsPage(clientId: widget.clientId, storeId: widget.storeId, equipmentId: id))),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade100),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 65,
                                height: 65,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                  image: imageUrl != null ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover) : null,
                                ),
                                child: imageUrl == null ? const Icon(Icons.router_outlined, color: Colors.blueGrey, size: 28) : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FutureBuilder<String>(
                                        future: _resolveProductName(data),
                                        initialData: data['nom'] ?? data['name'] ?? 'Chargement...',
                                        builder: (context, nameSnapshot) {
                                          return Text(
                                            nameSnapshot.data ?? 'Équipement',
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF1E293B)),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          );
                                        }),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.qr_code, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(serial, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(installDate != null ? DateFormat('dd/MM/yyyy').format(installDate.toDate()) : 'Date inconnue', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                        _buildPremiumWarrantyBadge(warranty),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: docs.length,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPremiumWarrantyBadge(EquipmentWarranty? warranty) {
    if (warranty == null) return const SizedBox.shrink();
    Color color = Colors.redAccent;
    String text = "Expirée";
    if (warranty.isValid) {
      if (warranty.isExpiringSoon) {
        color = Colors.orange;
        text = "Expire bientôt";
      } else {
        color = Colors.green;
        text = "Sous Garantie";
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  // ✅ FULLY REWRITTEN - NO EXPANSION TILE, NO OVERFLOWS
  Widget _buildHistoryTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchStoreHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.isEmpty) return _buildEmptyState("Aucun historique récent", Icons.history_toggle_off);

        final history = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final item = history[index];
            final bool isFirst = index == 0;
            final bool isLast = index == history.length - 1;

            final Timestamp? dateTs = item['date'] as Timestamp?;
            final String formattedDate = dateTs != null ? DateFormat('dd MMM yyyy • HH:mm').format(dateTs.toDate()) : 'Date inconnue';

            final List<String> techs = item['technicians'] as List<String>? ?? [];
            final List<String> mediaUrls = item['mediaUrls'] as List<String>? ?? [];
            final String? signatureUrl = item['signatureUrl'];

            return TimelineTile(
              isFirst: isFirst,
              isLast: isLast,
              indicatorStyle: IndicatorStyle(
                width: 36,
                height: 36,
                indicator: Container(
                  decoration: BoxDecoration(color: item['color'].withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: item['color'], width: 2)),
                  child: Icon(item['icon'], size: 18, color: item['color']),
                ),
              ),
              beforeLineStyle: LineStyle(color: Colors.grey.shade300, thickness: 2),
              afterLineStyle: LineStyle(color: Colors.grey.shade300, thickness: 2),
              endChild: Container(
                margin: const EdgeInsets.only(left: 16, bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                // ✅ Using the robust custom widget here!
                child: _ExpandableHistoryCard(
                  item: item,
                  formattedDate: formattedDate,
                  techs: techs,
                  mediaUrls: mediaUrls,
                  signatureUrl: signatureUrl,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(msg, style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
        ],
      ),
    );
  }

  // ==============================================================================
  // 🏗 MAIN BUILD
  // ==============================================================================

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 160.0,
                  pinned: true,
                  elevation: 0,
                  backgroundColor: const Color(0xFF667EEA),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // ✅ CLICKABLE COVER IMAGE
                        GestureDetector(
                          onTap: () {
                            if (_localCoverUrl != null) {
                              Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => ImageGalleryPage(imageUrls: [_localCoverUrl!], initialIndex: 0)
                              ));
                            }
                          },
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  gradient: _localCoverUrl == null ? const LinearGradient(
                                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ) : null,
                                  image: _localCoverUrl != null ? DecorationImage(
                                    image: NetworkImage(_localCoverUrl!),
                                    fit: BoxFit.cover,
                                  ) : null,
                                ),
                              ),
                              if (_localCoverUrl != null)
                                Container(color: Colors.black.withOpacity(0.2)),
                            ],
                          ),
                        ),

                        Positioned(
                          top: 40,
                          right: 16,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                color: Colors.white.withOpacity(0.2),
                                child: IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                                  onPressed: () => _pickAndUploadImage(isCover: true),
                                  tooltip: "Modifier la couverture",
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  title: innerBoxIsScrolled ? Text(widget.storeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)) : null,
                ),

                _buildHeroHeader(),

                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF667EEA),
                      unselectedLabelColor: Colors.grey.shade500,
                      indicatorColor: const Color(0xFF667EEA),
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      tabs: const [
                        Tab(text: "Aperçu"),
                        Tab(text: "Parc Installé"),
                        Tab(text: "Historique"),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildEquipmentTab(),
                _buildHistoryTab(),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: const Color(0xFF667EEA),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text("Équipement", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => AddStoreEquipmentPage(clientId: widget.clientId, storeId: widget.storeId)));
            },
          ),
        ),

        // 🔄 Uploading Overlay
        if (_isUploading)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF667EEA)),
                      SizedBox(height: 16),
                      Text("Téléchargement...", style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          )
      ],
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

// ==============================================================================
// 🚀 NEW: CUSTOM EXPANDABLE HISTORY CARD (Replaces Flawed ExpansionTile)
// ==============================================================================
class _ExpandableHistoryCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final String formattedDate;
  final List<String> techs;
  final List<String> mediaUrls;
  final String? signatureUrl;

  const _ExpandableHistoryCard({
    required this.item,
    required this.formattedDate,
    required this.techs,
    required this.mediaUrls,
    this.signatureUrl,
  });

  @override
  State<_ExpandableHistoryCard> createState() => _ExpandableHistoryCardState();
}

class _ExpandableHistoryCardState extends State<_ExpandableHistoryCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, // Crucial to prevent internal overflow
      children: [
        // --- Always Visible Header ---
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              widget.item['type'],
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: widget.item['color']),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(widget.formattedDate, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(widget.item['code'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                      if (widget.techs.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: widget.techs.map((t) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.person, size: 12, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(t, style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          )).toList(),
                        )
                      ]
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.grey),
              ],
            ),
          ),
        ),

        // --- Expandable Content Body ---
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(),

                if (widget.item['primaryDesc'] != null) ...[
                  const SizedBox(height: 8),
                  Text(widget.item['primaryDescTitle'] ?? 'Détail', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(widget.item['primaryDesc'], style: const TextStyle(fontSize: 14, color: Color(0xFF475569))),
                ],

                if (widget.item['secondaryDesc'] != null) ...[
                  const SizedBox(height: 12),
                  Text(widget.item['secondaryDescTitle'] ?? 'Info', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(widget.item['secondaryDesc'], style: const TextStyle(fontSize: 14, color: Color(0xFF475569))),
                ],

                if (widget.item['extraInfo'] != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Text(widget.item['extraInfo'], style: TextStyle(fontSize: 13, color: Colors.blue.shade700, fontWeight: FontWeight.w600)),
                  ),
                ],

                // Attachments Row
                if (widget.mediaUrls.isNotEmpty || widget.signatureUrl != null) ...[
                  const SizedBox(height: 16),
                  const Text('Pièces Jointes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (var url in widget.mediaUrls)
                        GestureDetector(
                          onTap: () => launchUrl(Uri.parse(url)),
                          child: Container(
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                              image: url.contains('.mp4') ? null : DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
                            ),
                            child: url.contains('.mp4') ? const Icon(Icons.play_circle_fill, color: Colors.black45) : null,
                          ),
                        ),
                      if (widget.signatureUrl != null)
                        GestureDetector(
                          onTap: () => launchUrl(Uri.parse(widget.signatureUrl!)),
                          child: Container(
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(child: Icon(Icons.draw, color: Colors.teal)),
                          ),
                        ),
                    ],
                  )
                ],

                // Navigation Button
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text("Voir la Fiche Complète", style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.item['color'].withOpacity(0.1),
                      foregroundColor: widget.item['color'],
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      if (widget.item['type'] == 'Intervention') {
                        Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => InterventionDetailsPage(interventionDoc: widget.item['doc']))
                        );
                      } else if (widget.item['type'] == 'Installation') {
                        Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => InstallationDetailsPage(installationDoc: widget.item['doc'], userRole: UserRoles.admin))
                        );
                      } else if (widget.item['type'] == 'Livraison') {
                        Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => LivraisonDetailsPage(livraisonId: widget.item['id']))
                        );
                      } else if (widget.item['type'] == 'SAV') {
                        Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => SavTicketDetailsPage(ticket: widget.item['ticket']))
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }
}