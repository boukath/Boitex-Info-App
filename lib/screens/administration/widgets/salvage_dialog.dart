// lib/screens/administration/widgets/salvage_dialog.dart

import 'package:flutter/material.dart';
import 'package:boitex_info_app/models/quarantine_item.dart';
import 'package:boitex_info_app/services/stock_service.dart';
import 'package:boitex_info_app/screens/administration/global_product_search_page.dart';

class SalvageDialog extends StatefulWidget {
  final QuarantineItem item;

  const SalvageDialog({super.key, required this.item});

  @override
  State<SalvageDialog> createState() => _SalvageDialogState();
}

class _SalvageDialogState extends State<SalvageDialog> {
  // List of parts we are recovering
  final List<Map<String, dynamic>> _recoveredParts = [];
  final TextEditingController _noteController = TextEditingController();
  bool _isLoading = false;

  // ➕ Add a part to the list
  void _addPart() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GlobalProductSearchPage(
          isSelectionMode: true,
          onProductSelected: (productMap) {
            // Check if already added
            final existingIndex = _recoveredParts.indexWhere((p) => p['productId'] == productMap['productId']);

            setState(() {
              if (existingIndex >= 0) {
                // Increment if already there
                _recoveredParts[existingIndex]['quantity'] += productMap['quantity'];
              } else {
                // Add new
                _recoveredParts.add(productMap);
              }
            });
            Navigator.pop(context); // Close search
          },
        ),
      ),
    );
  }

  // 🗑️ Remove a part
  void _removePart(int index) {
    setState(() {
      _recoveredParts.removeAt(index);
    });
  }

  // 💾 Save to Database
  Future<void> _submitSalvage() async {
    if (_recoveredParts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ajoutez au moins une pièce récupérée (ou annulez)."))
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await StockService().processSalvage(
        item: widget.item,
        recoveredParts: _recoveredParts,
        note: _noteController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context, true); // Return TRUE to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ Récupération effectuée avec succès"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        children: [
          const Icon(Icons.build_circle, color: Colors.orange, size: 40),
          const SizedBox(height: 8),
          const Text("Récupération / Salvage", style: TextStyle(fontWeight: FontWeight.bold)),
          Text(
            "Article HS: ${widget.item.productName}",
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  "Pièces détachées récupérées :",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)
              ),
              const SizedBox(height: 10),

              // --- LIST OF PARTS ---
              if (_recoveredParts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200)
                  ),
                  child: const Center(
                    child: Text("Aucune pièce ajoutée.\nCliquez sur '+' pour ajouter.", textAlign: TextAlign.center),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recoveredParts.length,
                  itemBuilder: (ctx, index) {
                    final part = _recoveredParts[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      color: Colors.grey.shade100,
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          radius: 12,
                          child: Text("${part['quantity']}"),
                        ),
                        title: Text(part['productName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Ref: ${part['partNumber'] ?? 'N/A'}"),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                          onPressed: () => _removePart(index),
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 10),

              // --- ADD BUTTON ---
              Center(
                child: OutlinedButton.icon(
                  onPressed: _addPart,
                  icon: const Icon(Icons.add),
                  label: const Text("Ajouter une pièce"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.indigo,
                  ),
                ),
              ),

              const Divider(height: 30),

              // --- NOTE ---
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: "Note / Observation (Optionnel)",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Annuler"),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitSalvage,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text("VALIDER & CLÔTURER"),
        ),
      ],
    );
  }
}