// lib/screens/administration/manage_clients_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/screens/administration/add_client_page.dart';
import 'package:boitex_info_app/screens/administration/manage_stores_page.dart';

class ManageClientsPage extends StatelessWidget {
  final String userRole;

  const ManageClientsPage({super.key, required this.userRole});

  Color _getAvatarColor(String clientName) {
    // Simple hash to get a color based on name
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
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 80), // Padding for FAB
            itemCount: clientDocs.length,
            itemBuilder: (context, index) {
              final clientDoc = clientDocs[index];
              // Safely cast data to Map<String, dynamic>
              final clientData = clientDoc.data() as Map<String, dynamic>? ?? {};

              final clientName = clientData['name'] as String? ?? 'Nom inconnu';
              final services = List<String>.from(clientData['services'] ?? []);
              final avatarColor = _getAvatarColor(clientName);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                  subtitle: Text(services.isNotEmpty ? 'Services: ${services.join(', ')}' : 'Aucun service'),
                  // ✅ MODIFIED: Trailing now has an edit button
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min, // Important for Row in ListTile trailing
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit_outlined, color: Colors.blue.shade700),
                        tooltip: 'Modifier Client',
                        onPressed: () {
                          // Navigate to AddClientPage in Edit Mode
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => AddClientPage(
                                clientId: clientDoc.id,
                                initialData: clientData, // Pass existing data
                              ),
                            ),
                          );
                        },
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16), // Keep the arrow
                    ],
                  ),
                  onTap: () {
                    // Navigate to Manage Stores Page
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
          // Navigate to AddClientPage in Add Mode (no parameters)
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