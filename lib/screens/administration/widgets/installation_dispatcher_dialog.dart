// lib/screens/administration/widgets/installation_dispatcher_dialog.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InstallationDispatcherDialog extends StatefulWidget {
  final List<dynamic> orderedProducts; // Passed from ProjectDetailsPage

  const InstallationDispatcherDialog({super.key, required this.orderedProducts});

  @override
  State<InstallationDispatcherDialog> createState() =>
      _InstallationDispatcherDialogState();
}

class _InstallationDispatcherDialogState
    extends State<InstallationDispatcherDialog> {
  bool _isLoading = true;

  // These lists will hold the state for the UI
  List<Map<String, dynamic>> _techProducts = [];
  List<Map<String, dynamic>> _itProducts = [];

  @override
  void initState() {
    super.initState();
    _fetchAndSortProducts();
  }

  /// 🧠 SMART SORTING LOGIC
  /// Fetches 'targetService' from Firestore to pre-fill the lists.
  Future<void> _fetchAndSortProducts() async {
    final List<Map<String, dynamic>> techList = [];
    final List<Map<String, dynamic>> itList = [];

    try {
      for (var item in widget.orderedProducts) {
        final productMap = Map<String, dynamic>.from(item as Map);
        final productId = productMap['productId'];
        final int totalQty = productMap['quantity'] ?? 0;

        // Default state: Not selected in either
        bool preSelectTech = false;
        bool preSelectIt = false;

        // 1. Fetch Product Metadata (Category/Service)
        if (productId != null) {
          final doc = await FirebaseFirestore.instance
              .collection('produits')
              .doc(productId)
              .get();

          if (doc.exists) {
            final data = doc.data();
            final String service = data?['targetService'] ?? 'Universel';

            if (service == 'Technique') {
              preSelectTech = true;
            } else if (service == 'IT') {
              preSelectIt = true;
            } else {
              // 'Universel' or others: Select in BOTH lists by default
              preSelectTech = true;
              preSelectIt = true;
            }
          } else {
            // Safety net: If product deleted, show in both to be safe
            preSelectTech = true;
            preSelectIt = true;
          }
        }

        // 2. Add to Technique List
        techList.add({
          ...productMap,
          'isSelected': preSelectTech,
          'dispatchQty': totalQty, // Default to full amount
          'maxQty': totalQty, // Reference for UI validation (optional)
        });

        // 3. Add to IT List
        itList.add({
          ...productMap,
          'isSelected': preSelectIt,
          'dispatchQty': totalQty, // Default to full amount
          'maxQty': totalQty,
        });
      }

      if (mounted) {
        setState(() {
          _techProducts = techList;
          _itProducts = itList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error dispatching products: $e');
      if (mounted) {
        // Fallback: Show everything everywhere
        // ✅ FIXED: Added explicit casting to resolve build error
        setState(() {
          _techProducts = widget.orderedProducts
              .map((e) => {
            ...Map<String, dynamic>.from(e as Map),
            'isSelected': true,
            'dispatchQty': e['quantity']
          })
              .toList();

          _itProducts = widget.orderedProducts
              .map((e) => {
            ...Map<String, dynamic>.from(e as Map),
            'isSelected': true,
            'dispatchQty': e['quantity']
          })
              .toList();
          _isLoading = false;
        });
      }
    }
  }

  void _confirmDispatch() {
    // 1. Filter Tech List
    final finalTechList = _techProducts
        .where((p) => p['isSelected'] == true && (p['dispatchQty'] as int) > 0)
        .map((p) => {
      'productId': p['productId'],
      'productName': p['productName'],
      'quantity': p['dispatchQty'], // Use the edited quantity
    })
        .toList();

    // 2. Filter IT List
    final finalItList = _itProducts
        .where((p) => p['isSelected'] == true && (p['dispatchQty'] as int) > 0)
        .map((p) => {
      'productId': p['productId'],
      'productName': p['productName'],
      'quantity': p['dispatchQty'], // Use the edited quantity
    })
        .toList();

    // 3. Return both lists
    Navigator.of(context).pop({
      'technique': finalTechList,
      'it': finalItList,
    });
  }

  @override
  Widget build(BuildContext context) {
    // Determine screen size for responsive layout
    final isWide = MediaQuery.of(context).size.width > 800;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: isWide ? 900 : double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              '📦 Dispatcher les Produits',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Vérifiez quels produits vont à quelle équipe.\nPour les consommables (Universel), vous pouvez ajuster les quantités.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const Divider(height: 30),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : isWide
                  ? Row(
                children: [
                  Expanded(child: _buildServiceColumn('Technique')),
                  const VerticalDivider(width: 30, thickness: 1),
                  Expanded(child: _buildServiceColumn('IT')),
                ],
              )
                  : PageView(
                children: [
                  _buildServiceColumn('Technique'),
                  _buildServiceColumn('IT'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!isWide)
              const Text(
                'Swipez ↔ pour changer de colonne',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _confirmDispatch,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Confirmer & Créer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceColumn(String type) {
    final bool isTech = type == 'Technique';
    final color = isTech ? Colors.deepPurple : Colors.blue;
    final icon = isTech ? Icons.handyman_outlined : Icons.computer_outlined;
    final productList = isTech ? _techProducts : _itProducts;

    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  'Installation $type',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: color),
                ),
                const Spacer(),
                Text('${productList.where((p) => p['isSelected']).length} items'),
              ],
            ),
          ),
          // List
          Expanded(
            child: ListView.separated(
              itemCount: productList.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = productList[index];
                final isSelected = item['isSelected'] as bool;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  color: isSelected ? Colors.white : Colors.transparent,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    leading: Checkbox(
                      activeColor: color,
                      value: isSelected,
                      onChanged: (val) {
                        setState(() {
                          productList[index]['isSelected'] = val;
                        });
                      },
                    ),
                    title: Text(
                      item['productName'],
                      style: TextStyle(
                        decoration:
                        isSelected ? null : TextDecoration.lineThrough,
                        color: isSelected ? Colors.black : Colors.grey,
                        fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? SizedBox(
                      width: 100,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 20),
                            onPressed: () {
                              if (item['dispatchQty'] > 1) {
                                setState(() {
                                  productList[index]['dispatchQty']--;
                                });
                              }
                            },
                            color: Colors.red,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          Expanded(
                            child: Text(
                              '${item['dispatchQty']}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 20),
                            onPressed: () {
                              // Optional: You could verify against 'maxQty' here if strict
                              setState(() {
                                productList[index]['dispatchQty']++;
                              });
                            },
                            color: Colors.green,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    )
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}