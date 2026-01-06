// lib/screens/administration/manage_stores_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_slidable/flutter_slidable.dart'; // ✅ Swipe Actions
import 'package:boitex_info_app/screens/administration/add_store_page.dart';
import 'package:boitex_info_app/screens/administration/store_equipment_page.dart';
import 'package:boitex_info_app/services/store_qr_pdf_service.dart';

class ManageStoresPage extends StatelessWidget {
  final String clientId;
  final String clientName;

  const ManageStoresPage({
    super.key,
    required this.clientId,
    required this.clientName,
  });

  /// Logic to handle QR printing & Token Generation
  Future<void> _handlePrintQr(BuildContext context, DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    String storeId = doc.id;
    String storeName = data['name'] ?? 'Magasin';

    String? token = data['qr_access_token'];

    if (token == null || token.isEmpty) {
      token = const Uuid().v4();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Génération du token de sécurité...")),
      );
      await doc.reference.update({'qr_access_token': token});
    }

    if (context.mounted) {
      await StoreQrPdfService.generateStoreQr(
        storeName,
        clientName,
        storeId,
        token,
      );
    }
  }

  /// ✅ ACTION 1: Archive (Soft Delete) - Swipe LEFT
  Future<void> _archiveStore(BuildContext context, DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final storeName = data['name'] ?? 'ce magasin';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Archiver le magasin ?"),
        content: Text(
            "Êtes-vous sûr de vouloir archiver '$storeName' ?\n\n"
                "Il disparaîtra de cette liste, mais l'historique sera conservé."
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text("Archiver"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await doc.reference.update({
        'status': 'archived',
        'archivedAt': FieldValue.serverTimestamp(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Magasin '$storeName' archivé.")),
        );
      }
    }
  }

  /// ✅ ACTION 2: Hard Delete - Swipe RIGHT
  Future<void> _deleteStore(BuildContext context, DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final storeName = data['name'] ?? 'ce magasin';

    // 🛑 DANGER ALERT DIALOG
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Supprimer DÉFINITIVEMENT ?"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                "Vous êtes sur le point de supprimer '$storeName'.",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Cette action est irréversible. Tout l'historique et les équipements associés risquent d'être perdus ou orphelins.",
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Annuler")
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("SUPPRIMER", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Perform Hard Delete
      await doc.reference.delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Magasin supprimé définitivement."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(clientName),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clients')
            .doc(clientId)
            .collection('stores')
            .orderBy('name')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Une erreur est survenue.'));
          }

          // Filter out archived stores
          final stores = snapshot.data?.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'active';
            return status != 'archived';
          }).toList() ?? [];

          if (stores.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: stores.length,
            itemBuilder: (context, index) {
              var storeDoc = stores[index];
              var storeData = storeDoc.data() as Map<String, dynamic>;
              String storeName = storeData['name'] ?? 'Nom Inconnu';
              String storeLocation = storeData['location'] ?? 'Localisation Inconnue';
              String storeId = storeDoc.id;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Slidable(
                  key: Key(storeId),

                  // ✅ SWIPE RIGHT -> DELETE (Red)
                  startActionPane: ActionPane(
                    motion: const ScrollMotion(),
                    children: [
                      SlidableAction(
                        onPressed: (context) => _deleteStore(context, storeDoc),
                        backgroundColor: Colors.red.shade100,
                        foregroundColor: Colors.red.shade900,
                        icon: Icons.delete_forever,
                        label: 'Supprimer',
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ],
                  ),

                  // ✅ SWIPE LEFT -> ARCHIVE (Orange)
                  endActionPane: ActionPane(
                    motion: const ScrollMotion(),
                    children: [
                      SlidableAction(
                        onPressed: (context) => _archiveStore(context, storeDoc),
                        backgroundColor: Colors.orange.shade100,
                        foregroundColor: Colors.orange.shade900,
                        icon: Icons.archive,
                        label: 'Archiver',
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ],
                  ),

                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    splashColor: Colors.teal.withOpacity(0.1),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StoreEquipmentPage(
                            clientId: clientId,
                            storeId: storeId,
                            storeName: storeName,
                          ),
                        ),
                      );
                    },
                    // Long press to edit details
                    onLongPress: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddStorePage(
                            clientId: clientId,
                            storeId: storeId,
                            initialData: storeData,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.store,
                                color: Colors.teal, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  storeName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2D3748),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined,
                                        size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        storeLocation,
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.qr_code_2, color: Colors.black87),
                            tooltip: "Imprimer le QR Code",
                            onPressed: () => _handlePrintQr(context, storeDoc),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => AddStorePage(clientId: clientId)));
        },
        tooltip: 'Ajouter un Magasin',
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add_business_outlined),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store_mall_directory_outlined,
              size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Aucun magasin actif trouvé.',
              style: TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }
}