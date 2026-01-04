// lib/screens/administration/quarantine_details_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';

// ✅ IMPORTS
import 'package:boitex_info_app/models/quarantine_item.dart';
import 'package:boitex_info_app/services/stock_service.dart';
// ✅ Import the new Salvage Dialog
import 'package:boitex_info_app/screens/administration/widgets/salvage_dialog.dart';

class QuarantineDetailsPage extends StatelessWidget {
  final String quarantineId;

  const QuarantineDetailsPage({super.key, required this.quarantineId});

  // ===========================================================================
  // 🕹️ ACTIONS LOGIC
  // ===========================================================================

  void _showStatusDialog(BuildContext context, QuarantineItem item) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Changer le Statut", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // 🚚 SEND TO SUPPLIER
            if (item.status == 'PENDING')
              ListTile(
                leading: const Icon(Icons.local_shipping, color: Colors.blue),
                title: const Text("Envoyer au Fournisseur (SAV/RMA)"),
                onTap: () {
                  Navigator.pop(ctx);
                  _updateStatus(context, item.id, 'AT_SUPPLIER', "Envoi SAV Fournisseur");
                },
              ),

            // 🔧 START REPAIR
            if (item.status == 'PENDING')
              ListTile(
                leading: const Icon(Icons.build, color: Colors.orange),
                title: const Text("Commencer Réparation Interne"),
                onTap: () {
                  Navigator.pop(ctx);
                  _updateStatus(context, item.id, 'IN_REPAIR', "Prise en charge par technicien");
                },
              ),

            // 📥 RETURN FROM SUPPLIER
            if (item.status == 'AT_SUPPLIER')
              ListTile(
                leading: const Icon(Icons.move_to_inbox, color: Colors.green),
                title: const Text("Retour du Fournisseur (Reçu)"),
                onTap: () {
                  Navigator.pop(ctx);
                  _updateStatus(context, item.id, 'PENDING', "Retour fournisseur reçu");
                },
              ),

