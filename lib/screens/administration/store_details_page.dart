// lib/screens/administration/store_details_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/screens/administration/add_system_page.dart';
import 'package:boitex_info_app/screens/administration/system_details_page.dart';
// Import the ContactInfo model
import 'package:boitex_info_app/screens/administration/add_client_page.dart' show ContactInfo;
// Import AddStorePage for the Edit button
import 'package:boitex_info_app/screens/administration/add_store_page.dart';
// Import url_launcher to make contacts tappable
import 'package:url_launcher/url_launcher.dart';
// ✅ 1. Import StoreEquipmentPage for navigation
import 'package:boitex_info_app/screens/administration/store_equipment_page.dart';


class StoreDetailsPage extends StatelessWidget {
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

  // Function to build the contacts section (Unchanged)
  Widget _buildContactsSection(BuildContext context, List<dynamic> contactsData) {
    // ... (Keep the existing _buildContactsSection code)
    if (contactsData.isEmpty) {
      return const SizedBox.shrink(); // Don't show section if no contacts
    }

    final List<ContactInfo> contacts = contactsData
        .asMap()
        .entries
        .map((entry) => ContactInfo.fromMap(entry.value as Map<String, dynamic>, entry.key.toString()))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Contacts Magasin',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.teal),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: contacts.length,
          itemBuilder: (context, index) {
            final contact = contacts[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: Icon(contact.icon, color: Colors.teal),
                title: Text(contact.value),
                subtitle: Text(contact.label),
                onTap: () => _launchContact(contact), // Make contacts tappable
              ),
            );
          },
        ),
        const SizedBox(height: 16), // Spacing after contacts
      ],
    );
  }

  // Helper function to launch phone or email (Unchanged)
  Future<void> _launchContact(ContactInfo contact) async {
    // ... (Keep the existing _launchContact code)
    Uri? uri;
    if (contact.type == 'Téléphone') {
      uri = Uri.tryParse('tel:${contact.value}');
    } else if (contact.type == 'E-mail') {
      uri = Uri.tryParse('mailto:${contact.value}');
    }

    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Handle error (e.g., show a SnackBar)
      print('Could not launch ${contact.value}');
    }
  }

  // ✅ 2. NEW FUNCTION: Build Equipment Overview Card
  Widget _buildEquipmentOverviewCard(BuildContext context) {
    // Reference to the equipment subcollection
    final equipmentCollectionRef = FirebaseFirestore.instance
        .collection('clients')
        .doc(clientId)
        .collection('stores')
        .doc(storeId)
        .collection('materiel_installe');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Matériel Installé',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.blueGrey),
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: equipmentCollectionRef.snapshots(), // Listen for changes
          builder: (context, snapshot) {
            int count = 0;
            if (snapshot.connectionState == ConnectionState.active && snapshot.hasData) {
              count = snapshot.data!.docs.length; // Get the count of documents
            }

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: const Icon(Icons.inventory_2_outlined, color: Colors.blueGrey),
                title: Text(
                  '$count ${count == 1 ? "item enregistré" : "items enregistrés"}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // Navigate to the StoreEquipmentPage
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
              ),
            );
          },
        ),
        const SizedBox(height: 16), // Spacing after card
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    // Reference to the specific store document
    final storeDocRef = FirebaseFirestore.instance
        .collection('clients')
        .doc(clientId)
        .collection('stores')
        .doc(storeId);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal, // Match store theme color
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(storeName),
            Text(storeLocation, style: const TextStyle(fontSize: 14, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Modifier Magasin',
            onPressed: () async {
              // ... (Keep existing edit button logic)
              try {
                final storeSnapshot = await storeDocRef.get();
                if (storeSnapshot.exists && context.mounted) {
                  final storeData = storeSnapshot.data() as Map<String, dynamic>;
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
                }
              } catch (e) {
                print("Error fetching store data for edit: $e");
                // Optionally show an error message
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
          stream: storeDocRef.snapshots(),
          builder: (context, snapshot) {
            // ... (Keep existing loading/error/not found checks)
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Erreur: ${snapshot.error}'));
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('Magasin non trouvé.'));
            }


            final storeData = snapshot.data!.data() as Map<String, dynamic>;
            final List<dynamic> contactsData = storeData['storeContacts'] ?? [];

            return ListView(
              padding: const EdgeInsets.only(bottom: 80), // Padding for FAB
              children: [
                // --- Display Store Contacts ---
                _buildContactsSection(context, contactsData),

                // ✅ 3. ADDED: Display Equipment Overview Card
                _buildEquipmentOverviewCard(context),

                // --- Existing Systems Section ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Systèmes Antivol Installés',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.teal), // Kept teal color
                  ),
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  // Stream for the systems subcollection remains the same
                  stream: storeDocRef.collection('systems').orderBy('name').snapshots(),
                  builder: (context, systemSnapshot) {
                    // ... (Keep existing systems list builder logic)
                    if (systemSnapshot.connectionState == ConnectionState.waiting) {
                      // Show a smaller loading indicator within the section
                      return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)));
                    }
                    if (systemSnapshot.hasError) {
                      return Center(child: Text('Erreur chargement systèmes: ${systemSnapshot.error}'));
                    }
                    if (!systemSnapshot.hasData || systemSnapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20.0),
                          child: Text('Aucun système antivol enregistré.'),
                        ),
                      );
                    }

                    final systemDocs = systemSnapshot.data!.docs;

                    // Use ListView.builder directly (no need for Column + shrinkWrap if it's the main list content)
                    return ListView.builder(
                      shrinkWrap: true, // Keep if inside the outer ListView
                      physics: const NeverScrollableScrollPhysics(), // Keep if inside the outer ListView
                      itemCount: systemDocs.length,
                      itemBuilder: (context, index) {
                        final systemDoc = systemDocs[index];
                        final systemData = systemDoc.data() as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: ListTile(
                            leading: const Icon(Icons.shield_outlined, color: Colors.teal),
                            title: Text(systemData['name'] ?? 'Nom Inconnu'),
                            subtitle: Text('Type: ${systemData['type'] ?? 'N/A'}'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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
            );
          }
      ),
      floatingActionButton: FloatingActionButton(
        // ... (Keep existing FAB for adding systems)
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
        backgroundColor: Colors.teal, // Match theme
        child: const Icon(Icons.add),
      ),
    );
  }
}