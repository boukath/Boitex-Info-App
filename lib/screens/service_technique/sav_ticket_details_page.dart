// lib/screens/service_technique/sav_ticket_details_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/models/sav_ticket.dart';
import 'package:boitex_info_app/services/activity_logger.dart';
import 'package:intl/intl.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:boitex_info_app/screens/service_technique/finalize_sav_return_page.dart';
import 'dart:typed_data'; // ✅ ADDED for Uint8List
import 'package:video_thumbnail/video_thumbnail.dart'; // ✅ ADDED for video thumbnails
import 'package:boitex_info_app/widgets/image_gallery_page.dart'; // ✅ ADDED image viewer
import 'package:boitex_info_app/widgets/video_player_page.dart'; // ✅ ADDED video viewer

class SavTicketDetailsPage extends StatefulWidget {
  final SavTicket ticket;
  const SavTicketDetailsPage({super.key, required this.ticket});

  @override
  State<SavTicketDetailsPage> createState() => _SavTicketDetailsPageState();
}

class _SavTicketDetailsPageState extends State<SavTicketDetailsPage> {
  late SavTicket _currentTicket;
  late final TextEditingController _reportController;
  bool _isUpdating = false;
  Map<String, int> _stockStatus = {};

  final List<String> _statusOptions = [
    'Nouveau',
    'En Diagnostic',
    'En Réparation',
    'Terminé',
    'Irréparable - Remplacement Demandé',
    'Approuvé - Prêt pour retour', // Added missing status if needed
    'Retourné', // Added missing status if needed
  ];

  @override
  void initState() {
    super.initState();
    _currentTicket = widget.ticket;
    _reportController =
        TextEditingController(text: _currentTicket.technicianReport ?? '');

    // Listen for real-time updates to the ticket
    FirebaseFirestore.instance
        .collection('sav_tickets')
        .doc(widget.ticket.id)
        .snapshots()
        .listen((doc) {
      if (doc.exists && mounted) {
        setState(() {
          _currentTicket = SavTicket.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>);
          // Update report controller only if text has actually changed
          if (_reportController.text != (_currentTicket.technicianReport ?? '')) {
            _reportController.text = _currentTicket.technicianReport ?? '';
          }
          // Re-check stock if broken parts change
          if (_currentTicket.brokenParts.isNotEmpty) {
            _checkStockForParts(_currentTicket.brokenParts);
          }
        });
      }
    });

