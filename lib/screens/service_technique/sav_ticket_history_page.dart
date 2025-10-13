// lib/screens/service_technique/sav_ticket_history_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/models/sav_ticket.dart';
import 'package:boitex_info_app/screens/service_technique/sav_ticket_details_page.dart';

// ✅ MODIFIED: Converted to a StatefulWidget
class SavTicketHistoryPage extends StatefulWidget {
  final String serviceType;

  const SavTicketHistoryPage({super.key, required this.serviceType});

  @override
  State<SavTicketHistoryPage> createState() => _SavTicketHistoryPageState();
}

class _SavTicketHistoryPageState extends State<SavTicketHistoryPage> {
  // ✅ ADDED: State variable for the search query
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historique SAV - ${widget.serviceType}'),
        backgroundColor: Colors.orange,
      ),
      body: Column(
        children: [
          // ✅ ADDED: Search bar UI
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: const InputDecoration(
                labelText: 'Rechercher (Code, Client, Produit...)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12.0)),
                ),
              ),
            ),
          ),
          // ✅ ADDED: Expanded to make the list scrollable within the Column
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('sav_tickets')
                  .where('serviceType', isEqualTo: widget.serviceType)
                  .where('status', isEqualTo: 'Retourné')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (BuildContext context,
                  AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Une erreur est survenue.'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text('Aucun ticket SAV retourné trouvé.'));
                }

                // ✅ ADDED: Filtering logic
                final allTickets = snapshot.data!.docs.map((doc) {
                  return SavTicket.fromFirestore(
                      doc as DocumentSnapshot<Map<String, dynamic>>);
                }).toList();

                final filteredTickets = allTickets.where((ticket) {
                  final query = _searchQuery.toLowerCase();
                  return ticket.savCode.toLowerCase().contains(query) ||
                      ticket.clientName.toLowerCase().contains(query) ||
                      ticket.productName.toLowerCase().contains(query) ||
                      ticket.serialNumber.toLowerCase().contains(query);
                }).toList();

                if (filteredTickets.isEmpty) {
                  return const Center(child: Text('Aucun résultat trouvé.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  itemCount: filteredTickets.length,
                  itemBuilder: (context, index) {
                    final ticket = filteredTickets[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) =>
                                SavTicketDetailsPage(ticket: ticket),
                          ));
                        },
                        borderRadius: BorderRadius.circular(12.0),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: Colors.grey,
                                child: Icon(Icons.history, color: Colors.white),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(ticket.savCode,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Client: ${ticket.clientName}',
                                      style: TextStyle(
                                          color: Colors.grey.shade700),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Produit: ${ticket.productName}',
                                      style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: Colors.grey),
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
        ],
      ),
    );
  }
}