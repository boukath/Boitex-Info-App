// lib/screens/administration/broken_stock_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';

// ✅ IMPORTS
import 'package:boitex_info_app/screens/administration/report_breakage_page.dart';
import 'package:boitex_info_app/screens/administration/quarantine_details_page.dart';
import 'package:boitex_info_app/models/quarantine_item.dart';

class BrokenStockListPage extends StatelessWidget {
  const BrokenStockListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // 🟢 Two Tabs: Active & History
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: const Text(
            "📁 Gestion SAV / Casse",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.indigo.shade800,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(icon: Icon(Icons.warning_amber_rounded), text: "En Cours (Quarantaine)"),
              Tab(icon: Icon(Icons.history), text: "Historique Global"),
            ],
          ),
        ),

        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ReportBreakagePage()),
            );
          },
          backgroundColor: Colors.red.shade700,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text("DÉCLARER CASSE"),
        ),

        body: const TabBarView(
          children: [
            _ActiveQuarantineList(),
            _QuarantineHistoryList(),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 🔴 TAB 1: ACTIVE ITEMS
// =============================================================================
class _ActiveQuarantineList extends StatelessWidget {
  const _ActiveQuarantineList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('quarantine_items')
          .where('status', isNotEqualTo: 'RESOLVED')
          .orderBy('status')
          .orderBy('reportedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 80, color: Colors.green.shade300),
                const SizedBox(height: 16),
                Text(
                  "Tout est en ordre (Aucune casse)",
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final item = QuarantineItem.fromFirestore(docs[index]);

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuarantineDetailsPage(quarantineId: item.id),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: item.photoUrl != null
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(item.photoUrl!, fit: BoxFit.cover),
                        )
                            : const Icon(Icons.broken_image, color: Colors.grey),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.productName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Réf: ${item.productReference} | Qté: ${item.quantity}",
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(
                                  "${timeago.format(item.reportedAt, locale: 'fr')} par ${item.reportedBy}",
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),

                      _buildStatusBadge(item.status),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case 'AT_SUPPLIER':
        color = Colors.blue;
        text = "SAV FOURN.";
        icon = Icons.local_shipping;
        break;
      case 'IN_REPAIR':
        color = Colors.purple;
        text = "ATELIER";
        icon = Icons.build;
        break;
      case 'PENDING':
      default:
        color = Colors.orange.shade800;
        text = "EN ATTENTE";
        icon = Icons.pause_circle_filled;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 2),
          Text(
            text,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 📜 TAB 2: GLOBAL HISTORY (Updated with Click Logic)
// =============================================================================
class _QuarantineHistoryList extends StatelessWidget {
  const _QuarantineHistoryList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('stock_movements')
          .where('type', whereIn: [
        'INTERNAL_BREAKAGE',
        'BROKEN_RESTORED',
        'BROKEN_DESTROYED',
        'QUARANTINE_RESOLVED',
        'QUARANTINE_SALVAGED',
        'SALVAGE_RECOVERY',
        'CLIENT_RETURN_BROKEN'
      ])
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text("Aucun historique récent", style: TextStyle(fontSize: 18, color: Colors.grey.shade500)),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final String type = data['type'] ?? '';
            final String productName = data['productName'] ?? 'Produit Inconnu';
            final String user = data['user'] ?? 'Inconnu';
            final Timestamp? ts = data['timestamp'];
            final DateTime date = ts != null ? ts.toDate() : DateTime.now();

            return Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: _buildHistoryIcon(type),
                title: Text(productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_getHistoryDescription(data)),
                    const SizedBox(height: 4),
                    Text(
                      "${DateFormat('dd/MM HH:mm').format(date)} • Par $user",
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                isThreeLine: true,
                dense: true,
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                // ✅ TAP ACTION
                onTap: () {
                  if (data['quarantineId'] != null) {
                    // 👉 Go to Full Case File
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => QuarantineDetailsPage(quarantineId: data['quarantineId'])
                        )
                    );
                  } else {
                    // 👉 Show Simple Bottom Sheet if no case file exists
                    _showMovementDetails(context, data);
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  void _showMovementDetails(BuildContext context, Map<String, dynamic> data) {
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))
        ),
        builder: (ctx) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildHistoryIcon(data['type'] ?? ''),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        data['productName'] ?? 'Produit',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _detailRow(Icons.person, "Utilisateur", data['user'] ?? 'N/A'),
                _detailRow(Icons.calendar_today, "Date", (data['timestamp'] as Timestamp?)?.toDate().toString() ?? 'N/A'),
                _detailRow(Icons.info_outline, "Action", data['type'] ?? 'N/A'),
                _detailRow(Icons.notes, "Note", data['reason'] ?? data['note'] ?? 'Aucune note'),
                const SizedBox(height: 10),
                if (data['brokenStockChange'] != null)
                  _detailRow(Icons.exposure, "Stock HS", "${data['brokenStockChange'] > 0 ? '+' : ''}${data['brokenStockChange']}"),
                if (data['maintenanceStockChange'] != null)
                  _detailRow(Icons.build, "Stock SAV", "${data['maintenanceStockChange'] > 0 ? '+' : ''}${data['maintenanceStockChange']}"),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Fermer"),
                  ),
                )
              ],
            ),
          );
        }
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildHistoryIcon(String type) {
    IconData icon;
    Color color;

    switch (type) {
      case 'INTERNAL_BREAKAGE':
      case 'CLIENT_RETURN_BROKEN':
        icon = Icons.broken_image;
        color = Colors.red;
        break;
      case 'BROKEN_RESTORED':
        icon = Icons.replay_circle_filled;
        color = Colors.green;
        break;
      case 'QUARANTINE_SALVAGED':
      case 'SALVAGE_RECOVERY':
        icon = Icons.build_circle;
        color = Colors.orange;
        break;
      case 'BROKEN_DESTROYED':
        icon = Icons.delete_forever;
        color = Colors.grey;
        break;
      default:
        icon = Icons.info;
        color = Colors.blue;
    }

    return CircleAvatar(
      backgroundColor: color.withOpacity(0.1),
      child: Icon(icon, color: color, size: 20),
    );
  }

  String _getHistoryDescription(Map<String, dynamic> data) {
    final type = data['type'];
    final reason = data['reason'] ?? data['note'] ?? '';
    final int qty = (data['brokenStockChange'] ?? 0).abs();

    switch (type) {
      case 'INTERNAL_BREAKAGE':
        return "🔴 Déclaré HS (-$qty). Motif: $reason";
      case 'CLIENT_RETURN_BROKEN':
        return "↩️ Retour Client HS (+$qty). $reason";
      case 'BROKEN_RESTORED':
        return "✅ Réparé & Remis en stock. $reason";
      case 'QUARANTINE_SALVAGED':
        return "🛠️ Démantelé pour pièces. $reason";
      case 'SALVAGE_RECOVERY':
        final int gained = data['maintenanceStockChange'] ?? 0;
        return "♻️ Pièce récupérée (+$gained SAV).";
      case 'BROKEN_DESTROYED':
        return "🗑️ Mis au rebut (Destruction). $reason";
      default:
        return reason;
    }
  }
}