    // Initial stock check
    if (_currentTicket.brokenParts.isNotEmpty) {
      _checkStockForParts(_currentTicket.brokenParts);
    }
  }

  @override
  void dispose() {
    _reportController.dispose();
    super.dispose();
  }

  // ✅ ADDED Helper function to check for video extensions
  bool _isVideoUrl(String url) {
    final lowercaseUrl = url.toLowerCase();
    // Add more video extensions if needed
    return lowercaseUrl.endsWith('.mp4') ||
        lowercaseUrl.endsWith('.mov') ||
        lowercaseUrl.endsWith('.avi') ||
        lowercaseUrl.endsWith('.mkv');
  }

  Future<void> _checkStockForParts(List<BrokenPart> parts) async {
    final tempStatus = <String, int>{};
    for (var part in parts) {
      try {
        final productDoc = await FirebaseFirestore.instance
            .collection('produits')
            .doc(part.productId)
            .get();

        if (productDoc.exists) {
          final data = productDoc.data();
          if (data != null && data.containsKey('stock')) {
            final stockValue = data['stock'] as num?;
            tempStatus[part.productId] = stockValue?.toInt() ?? 0;
          } else {
            tempStatus[part.productId] = 0;
          }
        } else {
          tempStatus[part.productId] = 0; // Product doesn't exist
        }
      } catch (e) {
        print('Error checking stock for ${part.productId}: $e');
        tempStatus[part.productId] = 0; // Error means we assume 0 stock
      }
    }
    if (mounted) {
      setState(() {
        _stockStatus = tempStatus;
      });
    }
  }


  Future<void> _updateTicket(String newStatus) async {
    setState(() => _isUpdating = true);
    try {
      await FirebaseFirestore.instance
          .collection('sav_tickets')
          .doc(_currentTicket.id)
          .update({
        'status': newStatus,
        'technicianReport': _reportController.text,
        'brokenParts':
        _currentTicket.brokenParts.map((p) => p.toJson()).toList(),
      });

      await ActivityLogger.logActivity(
        message:
        "Le statut du ticket SAV ${_currentTicket.savCode} a été mis à jour à '$newStatus'.",
        interventionId: _currentTicket.id,
        category: 'SAV',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ticket mis à jour avec succès.'),
              backgroundColor: Colors.green),
        );
        // No pop here, stay on the details page
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _showAddPartsDialog() async {
    final selectedProducts = await showDialog<List<DocumentSnapshot>>(
      context: context,
      builder: (context) => _AddPartsDialog(
          initialSelected:
          _currentTicket.brokenParts.map((p) => p.productId).toList()),
    );

    if (selectedProducts != null) {
      final newParts = selectedProducts.map((doc) {
        return BrokenPart(
          productId: doc.id,
          productName: doc['nom'] as String,
          status: 'À Remplacer', // Default status when adding
        );
      }).toList();

      // Update the local state first for immediate UI feedback
      setState(() {
        // Create a new SavTicket object with the updated parts.
        // Using a copyWith method in SavTicket would be cleaner.
        _currentTicket = SavTicket(
          id: _currentTicket.id,
          serviceType: _currentTicket.serviceType,
          savCode: _currentTicket.savCode,
          clientId: _currentTicket.clientId,
          clientName: _currentTicket.clientName,
          storeId: _currentTicket.storeId,
          storeName: _currentTicket.storeName,
          pickupDate: _currentTicket.pickupDate,
          pickupTechnicianIds: _currentTicket.pickupTechnicianIds,
          pickupTechnicianNames: _currentTicket.pickupTechnicianNames,
          productName: _currentTicket.productName,
          serialNumber: _currentTicket.serialNumber,
          problemDescription: _currentTicket.problemDescription,
          itemPhotoUrls: _currentTicket.itemPhotoUrls, // Keep existing media
          storeManagerName: _currentTicket.storeManagerName,
          storeManagerSignatureUrl: _currentTicket.storeManagerSignatureUrl,
          status: _currentTicket.status, // Keep current status
          technicianReport: _reportController.text, // Keep current report text
          createdBy: _currentTicket.createdBy,
          createdAt: _currentTicket.createdAt,
          brokenParts: newParts, // Use the NEW list of parts
          billingStatus: _currentTicket.billingStatus,
          invoiceUrl: _currentTicket.invoiceUrl,
          returnClientName: _currentTicket.returnClientName,
          returnSignatureUrl: _currentTicket.returnSignatureUrl,
          returnPhotoUrl: _currentTicket.returnPhotoUrl,
        );
      });
      // Check stock for the newly added parts
      _checkStockForParts(newParts);
      // Immediately save the updated parts list to Firestore
      _updateTicket(_currentTicket.status); // Save with current status
    }
  }

  // ✅ ADDED: Function to open the correct media viewer
  void _openMedia(String url) {
    if (_isVideoUrl(url)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => VideoPlayerPage(videoUrl: url),
        ),
      );
    } else {
      // Filter out video URLs to only show images in the gallery
      final List<String> imageLinks = _currentTicket.itemPhotoUrls
          .where((link) => !_isVideoUrl(link))
          .toList();
      if (imageLinks.isEmpty) return; // Should not happen if url is an image

      final int initialIndex = imageLinks.indexOf(url);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ImageGalleryPage(
            imageUrls: imageLinks,
            // Ensure index is valid, default to 0 if not found (shouldn't happen)
            initialIndex: (initialIndex != -1) ? initialIndex : 0,
          ),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTicket.savCode),
        backgroundColor: Colors.orange, // Match SAV theme
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 16),
            // ✅ ADDED call to the new media section widget
            if (_currentTicket.itemPhotoUrls.isNotEmpty) ...[
              _buildMediaSection(),
              const SizedBox(height: 16),
            ],
            _buildTechnicianSection(),
            const SizedBox(height: 24),
            // Conditional button for finalizing return
            if (_currentTicket.status == 'Approuvé - Prêt pour retour')
              Center(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.inventory_outlined),
                    label: const Text('Finaliser le Retour'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              FinalizeSavReturnPage(ticket: _currentTicket),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4, // Added subtle elevation
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Informations sur le Ticket',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.orange)),
            const Divider(height: 20),
            _buildInfoRow('Client:', _currentTicket.clientName),
            _buildInfoRow('Magasin:', _currentTicket.storeName ?? 'N/A'),
            _buildInfoRow('Produit:', _currentTicket.productName),
            _buildInfoRow('N° de Série:', _currentTicket.serialNumber),
            const SizedBox(height: 8),
            const Text('Description du Problème:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Padding( // Added padding for better readability
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(_currentTicket.problemDescription,
                  style: const TextStyle(height: 1.4)),
            ),
            const Divider(height: 20),
            _buildInfoRow('Statut Actuel:', _currentTicket.status,
                isStatus: true),
            if (_currentTicket.billingStatus != null)
              _buildInfoRow('Facturation:', _currentTicket.billingStatus!),
            _buildInfoRow(
                'Date de création:',
                DateFormat('dd MMM yyyy, HH:mm', 'fr_FR')
                    .format(_currentTicket.createdAt)),
          ],
        ),
      ),
    );
  }

  // ✅ ADDED: Widget to display media thumbnails
  Widget _buildMediaSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Photos/Vidéos de l\'Article',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.orange)),
            const Divider(height: 20),
            if (_currentTicket.itemPhotoUrls.isEmpty)
              const Text('Aucun fichier joint.', style: TextStyle(color: Colors.grey))
            else
              Wrap(
                spacing: 8.0, // Horizontal space between items
                runSpacing: 8.0, // Vertical space between lines
                children: _currentTicket.itemPhotoUrls
                    .map((url) => _buildMediaThumbnail(url))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  // ✅ ADDED: Widget to build a single thumbnail (image or video)
  Widget _buildMediaThumbnail(String url) {
    bool isVideo = _isVideoUrl(url);

    return GestureDetector(
      onTap: () => _openMedia(url),
      child: Container(
        width: 80, // Smaller thumbnail size
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
          color: Colors.grey.shade200, // Placeholder color
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: isVideo
              ? FutureBuilder<Uint8List?>(
            future: VideoThumbnail.thumbnailData(
              video: url,
              imageFormat: ImageFormat.JPEG,
              maxWidth: 80, // Match container size
              quality: 25, // Lower quality for list thumbnail
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              }
              if (snapshot.hasData && snapshot.data != null) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(snapshot.data!, fit: BoxFit.cover),
                    const Center(
                      child: Icon(Icons.play_circle_fill,
                          color: Colors.white70, size: 30),
                    ),
                  ],
                );
              }
              // Fallback for failed thumbnail generation
              return const Center(child: Icon(Icons.videocam, color: Colors.black54));
            },
          )
              : Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) =>
            progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, color: Colors.grey),
          ),
        ),
      ),
    );
  }


  Widget _buildTechnicianSection() {
    bool isReadOnly = _currentTicket.status == 'Terminé' ||
        _currentTicket.status == 'Approuvé - Prêt pour retour' ||
        _currentTicket.status == 'Retourné';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Section Technicien',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.orange)),
            const Divider(height: 20),
            DropdownButtonFormField<String>(
              value: _statusOptions.contains(_currentTicket.status) ? _currentTicket.status : null,
              items: _statusOptions
                  .map((status) =>
                  DropdownMenuItem(value: status, child: Text(status)))
                  .toList(),
              onChanged: isReadOnly
                  ? null
                  : (value) {
                if (value != null && value != _currentTicket.status) {
                  _updateTicket(value); // Update status immediately on change
                }
              },
              decoration: const InputDecoration(
                labelText: 'Changer le statut',
                border: OutlineInputBorder(), // Added border
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _reportController,
              readOnly: isReadOnly,
              decoration: const InputDecoration(
                labelText: 'Rapport du technicien / Diagnostic',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            if (!isReadOnly)
              OutlinedButton.icon(
                onPressed: _showAddPartsDialog,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Ajouter/Modifier Pièces Défectueuses'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.orange), // Match theme
                  foregroundColor: Colors.orange,
                ),
              ),
            const SizedBox(height: 16),
            if (_currentTicket.brokenParts.isNotEmpty) ...[
              const Text('Pièces Défectueuses:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              // Use ListView.builder for potentially long lists
              ListView.builder(
                  shrinkWrap: true, // Important inside SingleChildScrollView
                  physics: const NeverScrollableScrollPhysics(), // Disable internal scrolling
                  itemCount: _currentTicket.brokenParts.length,
                  itemBuilder: (context, index){
                    final part = _currentTicket.brokenParts[index];
                    final stock = _stockStatus[part.productId];
                    final stockText = stock == null ? '...' : stock.toString();
                    final stockColor = stock == null ? Colors.grey : (stock > 0 ? Colors.green : Colors.red);
                    return ListTile(
                      contentPadding: EdgeInsets.zero, // Remove default padding
                      leading: Icon(Icons.build_circle_outlined, color: Colors.grey[600]), // Add an icon
                      title: Text(part.productName),
                      trailing: Text( 'Stock: $stockText',
                        style: TextStyle(color: stockColor, fontWeight: FontWeight.bold),
                      ),
                    );
                  }
              ),
            ],
            const SizedBox(height: 24),
            // "Save" button now only saves the report text, status is saved on change
            if (!isReadOnly)
              ElevatedButton.icon(
                onPressed: _isUpdating
                    ? null
                    : () => _updateTicket(_currentTicket.status), // Pass current status to save report
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange, // Match theme
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: _isUpdating ? Container() : const Icon(Icons.save_outlined),
                label: _isUpdating
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3,))
                    : const Text('Enregistrer Rapport'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isStatus = false}) {
    Color statusColor = Colors.black87; // Default color
    if (isStatus) {
      switch (value) {
        case 'Nouveau': statusColor = Colors.blue; break;
        case 'En Diagnostic':
        case 'En Réparation': statusColor = Colors.orange; break;
        case 'Terminé': statusColor = Colors.green; break;
        case 'Irréparable - Remplacement Demandé': statusColor = Colors.red; break;
        case 'Approuvé - Prêt pour retour': statusColor = Colors.purple; break;
        case 'Retourné': statusColor = Colors.grey; break;
        default: statusColor = Colors.black87;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          Expanded(
              child: Text(value,
                style: TextStyle(
                    color: statusColor, // Use dynamic color
                    fontWeight: isStatus ? FontWeight.bold : FontWeight.normal),
              )),
        ],
      ),
    );
  }
}

