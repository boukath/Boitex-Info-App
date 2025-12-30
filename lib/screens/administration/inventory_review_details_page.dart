// lib/screens/administration/inventory_review_details_page.dart

import 'package:flutter/material.dart';
import 'package:boitex_info_app/models/inventory_session.dart';
import 'package:boitex_info_app/services/inventory_service.dart';

class InventoryReviewDetailsPage extends StatefulWidget {
  final InventorySession session;

  const InventoryReviewDetailsPage({super.key, required this.session});

  @override
  State<InventoryReviewDetailsPage> createState() => _InventoryReviewDetailsPageState();
}

class _InventoryReviewDetailsPageState extends State<InventoryReviewDetailsPage> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text("Revue: ${widget.session.scope}"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<InventoryItem>>(
        stream: InventoryService().getSessionItems(widget.session.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Erreur: Inventaire vide"));
          }

          final items = snapshot.data!;
          // Calculate stats
          int totalDiff = 0;
          for (var i in items) totalDiff += i.difference;

          return Column(
            children: [
              // 📊 SUMMARY HEADER
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat("Articles", "${items.length}", Colors.black),
                    _buildStat("Ecart Total", "${totalDiff > 0 ? '+' : ''}$totalDiff", totalDiff == 0 ? Colors.green : (totalDiff < 0 ? Colors.red : Colors.blue)),
                  ],
                ),
              ),

              // 📝 LIST
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final hasDiff = item.difference != 0;

                    return Card(
                      color: hasDiff ? (item.difference < 0 ? Colors.red.shade50 : Colors.blue.shade50) : Colors.white,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Système: ${item.systemQuantity}  |  Compté: ${item.countedQuantity}"),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: hasDiff ? (item.difference < 0 ? Colors.red : Colors.blue) : Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "${item.difference > 0 ? '+' : ''}${item.difference}",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        color: Colors.white,
        child: _isProcessing
            ? const Center(child: CircularProgressIndicator())
            : Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _rejectSession(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text("REJETER"),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _approveSession(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text("VALIDER & MAJ STOCK"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Future<void> _approveSession(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirmer la mise à jour ?"),
        content: const Text("ATTENTION : Cela va modifier le stock réel de tous les articles listés.\n\nCette action est irréversible."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("OUI, METTRE À JOUR"),
          )
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      await InventoryService().approveSession(widget.session.id);
      if (mounted) {
        Navigator.pop(context); // Close details
        Navigator.pop(context); // Close list (optional)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Stock mis à jour avec succès !"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _rejectSession(BuildContext context) async {
    // Similar logic for reject...
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Rejeter l'inventaire ?"),
        content: const Text("Cet inventaire sera marqué comme rejeté et le stock ne sera PAS modifié."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("REJETER"),
          )
        ],
      ),
    );

    if (confirm == true) {
      await InventoryService().rejectSession(widget.session.id);
      if (mounted) Navigator.pop(context);
    }
  }
}