// lib/screens/fleet/repair_order_details_page.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; // Add this to pubspec if not present, or remove logic
import 'package:boitex_info_app/models/repair_order.dart';

class RepairOrderDetailsPage extends StatefulWidget {
  final String orderId;

  const RepairOrderDetailsPage({super.key, required this.orderId});

  @override
  State<RepairOrderDetailsPage> createState() => _RepairOrderDetailsPageState();
}

class _RepairOrderDetailsPageState extends State<RepairOrderDetailsPage> {
  RepairOrder? _order;
  bool _isLoading = true;
  bool _isSaving = false;

  // Controllers for editing
  final TextEditingController _mechanicNotesCtrl = TextEditingController();
  final TextEditingController _costCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchOrder();
  }

  Future<void> _fetchOrder() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('repair_orders').doc(widget.orderId).get();
      if (doc.exists) {
        setState(() {
          _order = RepairOrder.fromFirestore(doc);
          _mechanicNotesCtrl.text = _order!.mechanicNotes ?? '';
          _costCtrl.text = _order!.finalCost > 0 ? _order!.finalCost.toStringAsFixed(0) : '';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching order: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // 🔄 WORKFLOW ACTIONS
  // ---------------------------------------------------------------------------

  Future<void> _updateStatus(RepairStatus newStatus) async {
    setState(() => _isSaving = true);
    try {
      final updates = <String, dynamic>{
        'status': newStatus.name,
      };

      // Logic triggers
      if (newStatus == RepairStatus.inProgress) {
        // Optional: Notify Mechanic?
      } else if (newStatus == RepairStatus.completed) {
        // Validate
        if (_costCtrl.text.isEmpty) {
          _showError("Veuillez saisir le coût final avant de terminer.");
          setState(() => _isSaving = false);
          return;
        }
        updates['finalCost'] = double.tryParse(_costCtrl.text) ?? 0.0;
        updates['mechanicNotes'] = _mechanicNotesCtrl.text;
      } else if (newStatus == RepairStatus.archived) {
        // 🟢 RESTORE VEHICLE TO AVAILABLE
        if (_order != null) {
          await FirebaseFirestore.instance.collection('vehicles').doc(_order!.vehicleId).update({
            'status': 'available',
          });
        }
      }

      await FirebaseFirestore.instance.collection('repair_orders').doc(widget.orderId).update(updates);
      await _fetchOrder(); // Refresh local data

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Statut mis à jour !")));

    } catch (e) {
      _showError("Erreur: $e");
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // ✅ ITEM TOGGLE (Mechanic Checklist)
  // ---------------------------------------------------------------------------

  Future<void> _toggleItemDone(int index, bool? value) async {
    if (_order == null) return;

    // Create a copy of items
    List<RepairItem> updatedItems = List.from(_order!.items);

    // Update the specific item
    // We have to recreate the RepairItem because it's final (immutable)
    RepairItem oldItem = updatedItems[index];
    updatedItems[index] = RepairItem(
      title: oldItem.title,
      description: oldItem.description,
      photoUrl: oldItem.photoUrl,
      cost: oldItem.cost,
      isDone: value ?? false, // New Value
    );

    // Optimistic UI Update
    setState(() {
      _order = RepairOrder(
        id: _order!.id,
        vehicleId: _order!.vehicleId,
        vehicleName: _order!.vehicleName,
        createdAt: _order!.createdAt,
        appointmentDate: _order!.appointmentDate,
        garageName: _order!.garageName,
        garagePhone: _order!.garagePhone,
        garageAddress: _order!.garageAddress,
        items: updatedItems,
        estimatedCost: _order!.estimatedCost,
        finalCost: _order!.finalCost,
        attachmentUrls: _order!.attachmentUrls,
        status: _order!.status,
        managerNotes: _order!.managerNotes,
        mechanicNotes: _order!.mechanicNotes,
      );
    });

    // Save to Firestore
    await FirebaseFirestore.instance.collection('repair_orders').doc(widget.orderId).update({
      'items': updatedItems.map((x) => x.toMap()).toList(),
    });
  }

  // ---------------------------------------------------------------------------
  // 📸 UPLOAD INVOICE (Similar to Inspection)
  // ---------------------------------------------------------------------------
  Future<void> _uploadDocument() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (img == null) return;

    setState(() => _isSaving = true);

    try {
      // 1. Get Url
      final uri = Uri.parse('https://europe-west1-boitexinfo-817cf.cloudfunctions.net/getB2UploadUrl');
      final configResponse = await http.get(uri);
      if (configResponse.statusCode != 200) throw Exception('Auth Error');
      final config = jsonDecode(configResponse.body);

      // 2. Upload
      final fileName = 'repairs/${widget.orderId}/${DateTime.now().millisecondsSinceEpoch}${path.extension(img.path)}';
      final bytes = await File(img.path).readAsBytes();
      final sha1Checksum = sha1.convert(bytes).toString();

      final uploadResponse = await http.post(
        Uri.parse(config['uploadUrl']),
        headers: {
          'Authorization': config['authorizationToken'],
          'X-Bz-File-Name': Uri.encodeComponent(fileName),
          'Content-Type': 'b2/x-auto',
          'X-Bz-Content-Sha1': sha1Checksum,
        },
        body: bytes,
      );

      if (uploadResponse.statusCode != 200) throw Exception('Upload Failed');
      final downloadUrl = '${config['downloadUrlPrefix']}$fileName';

      // 3. Update Firestore
      await FirebaseFirestore.instance.collection('repair_orders').doc(widget.orderId).update({
        'attachmentUrls': FieldValue.arrayUnion([downloadUrl])
      });

      await _fetchOrder(); // Refresh
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Document ajouté !")));

    } catch (e) {
      _showError("Erreur Upload: $e");
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  // ---------------------------------------------------------------------------
  // 🎨 UI BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CupertinoActivityIndicator()));
    if (_order == null) return const Scaffold(body: Center(child: Text("Ordre introuvable")));

    final isEditable = _order!.status == RepairStatus.scheduled || _order!.status == RepairStatus.inProgress;
    final isFinished = _order!.status == RepairStatus.completed || _order!.status == RepairStatus.archived;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(_order!.vehicleName, style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _order!.statusColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_order!.statusLabel, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 📍 1. GARAGE HEADER
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.store, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(_order!.garageName ?? 'Garage Inconnu', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (_order!.garagePhone != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 32, top: 4),
                      child: Text(_order!.garagePhone!, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
                    ),
                  const SizedBox(height: 12),
                  if (_order!.managerNotes != null && _order!.managerNotes!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text("Note Manager: ${_order!.managerNotes}", style: TextStyle(color: Colors.orange.shade900, fontSize: 12))),
                        ],
                      ),
                    )
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ✅ 2. CHECKLIST
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Align(alignment: Alignment.centerLeft, child: Text("LISTE DES TRAVAUX", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 12))),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              itemCount: _order!.items.length,
              itemBuilder: (context, index) {
                final item = _order!.items[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: item.isDone ? Colors.green.shade200 : Colors.grey.shade200)),
                  child: CheckboxListTile(
                    activeColor: Colors.green,
                    title: Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: item.isDone ? TextDecoration.lineThrough : null,
                        color: item.isDone ? Colors.grey : Colors.black,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.description),
                        if (item.photoUrl != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: GestureDetector(
                              // TODO: Open Image Viewer
                              onTap: () {},
                              child: const Text("📸 Voir photo défaut", style: TextStyle(color: Colors.blue, fontSize: 11)),
                            ),
                          )
                      ],
                    ),
                    value: item.isDone,
                    onChanged: isEditable
                        ? (val) => _toggleItemDone(index, val)
                        : null, // Read-only if draft or archived
                  ),
                );
              },
            ),

            // 💰 3. FINANCIALS & DOCS
            if (isEditable || isFinished) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("FACTURATION & DIAGNOSTIC", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _mechanicNotesCtrl,
                      maxLines: 2,
                      enabled: isEditable,
                      decoration: InputDecoration(
                        labelText: "Verdict du mécanicien",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _costCtrl,
                      keyboardType: TextInputType.number,
                      enabled: isEditable,
                      decoration: InputDecoration(
                        labelText: "Coût Final (DZD)",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        suffixIcon: const Icon(Icons.attach_money),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ATTACHMENTS
                    if (_order!.attachmentUrls.isNotEmpty)
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _order!.attachmentUrls.length,
                          itemBuilder: (context, index) {
                            return Container(
                              width: 80,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(image: NetworkImage(_order!.attachmentUrls[index]), fit: BoxFit.cover),
                              ),
                            );
                          },
                        ),
                      ),

                    if (isEditable)
                      TextButton.icon(
                        onPressed: _uploadDocument,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text("Ajouter Photo / Facture"),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),

      // 🚀 4. ACTION BUTTON
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget? _buildBottomBar() {
    if (_order == null) return null;

    String label = "";
    Color color = Colors.black;
    VoidCallback? action;

    switch (_order!.status) {
      case RepairStatus.draft:
        label = "VALIDER LE RDV (ENVOYER)";
        action = () => _updateStatus(RepairStatus.scheduled);
        break;
      case RepairStatus.scheduled:
        label = "DÉMARRER LES TRAVAUX";
        color = Colors.blue;
        action = () => _updateStatus(RepairStatus.inProgress);
        break;
      case RepairStatus.inProgress:
        label = "TERMINER & FACTURER";
        color = Colors.green;
        action = () => _updateStatus(RepairStatus.completed);
        break;
      case RepairStatus.completed:
        label = "ARCHIVER (CLÔTURER)";
        color = Colors.grey;
        action = () => _updateStatus(RepairStatus.archived);
        break;
      case RepairStatus.archived:
        return null; // No button
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _isSaving ? null : action,
            child: _isSaving
                ? const CupertinoActivityIndicator(color: Colors.white)
                : Text(label, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}