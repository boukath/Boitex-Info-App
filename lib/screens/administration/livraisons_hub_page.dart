// lib/screens/administration/livraisons_hub_page.dart

import 'package:boitex_info_app/screens/administration/add_livraison_page.dart';
import 'package:boitex_info_app/screens/administration/livraison_details_page.dart';
import 'package:boitex_info_app/screens/administration/livraison_history_page.dart';
import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // ✅ Added for Typography
import 'package:intl/intl.dart';

class LivraisonsHubPage extends StatefulWidget {
  final String? serviceType;
  const LivraisonsHubPage({super.key, this.serviceType});

  @override
  State<LivraisonsHubPage> createState() => _LivraisonsHubPageState();
}

class _LivraisonsHubPageState extends State<LivraisonsHubPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _canEdit = false;
  bool _canDelete = false;

  // 🎨 THEME COLORS
  final Color _primaryBlue = const Color(0xFF2962FF);
  final Color _accentGreen = const Color(0xFF00E676);
  final Color _bgLight = const Color(0xFFF4F6F9);
  final Color _cardWhite = Colors.white;
  final Color _textDark = const Color(0xFF2D3436);

  @override
  void initState() {
    super.initState();
    // ✅ UPDATED: Increased length to 3 to support "Partiel" tab
    _tabController = TabController(length: 3, vsync: this);
    _checkUserPermissions();
  }

  Future<void> _checkUserPermissions() async {
    final canEdit = await RolePermissions.canCurrentUserEditLivraison();
    final canDelete = await RolePermissions.canCurrentUserDeleteLivraison();
    if (mounted) {
      setState(() {
        _canEdit = canEdit;
        _canDelete = canDelete;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _deleteLivraison(String livraisonId, String bonNumber) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Supprimer ?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Text(
              'Voulez-vous vraiment supprimer le BL $bonNumber ?',
              style: GoogleFonts.poppins()),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Annuler', style: GoogleFonts.poppins(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text('Supprimer', style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('livraisons').doc(livraisonId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Livraison supprimée.'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        debugPrint('Delete Error: $e');
      }
    }
  }

  Widget _buildLivraisonList(String statusFilter, IconData emptyIcon, String emptyText) {
    Query query = FirebaseFirestore.instance.collection('livraisons');

    if (widget.serviceType != null) {
      query = query.where('accessGroups', arrayContains: widget.serviceType);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query
          .where('status', isEqualTo: statusFilter)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: _primaryBlue));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur', style: GoogleFonts.poppins(color: Colors.red)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, spreadRadius: 5)],
                  ),
                  child: Icon(emptyIcon, size: 50, color: Colors.grey.shade400),
                ),
                const SizedBox(height: 16),
                Text(emptyText, style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade500)),
              ],
            ),
          );
        }

        final livraisons = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 100), // Bottom padding for FAB
          itemCount: livraisons.length,
          itemBuilder: (context, index) {
            return _buildModernCard(livraisons[index]);
          },
        );
      },
    );
  }

  Widget _buildModernCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final bonNumber = data['bonLivraisonCode'] ?? 'N/A';
    final clientName = data['clientName'] ?? 'Client inconnu';
    final status = data['status'] ?? 'À Préparer';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final formattedDate = createdAt != null ? DateFormat('dd MMM, HH:mm').format(createdAt) : 'Date inconnue';

    // Logic for Progress Bar
    final products = data['products'] as List? ?? [];
    int totalItems = 0;
    int pickedItems = 0;
    if (status == 'À Préparer') {
      for (var p in products) {
        totalItems += (p['quantity'] as int? ?? 0);
        pickedItems += (p['serialNumbers'] as List? ?? []).length;
        // Also handle bulk picked count if available
        if (p['isBulk'] == true) {
          pickedItems = (p['pickedQuantity'] as int? ?? 0); // Simplified for display
        }
      }
    }

    // ✅ UPDATED: Dynamic Colors for the 3 Statuses
    Color statusColor;
    IconData statusIcon;
    String footerText;

    if (status == 'À Préparer') {
      statusColor = Colors.orange;
      statusIcon = Icons.inventory_2;
      footerText = "EN PRÉPARATION";
    } else if (status == 'Livraison Partielle') {
      statusColor = Colors.amber.shade800; // Warning Color
      statusIcon = Icons.warning_amber_rounded;
      footerText = "LIVRAISON PARTIELLE - ACTION REQUISE";
    } else {
      statusColor = _primaryBlue;
      statusIcon = Icons.local_shipping;
      footerText = "EN COURS D'ACHEMINEMENT";
    }

    final bool isPrep = status == 'À Préparer';

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => LivraisonDetailsPage(livraisonId: doc.id)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: _cardWhite,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icon Box
                  Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 24),
                  ),
                  const SizedBox(width: 16),

                  // Main Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bonNumber,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          clientName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Date & Action
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formattedDate,
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400),
                      ),
                      const SizedBox(height: 8),
                      // Popup Menu for Edit/Delete
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.more_horiz, color: Colors.grey.shade400),
                          onSelected: (value) {
                            if (value == 'edit') {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => AddLivraisonPage(serviceType: widget.serviceType, livraisonId: doc.id)));
                            } else if (value == 'details') {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => LivraisonDetailsPage(livraisonId: doc.id)));
                            } else if (value == 'delete') {
                              _deleteLivraison(doc.id, bonNumber);
                            }
                          },
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                            const PopupMenuItem(value: 'details', child: Text('Voir Détails')),
                            if (_canEdit) const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                            if (_canDelete) const PopupMenuItem(value: 'delete', child: Text('Supprimer', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      )
                    ],
                  )
                ],
              ),
            ),

            // Progress Bar or Status Strip
            if (isPrep && totalItems > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Progression Picking", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                        Text("$pickedItems / $totalItems", style: GoogleFonts.poppins(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: totalItems > 0 ? pickedItems / totalItems : 0,
                        backgroundColor: Colors.grey.shade100,
                        color: statusColor,
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              )
            else if (!isPrep)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1), // Slightly colored background
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
                child: Center(
                  child: Text(
                    footerText,
                    style: GoogleFonts.poppins(fontSize: 10, letterSpacing: 1.5, color: statusColor, fontWeight: FontWeight.bold),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          widget.serviceType == null ? 'HUB LIVRAISONS' : 'HUB ${widget.serviceType?.toUpperCase()}',
          style: GoogleFonts.poppins(
            color: _textDark,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(color: _bgLight, borderRadius: BorderRadius.circular(12)),
            child: IconButton(
              icon: const Icon(Icons.history, color: Colors.black87),
              tooltip: 'Historique',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LivraisonHistoryPage(serviceType: widget.serviceType ?? 'Général'),
                  ),
                );
              },
            ),
          ),
        ],
        // ✅ FIXED: Increased height to 100 to fit taller Tabs (Icon + Text) without hiding AppBar buttons
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _bgLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: _primaryBlue,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: _primaryBlue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey.shade600,
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent, // Removes the underline
              padding: const EdgeInsets.all(4),
              tabs: const [
                Tab(
                  icon: Icon(Icons.inventory_2, size: 20),
                  text: "À PRÉPARER",
                ),
                Tab(
                  icon: Icon(Icons.local_shipping, size: 20),
                  text: "EN ROUTE",
                ),
                Tab(
                  icon: Icon(Icons.warning_amber_rounded, size: 20),
                  text: "PARTIEL",
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLivraisonList('À Préparer', Icons.assignment_turned_in_outlined, 'Tout est prêt ! Aucune commande en attente.'),
          _buildLivraisonList('En Cours de Livraison', Icons.local_shipping_outlined, 'Aucune livraison sur la route.'),
          _buildLivraisonList('Livraison Partielle', Icons.warning_amber_rounded, 'Aucune livraison partielle en cours.'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => AddLivraisonPage(serviceType: widget.serviceType)));
        },
        backgroundColor: _primaryBlue,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('NOUVELLE DEMANDE', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
      ),
    );
  }
}