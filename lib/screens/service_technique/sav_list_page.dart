// lib/screens/service_technique/sav_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/models/sav_ticket.dart';
import 'package:boitex_info_app/screens/service_technique/add_sav_ticket_page.dart';
import 'package:boitex_info_app/screens/service_technique/sav_ticket_details_page.dart';
import 'package:intl/intl.dart';

class SavListPage extends StatelessWidget {
  final String serviceType;

  const SavListPage({super.key, required this.serviceType});

  Widget _getStatusChip(String status) {
    Color color;
    String label = status;

    switch (status) {
      case 'Nouveau':
        color = Colors.blue;
        break;
      case 'En Diagnostic':
      case 'En Réparation':
        color = Colors.orange;
        break;
      case 'Terminé':
        color = Colors.green;
        break;
      case 'Irréparable - Remplacement Demandé':
        color = Colors.red;
        label = 'Remplacement Demandé';
        break;
      case 'Irréparable - Remplacement Approuvé':
        color = Colors.teal;
        label = 'Remplacement Approuvé';
        break;
    // This status will no longer appear on this page, but we leave the style for safety
      case 'Retourné':
        color = Colors.grey;
        break;
      default:
        color = Colors.black;
    }
    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6.0),
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gestion SAV ($serviceType)'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sav_tickets')
            .where('serviceType', isEqualTo: serviceType)
        // ✅ CHANGED: This filter removes completed tickets from this list
            .where('status', isNotEqualTo: 'Retourné')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Une erreur est survenue.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Aucun ticket SAV actif pour le moment.\nAppuyez sur + pour en créer un.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
            children: snapshot.data!.docs.map((DocumentSnapshot document) {
              final ticket = SavTicket.fromFirestore(document as DocumentSnapshot<Map<String, dynamic>>);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => SavTicketDetailsPage(ticket: ticket)),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.orange.withOpacity(0.1),
                          child: const Icon(Icons.build_outlined, color: Colors.orange),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(ticket.savCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  _getStatusChip(ticket.status),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                ticket.clientName,
                                style: TextStyle(color: Colors.grey.shade700),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Produit: ${ticket.productName}',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => AddSavTicketPage(serviceType: serviceType)),
          );
        },
        tooltip: 'Nouveau Ticket SAV',
        child: const Icon(Icons.add),
      ),
    );
  }
}