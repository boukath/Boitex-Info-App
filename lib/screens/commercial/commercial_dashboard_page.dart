// lib/screens/commercial/commercial_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:boitex_info_app/screens/commercial/add_prospect_page.dart';

class CommercialDashboardPage extends StatelessWidget {
  const CommercialDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tableau de Bord Commercial"),
        backgroundColor: const Color(0xFFFF9966),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFFF9966).withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('prospects')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            // 1. Loading State
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // 2. Error State
            if (snapshot.hasError) {
              return Center(
                child: Text("Erreur: ${snapshot.error}"),
              );
            }

            // 3. Empty State
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.store_mall_directory_outlined,
                        size: 80, color: Colors.grey.withOpacity(0.5)),
                    const SizedBox(height: 20),
                    const Text(
                      "Aucun prospect trouvé",
                      style: TextStyle(fontSize: 20, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Appuyez sur + pour ajouter le premier",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            // 4. Data List
            final prospects = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: prospects.length,
              itemBuilder: (context, index) {
                final data = prospects[index].data() as Map<String, dynamic>;
                final createdTimestamp = data['createdAt'] as Timestamp?;
                final date = createdTimestamp?.toDate() ?? DateTime.now();

                // Extract fields safely
                final companyName = data['companyName'] ?? 'Sans nom';
                final serviceType = data['serviceType'] ?? 'Activité inconnue';
                final contactName = data['contactName'] ?? 'Aucun contact';
                final address = data['address'] ?? '';
                // Extract just the Commune part from address (before the "-")
                final commune = address.contains('-')
                    ? address.split('-')[0].trim()
                    : address;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      // TODO: Navigate to Detail Page (We can build this next)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Détails de $companyName à venir...")),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Service Type Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF9966).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFFFF9966).withOpacity(0.5)),
                                ),
                                child: Text(
                                  serviceType.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFE65100),
                                  ),
                                ),
                              ),
                              // Time Ago
                              Text(
                                timeago.format(date, locale: 'fr'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.store,
                                    color: Color(0xFFFF9966)),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      companyName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF333333),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.person,
                                            size: 14, color: Colors.grey.shade600),
                                        const SizedBox(width: 4),
                                        Text(
                                          contactName,
                                          style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(Icons.location_on,
                                            size: 14, color: Colors.grey.shade600),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            commune, // Displaying only the Commune for cleaner UI
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: Colors.grey),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddProspectPage(),
            ),
          );
        },
        backgroundColor: const Color(0xFFFF9966),
        icon: const Icon(Icons.add_business),
        label: const Text("Nouveau Prospect"),
      ),
    );
  }
}