import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/screens/administration/add_client_page.dart';
import 'package:boitex_info_app/screens/administration/manage_stores_page.dart';

class ManageClientsPage extends StatelessWidget {
  final String userRole;

  const ManageClientsPage({super.key, required this.userRole});

  Color _getAvatarColor(String clientName) {
    return Colors.primaries[clientName.hashCode % Colors.primaries.length].shade300;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients & Magasins'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // **MODIFIED**: Added .orderBy('name') to sort the list alphabetically
        stream: FirebaseFirestore.instance.collection('clients').orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Une erreur est survenue.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Aucun client trouvé.'));
          }

          final clientDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8.0, bottom: 80.0),
            itemCount: clientDocs.length,
            itemBuilder: (context, index) {
              final clientDoc = clientDocs[index];
              final clientData = clientDoc.data() as Map<String, dynamic>;
              final clientName = clientData['name'] as String? ?? 'Nom inconnu';
              final services = clientData['services'] as List<dynamic>? ?? [];
              final avatarColor = _getAvatarColor(clientName);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: avatarColor,
                    child: Text(
                      clientName.isNotEmpty ? clientName[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(clientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Services: ${services.join(', ')}'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ManageStoresPage(
                          clientId: clientDoc.id,
                          clientName: clientName,
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddClientPage()),
          );
        },
        tooltip: 'Ajouter un client',
        child: const Icon(Icons.add),
      ),
    );
  }
}