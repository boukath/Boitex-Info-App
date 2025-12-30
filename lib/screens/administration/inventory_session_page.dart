// lib/screens/administration/inventory_session_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/models/inventory_session.dart';
import 'package:boitex_info_app/services/inventory_service.dart';

class InventorySessionPage extends StatelessWidget {
  final String sessionId;
  final String scope;

  const InventorySessionPage({
    super.key,
    required this.sessionId,
    required this.scope,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Contenu de l'Inventaire", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(scope, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        backgroundColor: Colors.amber.shade800,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<InventoryItem>>(
        stream: InventoryService().getSessionItems(sessionId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_scanner, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text("Aucun article scanné pour le moment."),
                  const SizedBox(height: 8),
                  const Text("Retournez scanner des produits.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final items = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildItemCard(context, item);
            },
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => _confirmFinish(context),
          icon: const Icon(Icons.check_circle_outline),
          label: const Text("VALIDER L'INVENTAIRE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, InventoryItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.amber.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.inventory_2, color: Colors.amber.shade800),
        ),
        title: Text(
          item.productName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Ref: ${item.productReference}"),
            Text(
              "Scanné à: ${DateFormat('HH:mm').format(item.scannedAt)}",
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                "${item.countedQuantity}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton(
              onSelected: (value) {
                if (value == 'edit') _editItem(context, item);
                if (value == 'delete') _deleteItem(context, item);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text("Modifier")])),
                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text("Supprimer", style: TextStyle(color: Colors.red))])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _editItem(BuildContext context, InventoryItem item) {
    final controller = TextEditingController(text: item.countedQuantity.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Modifier: ${item.productName}"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: "Nouvelle quantité", border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null) {
                InventoryService().updateItemCount(sessionId, item.productId, val);
              }
              Navigator.pop(ctx);
            },
            child: const Text("Enregistrer"),
          )
        ],
      ),
    );
  }

  void _deleteItem(BuildContext context, InventoryItem item) {
    InventoryService().deleteItem(sessionId, item.productId);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${item.productName} supprimé.")));
  }

  Future<void> _confirmFinish(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Terminer la session ?"),
        content: const Text("Vous ne pourrez plus modifier ces scans une fois envoyés au Responsable."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Retour")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Envoyer Rapport"),
          )
        ],
      ),
    );

    if (confirm == true) {
      await InventoryService().finishSession(sessionId);
      if (context.mounted) {
        Navigator.pop(context); // Close this page
      }
    }
  }
}