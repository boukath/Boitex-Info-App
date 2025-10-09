import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/screens/administration/add_system_page.dart';
// **CHANGE**: Import the new system details page
import 'package:boitex_info_app/screens/administration/system_details_page.dart';

class StoreDetailsPage extends StatelessWidget {
  // ... (Constructor and properties do not change)
  final String clientId;
  final String storeId;
  final String storeName;
  final String storeLocation;

  const StoreDetailsPage({
    super.key,
    required this.clientId,
    required this.storeId,
    required this.storeName,
    required this.storeLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(storeName),
            Text(storeLocation, style: const TextStyle(fontSize: 14, color: Colors.white70)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text('Systèmes Antivol', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('clients').doc(clientId)
                .collection('stores').doc(storeId)
                .collection('systems').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Card(child: ListTile(title: Text('Aucun système trouvé')));
              }
              final systemDocs = snapshot.data!.docs;
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: systemDocs.length,
                itemBuilder: (context, index) {
                  final systemDoc = systemDocs[index];
                  final systemData = systemDoc.data() as Map<String, dynamic>;
                  return Card(
                    child: ListTile(
                      title: Text(systemData['name'] ?? ''),
                      subtitle: Text(systemData['type'] ?? ''),
                      // **CHANGE**: Add navigation to the details page
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => SystemDetailsPage(
                              clientId: clientId,
                              storeId: storeId,
                              systemId: systemDoc.id,
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
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AddSystemPage(
                clientId: clientId,
                storeId: storeId,
              ),
            ),
          );
        },
        tooltip: 'Ajouter un système',
        child: const Icon(Icons.add),
      ),
    );
  }
}