            // ⏹ STOP REPAIR
            if (item.status == 'IN_REPAIR')
              ListTile(
                leading: const Icon(Icons.stop_circle_outlined, color: Colors.red),
                title: const Text("Arrêter Réparation (Remettre en attente)"),
                onTap: () {
                  Navigator.pop(ctx);
                  _updateStatus(context, item.id, 'PENDING', "Réparation suspendue");
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showResolutionDialog(BuildContext context, QuarantineItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Résolution Finale"),
        content: const Text("Quelle est la décision finale pour cet article ?\nCette action est irréversible."),
        actions: [
          // ♻️ RESTORE (FIXED) - ✅ UPDATED: Now asks for details
          ElevatedButton.icon(
            icon: const Icon(Icons.check_circle),
            label: const Text("Réparé (Retour Stock)"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx); // Close selection
              _showRepairDetailsDialog(context, item); // Open text input
            },
          ),

          const SizedBox(height: 8),

          // 🛠️ SALVAGE (SPARE PARTS)
          ElevatedButton.icon(
            icon: const Icon(Icons.build_circle),
            label: const Text("Pièces Détachées (Salvage)"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => SalvageDialog(item: item),
              ).then((result) {
                if (result == true) {
                  // Page refreshes automatically via Stream
                }
              });
            },
          ),

          const SizedBox(height: 8),

          // 🗑️ DESTROY (TRASH)
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever),
            label: const Text("Déchet (Destruction)"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _resolve(context, item, 'DESTROY', "Mis au rebut");
            },
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Dialog to enter repair details
  void _showRepairDetailsDialog(BuildContext context, QuarantineItem item) {
    final TextEditingController detailsController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Détails de la Réparation"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Veuillez décrire la réparation effectuée (pièces changées, actions...) :"),
            const SizedBox(height: 12),
            TextField(
              controller: detailsController,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: "Ex: Remplacement fusible, soudure port charge...",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () {
              // Validate input
              if (detailsController.text.trim().isEmpty) return;

              Navigator.pop(ctx);
              // Call resolve with the user's description
              _resolve(context, item, 'RESTORE', "Réparé : ${detailsController.text.trim()}");
            },
            child: const Text("Valider et Clôturer"),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(BuildContext context, String id, String status, String note) async {
    try {
      await StockService().updateQuarantineStatus(quarantineId: id, newStatus: status, note: note);
      if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Statut mis à jour")));
    } catch (e) {
      if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _resolve(BuildContext context, QuarantineItem item, String type, String note) async {
    try {
      await StockService().resolveQuarantineItem(item: item, resolutionType: type, note: note);
      if(context.mounted) {
        Navigator.pop(context); // Close Page
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dossier clôturé avec succès"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
    }
  }

  // ===========================================================================
  // 🖥️ UI BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('quarantine_items').doc(quarantineId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (!snapshot.data!.exists) return const Scaffold(body: Center(child: Text("Dossier introuvable")));

        final item = QuarantineItem.fromFirestore(snapshot.data!);

        return Scaffold(
          appBar: AppBar(
            title: const Text("Dossier Casse"),
            backgroundColor: _getStatusColor(item.status),
            foregroundColor: Colors.white,
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 📸 1. PHOTO & HEADER
                Stack(
                  children: [
                    Container(
                      height: 250,
                      width: double.infinity,
                      color: Colors.grey.shade200,
                      child: item.photoUrl != null
                          ? Image.network(item.photoUrl!, fit: BoxFit.cover)
                          : const Center(child: Icon(Icons.broken_image, size: 64, color: Colors.grey)),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.productName,
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "Réf: ${item.productReference} | Qté: ${item.quantity}",
                              style: const TextStyle(color: Colors.white70, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // 🏷️ 2. STATUS BAR
                Container(
                  padding: const EdgeInsets.all(16),
                  color: _getStatusColor(item.status).withOpacity(0.1),
                  child: Row(
                    children: [
                      Icon(_getStatusIcon(item.status), color: _getStatusColor(item.status), size: 32),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("STATUT ACTUEL", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                          Text(
                            _getStatusLabel(item.status),
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _getStatusColor(item.status)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // 📝 3. DETAILS (Updated with Bold User Name)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(Icons.person, "Déclaré par", item.reportedBy, isBold: true),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.calendar_today, "Date", DateFormat('dd/MM/yyyy HH:mm').format(item.reportedAt)),
                      const SizedBox(height: 16),
                      const Text("Motif / Description :", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        width: double.infinity,
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                        child: Text(item.reason, style: const TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),

                const Divider(),

                // 📜 4. HISTORY (Updated with Bold User Names)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text("Derniers Mouvements", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: item.history.length,
                  itemBuilder: (context, index) {
                    final event = item.history[item.history.length - 1 - index];
                    final date = (event['date'] as Timestamp).toDate();
                    final String user = event['by'] ?? 'Inconnu';

                    return ListTile(
                      leading: const CircleAvatar(radius: 4, backgroundColor: Colors.grey),
                      title: Text(event['note'] ?? event['action']),
                      subtitle: RichText(
                        text: TextSpan(
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          children: [
                            TextSpan(text: timeago.format(date, locale: 'fr')),
                            const TextSpan(text: " par "),
                            TextSpan(
                                text: user,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)
                            ),
                          ],
                        ),
                      ),
                      visualDensity: VisualDensity.compact,
                    );
                  },
                ),

                const SizedBox(height: 80), // Space for FAB
              ],
            ),
          ),

          // 🔘 5. FLOATING ACTION BUTTONS
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          floatingActionButton: item.status == 'RESOLVED'
              ? null
              : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // ACTION 1: Workflow (Supplier/Repair)
                Expanded(
                  child: FloatingActionButton.extended(
                    heroTag: "btn1",
                    onPressed: () => _showStatusDialog(context, item),
                    backgroundColor: Colors.indigo,
                    icon: const Icon(Icons.swap_horiz, color: Colors.white),
                    label: const Text("Flux", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                // ACTION 2: Resolve (Fix/Trash/Spare)
                Expanded(
                  child: FloatingActionButton.extended(
                    heroTag: "btn2",
                    onPressed: () => _showResolutionDialog(context, item),
                    backgroundColor: Colors.green.shade700,
                    icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                    label: const Text("Clôturer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- HELPERS ---

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isBold = false}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text("$label: ", style: const TextStyle(color: Colors.grey)),
        Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontSize: isBold ? 16 : 14, // Slightly larger if bold
            )
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING': return Colors.orange;
      case 'AT_SUPPLIER': return Colors.blue;
      case 'IN_REPAIR': return Colors.purple;
      case 'RESOLVED': return Colors.green;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'PENDING': return Icons.pause_circle_filled;
      case 'AT_SUPPLIER': return Icons.local_shipping;
      case 'IN_REPAIR': return Icons.build;
      case 'RESOLVED': return Icons.check_circle;
      default: return Icons.help;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'PENDING': return "En Attente (Stock HS)";
      case 'AT_SUPPLIER': return "Chez Fournisseur (SAV)";
      case 'IN_REPAIR': return "En Réparation (Interne)";
      case 'RESOLVED': return "Clôturé / Résolu";
      default: return status;
    }
  }
}