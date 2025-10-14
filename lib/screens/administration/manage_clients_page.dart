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
            itemCount: clientDocs.length,
            itemBuilder: (context, index) {
              final clientDoc = clientDocs[index];
              final clientData = clientDoc.data() as Map<String, dynamic>;
              final clientName = clientData['name'] as String? ?? 'Client inconnu';

              final servicesRaw = clientData['service'];
              final services = (servicesRaw is List)
                  ? servicesRaw.map((s) => s.toString()).toList()
                  : [servicesRaw?.toString() ?? 'Non spécifié'];

              final avatarColor = _getAvatarColor(clientName);

              // ✅ CORRECTED: The ListTile is now simple again.
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
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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