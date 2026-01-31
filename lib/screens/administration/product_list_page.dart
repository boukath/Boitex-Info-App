import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/screens/administration/product_details_page.dart';

class ProductListPage extends StatefulWidget {
  final String category;
  final Color categoryColor;

  const ProductListPage({
    super.key,
    required this.category,
    required this.categoryColor,
  });

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  // ⚙️ FILTER STATE VARIABLES
  String _sortOption = 'az'; // Options: az, za, stock_asc, stock_desc, newest
  bool _hideOutOfStock = false;
  String? _selectedBrand;
  String? _selectedOrigin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.category),
            const Text(
              'Liste des produits',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        backgroundColor: widget.categoryColor,
        foregroundColor: Colors.white,
        actions: [
          // 🔍 FILTER BUTTON
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            tooltip: 'Filtrer et Trier',
            onPressed: () => _showFilterModal(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('produits')
            .where('categorie', isEqualTo: widget.category)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Aucun produit trouvé dans cette catégorie.'));
          }

          // ⚡ CORE LOGIC: PROCESS DATA CLIENT-SIDE
          List<QueryDocumentSnapshot> docs = snapshot.data!.docs;

          // 1. Extract Unique Values for Filters (Before filtering)
          // We do this here so the filter dropdowns are populated with real data
          final Set<String> availableBrands = {};
          final Set<String> availableOrigins = {};
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['marque'] != null && data['marque'].toString().isNotEmpty) {
              availableBrands.add(data['marque'].toString());
            }
            if (data['origine'] != null && data['origine'].toString().isNotEmpty) {
              availableOrigins.add(data['origine'].toString());
            }
          }

          // 2. Apply Filters
          List<QueryDocumentSnapshot> filteredDocs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final stock = data['quantiteEnStock'] is int ? data['quantiteEnStock'] as int : 0;
            final brand = data['marque'] as String?;
            final origin = data['origine'] as String?;

            // Filter: Hide Out of Stock
            if (_hideOutOfStock && stock <= 0) return false;

            // Filter: Brand
            if (_selectedBrand != null && brand != _selectedBrand) return false;

            // Filter: Origin
            if (_selectedOrigin != null && origin != _selectedOrigin) return false;

            return true;
          }).toList();

          // 3. Apply Sorting
          filteredDocs.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;

            switch (_sortOption) {
              case 'za':
                return (dataB['nom'] ?? '').toString().compareTo((dataA['nom'] ?? '').toString());
              case 'stock_asc': // Low stock first (Urgent)
                final stockA = dataA['quantiteEnStock'] ?? 0;
                final stockB = dataB['quantiteEnStock'] ?? 0;
                return stockA.compareTo(stockB);
              case 'stock_desc': // High stock first
                final stockA = dataA['quantiteEnStock'] ?? 0;
                final stockB = dataB['quantiteEnStock'] ?? 0;
                return stockB.compareTo(stockA);
              case 'newest': // Recently created
                final dateA = (dataA['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
                final dateB = (dataB['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
                return dateB.compareTo(dateA);
              case 'az':
              default:
                return (dataA['nom'] ?? '').toString().compareTo((dataB['nom'] ?? '').toString());
            }
          });

          if (filteredDocs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.filter_alt_off_rounded, size: 60, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun résultat avec ces filtres',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  TextButton(
                    onPressed: _resetFilters,
                    child: const Text('Réinitialiser'),
                  ),
                ],
              ),
            );
          }

          // 4. Render List
          return Column(
            children: [
              // Small Filter Summary Bar
              if (_selectedBrand != null || _selectedOrigin != null || _hideOutOfStock)
                Container(
                  width: double.infinity,
                  color: Colors.grey.shade100,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      if (_hideOutOfStock) _buildFilterChip('En Stock', () => setState(() => _hideOutOfStock = false)),
                      if (_selectedBrand != null) _buildFilterChip('Marque: $_selectedBrand', () => setState(() => _selectedBrand = null)),
                      if (_selectedOrigin != null) _buildFilterChip('Origine: $_selectedOrigin', () => setState(() => _selectedOrigin = null)),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final productDoc = filteredDocs[index];
                    final productData = productDoc.data() as Map<String, dynamic>;
                    return _buildProductCard(context, productDoc, productData);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // 🏗️ CARD UI
  Widget _buildProductCard(BuildContext context, DocumentSnapshot doc, Map<String, dynamic> data) {
    // Extract Image
    final List<dynamic>? images = data['imageUrls'];
    final String? firstImageUrl = (images != null && images.isNotEmpty) ? images.first.toString() : null;
    final int stock = data['quantiteEnStock'] ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: SizedBox(
          width: 60,
          height: 60,
          child: firstImageUrl != null
              ? ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              firstImageUrl,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => _buildFallbackIcon(),
              loadingBuilder: (ctx, child, progress) => progress == null
                  ? child
                  : Center(child: CircularProgressIndicator(value: progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null)),
            ),
          )
              : _buildFallbackIcon(),
        ),
        title: Text(
          data['nom'] ?? 'Nom inconnu',
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Réf: ${data['reference'] ?? 'N/A'}'),
            Text('Marque: ${data['marque'] ?? 'N/A'} • ${data['origine'] ?? ''}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.circle,
              size: 12,
              color: stock > 0 ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 4),
            Text(
              '$stock',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ProductDetailsPage(productDoc: doc),
            ),
          );
        },
      ),
    );
  }

  // 🛠️ FILTER MODAL
  void _showFilterModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // Fetch values again for the modal options (or pass them if optimized)
        // For simplicity, we are building UI that modifies state directly
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Trier & Filtrer',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {
                          _resetFilters();
                          Navigator.pop(context);
                        },
                        child: const Text('Réinitialiser'),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      children: [
                        const Text('Ordre d\'affichage', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          children: [
                            _buildSortChip(setModalState, 'A - Z', 'az'),
                            _buildSortChip(setModalState, 'Z - A', 'za'),
                            _buildSortChip(setModalState, 'Stock Croissant', 'stock_asc'),
                            _buildSortChip(setModalState, 'Stock Décroissant', 'stock_desc'),
                            _buildSortChip(setModalState, 'Plus Récent', 'newest'),
                          ],
                        ),
                        const SizedBox(height: 24),

                        const Text('Options', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Masquer rupture de stock'),
                          value: _hideOutOfStock,
                          activeColor: widget.categoryColor,
                          onChanged: (val) {
                            setModalState(() => _hideOutOfStock = val);
                            setState(() {}); // Update main screen immediately
                          },
                        ),
                        const SizedBox(height: 10),

                        // Note: For Brand/Origin specific lists, implementing a dynamic fetch inside
                        // the modal usually requires passing the list from the parent or refetching.
                        // For a clean UI, we keep the quick sorting here.
                        // Advanced filtering (Brand/Origin) is best handled by tapping chips on the main screen
                        // if specific items are needed, OR you can add text fields here.
                        const Text('Filtre Textuel', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 10),
                        TextField(
                          decoration: InputDecoration(
                            labelText: 'Filtrer par Marque Exacte',
                            hintText: 'Ex: Hikvision',
                            prefixIcon: const Icon(Icons.business),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onChanged: (val) {
                            setState(() => _selectedBrand = val.isEmpty ? null : val);
                          },
                          controller: TextEditingController(text: _selectedBrand),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          decoration: InputDecoration(
                            labelText: 'Filtrer par Origine / Fournisseur',
                            hintText: 'Ex: France',
                            prefixIcon: const Icon(Icons.public),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onChanged: (val) {
                            setState(() => _selectedOrigin = val.isEmpty ? null : val);
                          },
                          controller: TextEditingController(text: _selectedOrigin),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.categoryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Appliquer', style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSortChip(StateSetter setModalState, String label, String value) {
    final isSelected = _sortOption == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: widget.categoryColor.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? widget.categoryColor : Colors.black,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (selected) {
          setModalState(() => _sortOption = value);
          setState(() {}); // Update main screen
        }
      },
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onDeleted) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: onDeleted,
      backgroundColor: Colors.white,
      shape: StadiumBorder(side: BorderSide(color: Colors.grey.shade300)),
    );
  }

  Widget _buildFallbackIcon() {
    return Container(
      decoration: BoxDecoration(
        color: widget.categoryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(Icons.inventory_2_outlined, color: widget.categoryColor),
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _sortOption = 'az';
      _hideOutOfStock = false;
      _selectedBrand = null;
      _selectedOrigin = null;
    });
  }
}