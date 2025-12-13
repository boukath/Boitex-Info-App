// lib/screens/administration/approvals_required_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class ApprovalsRequiredPage extends StatelessWidget {
  const ApprovalsRequiredPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textStyle = GoogleFonts.poppins;
    return Scaffold(
      appBar: AppBar(
        title: Text('Approbations Requises', style: textStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF008080),
        leading: BackButton(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('requisitions')
            .where('status', isEqualTo: 'en attente d\'approbation')
            .orderBy('requestedAt', descending: true)
            .snapshots(), // web:82
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Text('Aucune demande en attente', style: textStyle(fontSize: 16)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final id = docs[i].id;
              final requestedBy = data['requestedBy'] ?? '—';
              final items = (data['requestedItems'] as List<dynamic>? ?? []);
              final status = data['status'] ?? '—';
              final ts = (data['requestedAt'] as Timestamp?)?.toDate();
              final dateStr = ts != null
                  ? DateFormat('dd/MM/yy').format(ts)
                  : '—';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.inventory_2, color: Colors.purple),
                  ),
                  title: Text('Demandé par : $requestedBy',
                      style: textStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  subtitle: Text('${items.length} article(s) · Statut : $status',
                      style: textStyle(color: Colors.grey[700])),
                  trailing: Text(dateStr,
                      style: textStyle(color: Colors.grey[600], fontSize: 12)),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/requisitionDetails',
                      arguments: {'id': id},
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