// --- Add Parts Dialog --- (No changes needed below this line for media display)
class _AddPartsDialog extends StatefulWidget {
  final List<String> initialSelected;
  const _AddPartsDialog({required this.initialSelected});

  @override
  _AddPartsDialogState createState() => _AddPartsDialogState();
}

class _AddPartsDialogState extends State<_AddPartsDialog> {
  List<DocumentSnapshot> _allProducts = [];
  List<DocumentSnapshot> _productsForCategory = [];
  String? _selectedCategory;
  bool _isLoadingProducts = true;
  late List<DocumentSnapshot> _selectedParts;

  @override
  void initState() {
    super.initState();
    _selectedParts = [];
    _fetchAllProducts();
  }

  Future<void> _fetchAllProducts() async {
    setState(() => _isLoadingProducts = true); // Start loading
    try {
      final snapshot =
      await FirebaseFirestore.instance.collection('produits')
          .orderBy('categorie').orderBy('nom') // Order for consistency
          .get();
      if (mounted) {
        setState(() {
          _allProducts = snapshot.docs;
          // Pre-select parts based on initialSelected list
          _selectedParts
              .addAll(_allProducts.where((p) => widget.initialSelected.contains(p.id)));
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur chargement produits: ${e.toString()}'))
        );
      }
    }
  }

  void _filterProductsByCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _productsForCategory =
          _allProducts.where((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            return data?['categorie'] == category;
          }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Extract unique categories efficiently
    final categories =
    _allProducts.map((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      return data?['categorie'] as String?;
    }).where((c) => c != null).toSet().toList()..sort(); // Sort categories alphabetically


    return AlertDialog(
      title: const Text('Ajouter/Modifier Pièces'),
      content: SizedBox(
        width: double.maxFinite, // Use available width
        height: MediaQuery.of(context).size.height * 0.6, // Set a max height
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              hint: const Text('Sélectionner une catégorie'),
              isExpanded: true, // Allow dropdown to expand
              onChanged: (value) {
                if (value != null) _filterProductsByCategory(value);
              },
              items: categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c!)))
                  .toList(),
              decoration: const InputDecoration(border: OutlineInputBorder()), // Add border
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoadingProducts
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedCategory == null
                  ? const Center(child: Text('Sélectionnez une catégorie pour voir les produits.'))
                  : _productsForCategory.isEmpty
                  ? const Center(child: Text('Aucun produit trouvé dans cette catégorie.'))
                  : ListView.builder(
                itemCount: _productsForCategory.length,
                itemBuilder: (context, index) {
                  final product = _productsForCategory[index];
                  final productName = (product.data() as Map<String, dynamic>?)?['nom'] ?? 'Nom Inconnu';
                  final isSelected =
                  _selectedParts.any((p) => p.id == product.id);
                  return CheckboxListTile(
                    title: Text(productName),
                    value: isSelected,
                    onChanged: (bool? selected) {
                      setState(() {
                        if (selected == true) {
                          // Add only if not already present (safety check)
                          if (!_selectedParts.any((p) => p.id == product.id)) {
                            _selectedParts.add(product);
                          }
                        } else {
                          _selectedParts.removeWhere(
                                  (p) => p.id == product.id);
                        }
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading, // Checkbox on left
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            child: const Text('ANNULER'),
            onPressed: () => Navigator.of(context).pop()), // Pop without value
        ElevatedButton(
            child: const Text('CONFIRMER'),
            onPressed: () => Navigator.of(context).pop(_selectedParts)), // Pop WITH value
      ],
    );
  }
}