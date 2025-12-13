// lib/screens/administration/antivol_config/supplier_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// ✅ 1. Import the model we created
import 'package:boitex_info_app/models/antivol_system.dart';
// ✅ 2. Import the next page (will create a placeholder for it)
import 'package:boitex_info_app/screens/administration/antivol_config/system_list_page.dart';

class SupplierListPage extends StatefulWidget {
  final String technology; // "AM" or "RF"
  const SupplierListPage({super.key, required this.technology});

  @override
  State<SupplierListPage> createState() => _SupplierListPageState();
}

class _SupplierListPageState extends State<SupplierListPage> {
  late Future<List<String>> _suppliersFuture;

  @override
  void initState() {
    super.initState();
    _suppliersFuture = _fetchSuppliers();
  }

  /// Fetches Antivol Systems and extracts a unique, sorted list of suppliers.
  Future<List<String>> _fetchSuppliers() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('antivolSystems')
          .where('technology', isEqualTo: widget.technology)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return []; // No systems found for this technology
      }

      // Use a Set to automatically handle duplicates
      final supplierSet = <String>{};

      for (final doc in querySnapshot.docs) {
        // Use the model to safely parse data
        final system = AntivolSystem.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
        supplierSet.add(system.supplier);
      }

      // Convert to a list and sort alphabetically
      final supplierList = supplierSet.toList();
      supplierList.sort();

      return supplierList;

    } catch (e) {
      print("Erreur lors de la récupération des fournisseurs: $e");
      throw Exception('Impossible de charger les fournisseurs');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Fournisseurs ${widget.technology}'),
      ),
      body: FutureBuilder<List<String>>(
        future: _suppliersFuture,
        builder: (context, snapshot) {
          // 1. Loading State
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Error State
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erreur: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          // 3. No Data State
          final suppliers = snapshot.data;
          if (suppliers == null || suppliers.isEmpty) {
            return Center(
              child: Text(
                'Aucun fournisseur trouvé pour la technologie ${widget.technology}.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          // 4. Success State: Show the list
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: suppliers.length,
            itemBuilder: (context, index) {
              final supplierName = suppliers[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.business_rounded),
                  ),
                  title: Text(
                    supplierName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Navigate to the next page: SystemListPage
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => SystemListPage(
                          technology: widget.technology,
                          supplier: supplierName,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}