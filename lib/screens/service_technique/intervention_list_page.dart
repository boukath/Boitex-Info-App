// lib/screens/service_technique/intervention_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:boitex_info_app/screens/service_technique/add_intervention_page.dart';
import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';
import 'package:boitex_info_app/screens/service_technique/intervention_history_clients_page.dart';
import 'package:boitex_info_app/screens/administration/store_equipment_page.dart'; // ✅ Added Store Equipment Page Import
import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:timeago/timeago.dart' as timeago;

class InterventionListPage extends StatefulWidget {
  final String userRole;
  final String serviceType;
  const InterventionListPage({
    super.key,
    required this.userRole,
    required this.serviceType,
  });

  @override
  State<InterventionListPage> createState() => _InterventionListPageState();
}

class _InterventionListPageState extends State<InterventionListPage> {
  bool _canDelete = false;
  bool _canPrioritize = false;

  @override
  void initState() {
    super.initState();
    _checkUserPermissions();
  }

  Future<void> _checkUserPermissions() async {
    final canDelete = await RolePermissions.canCurrentUserDeleteIntervention();
    // Assuming managers/admins can prioritize. Adjust based on your role logic.
    final canPrioritize = widget.userRole.contains('Admin') ||
        widget.userRole.contains('Responsable') ||
        widget.userRole.contains('PDG');

    if (mounted) {
      setState(() {
        _canDelete = canDelete;
        _canPrioritize = canPrioritize;
      });
    }
  }

  // --- ⚡️ FLASH INFO DIALOG ---
  Future<void> _showQuickUpdateDialog(String docId, String? currentNote) async {
    final TextEditingController noteController = TextEditingController(text: currentNote);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.flash_on, color: Colors.amber),
            SizedBox(width: 8),
            Text("Flash Info"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Ajoutez une note rapide pour expliquer la situation actuelle (ex: Client en vacances, Pièce commandée...)",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              autofocus: true,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: "La situation actuelle...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.send, size: 16),
            label: const Text("Publier le statut"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (noteController.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('interventions')
                    .doc(docId)
                    .update({
                  'lastFollowUpNote': noteController.text.trim(),
                  'lastFollowUpDate': FieldValue.serverTimestamp(),
                });
                if (mounted) Navigator.pop(context);
              }
            },
          )
        ],
      ),
    );
  }

  // --- 📌 PIN LOGIC ---
  Future<void> _togglePin(String docId, bool currentPinStatus) async {
    await FirebaseFirestore.instance.collection('interventions').doc(docId).update({
      'isPinned': !currentPinStatus,
      // When pinned, give it a timestamp so newly pinned items go to the top of the pin list
      if (!currentPinStatus) 'pinnedAt': FieldValue.serverTimestamp(),
    });
  }

  // --- 🚨 PRIORITY LOGIC ---
  Future<void> _updatePriority(String docId, int newPriorityLevel) async {
    await FirebaseFirestore.instance.collection('interventions').doc(docId).update({
      'priorityLevel': newPriorityLevel,
    });
  }

  // --- 🖐️ DRAG & DROP LOGIC (For Pinned Items) ---
  Future<void> _onReorderPinned(int oldIndex, int newIndex, List<QueryDocumentSnapshot> pinnedDocs) async {
    if (newIndex > oldIndex) newIndex -= 1;

    final item = pinnedDocs.removeAt(oldIndex);
    pinnedDocs.insert(newIndex, item);

    final batch = FirebaseFirestore.instance.batch();

    // Update the custom sort index for the pinned items
    for (int i = 0; i < pinnedDocs.length; i++) {
      batch.update(pinnedDocs[i].reference, {'pinSortIndex': i});
    }

    await batch.commit();
  }

  Future<void> _deleteIntervention(String interventionId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: Text(
              'Êtes-vous sûr de vouloir supprimer définitivement l\'intervention pour "$title"? Cette action est irréversible.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('interventions').doc(interventionId).delete();
    }
  }

  // 🎨 THE DESIGN BRAIN: Get Styles based on Type
  Map<String, dynamic> _getInterventionStyle(String? type, String? billingStatus) {
    if (type == 'Facturable' || type == 'Intervention Facturable' || billingStatus == 'FACTURABLE') {
      return {
        'color': Colors.amber.shade700,
        'bg': Colors.amber.shade50,
        'icon': Icons.monetization_on_outlined,
        'label': 'FACTURABLE',
      };
    }
    if (type == 'Corrective' || type == 'Maintenance Corrective') {
      return {
        'color': const Color(0xFFFF5722),
        'bg': const Color(0xFFFBE9E7),
        'icon': Icons.build_circle_outlined,
        'label': 'CORRECTIF',
      };
    }
    if (type == 'Garantie' || type == 'Sous Garantie' || billingStatus == 'GRATUIT') {
      return {
        'color': const Color(0xFF00C853),
        'bg': const Color(0xFFE8F5E9),
        'icon': Icons.verified_user_outlined,
        'label': 'GARANTIE',
      };
    }
    if (type == 'Preventive' || type == 'Maintenance Préventive') {
      return {
        'color': const Color(0xFF3F51B5),
        'bg': const Color(0xFFE8EAF6),
        'icon': Icons.calendar_month_outlined,
        'label': 'PRÉVENTIF',
      };
    }
    return {
      'color': Colors.blueGrey,
      'bg': Colors.grey.shade50,
      'icon': Icons.work_outline,
      'label': 'INTERVENTION',
    };
  }

  // Helper for Status Badge Color
  Color _getStatusColor(String? status) {
    switch (status) {
      case 'En cours': return Colors.orange.shade700;
      case 'Nouveau':
      case 'Nouvelle Demande': return Colors.blue.shade700;
      case 'Terminé': return Colors.green.shade700;
      case 'En attente': return Colors.purple.shade700;
      default: return Colors.grey;
    }
  }

  // Helper for Priority UI
  Widget _buildPriorityBadge(int priorityLevel) {
    Color pColor;
    String pLabel;
    IconData pIcon;

    switch(priorityLevel) {
      case 3: pColor = Colors.red; pLabel = "URGENTE"; pIcon = Icons.warning_rounded; break;
      case 2: pColor = Colors.orange; pLabel = "HAUTE"; pIcon = Icons.priority_high; break;
      case 1: pColor = Colors.blue; pLabel = "NORMALE"; pIcon = Icons.remove; break;
      default: pColor = Colors.grey; pLabel = "BASSE"; pIcon = Icons.arrow_downward; break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: pColor.withOpacity(0.1),
        border: Border.all(color: pColor.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(pIcon, size: 10, color: pColor),
          const SizedBox(width: 4),
          Text(pLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: pColor)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final serviceType = widget.serviceType;
    final userRole = widget.userRole;

    // 🚀 BASE QUERY (No priority sorting here so old documents aren't hidden!)
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('interventions')
        .where('serviceType', isEqualTo: serviceType)
        .where('status', whereIn: ['Nouvelle Demande', 'Nouveau', 'En cours', 'En attente'])
        .orderBy('createdAt', descending: true); // ✅ ONLY keep createdAt

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Interventions',
          style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.black87),
            tooltip: "Historique Clients",
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => InterventionHistoryClientsPage(
                    serviceType: serviceType,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Erreur: Index requis ? Vérifiez la console.'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('Tout est calme', style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          final allDocs = snapshot.data!.docs;

          // 🚀 HYBRID SPLIT: Separate Pinned from Unpinned
          List<QueryDocumentSnapshot<Map<String, dynamic>>> pinnedDocs = [];
          List<QueryDocumentSnapshot<Map<String, dynamic>>> unpinnedDocs = [];

          for (var doc in allDocs) {
            if (doc.data()['isPinned'] == true) {
              pinnedDocs.add(doc);
            } else {
              unpinnedDocs.add(doc);
            }
          }

          // Sort pinned docs by their custom Drag & Drop index
          pinnedDocs.sort((a, b) => (a.data()['pinSortIndex'] ?? 999).compareTo(b.data()['pinSortIndex'] ?? 999));

          // 🚀 FIX: Sort unpinned docs locally by Priority! (Treats missing fields as "Normal")
          unpinnedDocs.sort((a, b) {
            final int priorityA = a.data()['priorityLevel'] ?? 1; // Default to 1 (Normal) if old
            final int priorityB = b.data()['priorityLevel'] ?? 1; // Default to 1 (Normal) if old

            // 1. Sort by Priority Level (Urgente 3 -> Basse 0)
            if (priorityA != priorityB) {
              return priorityB.compareTo(priorityA);
            }

            // 2. If priorities are the same, sort by Newest First
            final timeA = a.data()['createdAt'] as Timestamp?;
            final timeB = b.data()['createdAt'] as Timestamp?;
            if (timeA != null && timeB != null) {
              return timeB.compareTo(timeA);
            }
            return 0;
          });

          return CustomScrollView(
            slivers: [
              // --- 📌 PINNED SECTION (DRAG & DROP) ---
              if (pinnedDocs.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        const Icon(Icons.push_pin, color: Colors.redAccent, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          "Épinglées",
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverReorderableList(
                  itemCount: pinnedDocs.length,
                  onReorder: (oldIndex, newIndex) => _onReorderPinned(oldIndex, newIndex, pinnedDocs),
                  itemBuilder: (context, index) {
                    return Container(
                      key: ValueKey(pinnedDocs[index].id),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: _buildInterventionCard(pinnedDocs[index]),
                    );
                  },
                ),
                SliverToBoxAdapter(child: Divider(color: Colors.grey.shade300, thickness: 1, indent: 16, endIndent: 16, height: 32)),
              ],

              // --- 📁 UNPINNED SECTION ---
              if (unpinnedDocs.isNotEmpty) ...[
                SliverPadding(
                  // ✅ FIX: Removed 'const' to allow dynamic evaluation
                  padding: EdgeInsets.fromLTRB(16, pinnedDocs.isEmpty ? 16.0 : 0.0, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      "Toutes les interventions",
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: _buildInterventionCard(unpinnedDocs[index]),
                      );
                    },
                    childCount: unpinnedDocs.length,
                  ),
                ),
              ],

              const SliverPadding(padding: EdgeInsets.only(bottom: 80)), // Space for FAB
            ],
          );
        },
      ),
      floatingActionButton: RolePermissions.canAddIntervention(userRole)
          ? FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => AddInterventionPage(serviceType: serviceType))),
        label: const Text("Nouvelle"),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFF667EEA),
      )
          : null,
    );
  }

  // --- 🧱 CARD BUILDER ---
  Widget _buildInterventionCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final String docId = doc.id;

    // Data Extraction
    final String storeName = data['storeName'] ?? 'Magasin Inconnu';
    final String clientName = data['clientName'] ?? 'Client Inconnu';
    final String interventionCode = data['interventionCode'] ?? 'INT-XX';
    final String status = data['status'] ?? 'Inconnu';
    final DateTime? createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final String timeAgoDate = createdAt != null ? timeago.format(createdAt, locale: 'fr') : 'N/A';

    final String? clientId = data['clientId'];
    final String? storeId = data['storeId'];
    final DateTime? scheduledAt = (data['scheduledAt'] as Timestamp?)?.toDate();

    final String? type = data['interventionType'];
    final String? billingStatus = data['billingStatus'];
    final bool isPinned = data['isPinned'] ?? false;
    final int priorityLevel = data['priorityLevel'] ?? 1; // Default normal

    final style = _getInterventionStyle(type, billingStatus);
    final Color themeColor = style['color'];
    final Color themeBg = style['bg'];
    final IconData themeIcon = style['icon'];

    final String? flashNote = data['lastFollowUpNote'];
    final DateTime? flashDate = (data['lastFollowUpDate'] as Timestamp?)?.toDate();
    final bool hasFlash = flashNote != null && flashNote.isNotEmpty;

    // The core visual card
    Widget card = Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isPinned ? Border.all(color: Colors.redAccent.withOpacity(0.5), width: 1.5) : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onLongPress: () => _showQuickUpdateDialog(docId, flashNote),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => InterventionDetailsPage(interventionDoc: doc),
              ),
            );
          },
          child: Stack(
            children: [
              Positioned(
                bottom: -20,
                right: -20,
                child: Icon(themeIcon, size: 140, color: themeColor.withOpacity(0.15)),
              ),
              if (isPinned)
                const Positioned(
                  top: 12,
                  right: 12,
                  child: Icon(Icons.push_pin, color: Colors.redAccent, size: 16),
                ),

              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 6, decoration: BoxDecoration(color: themeColor)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: themeBg,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: themeColor.withOpacity(0.2)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(themeIcon, size: 14, color: themeColor),
                                          const SizedBox(width: 6),
                                          Text(
                                            style['label'],
                                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: themeColor),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // 🚨 Priority Badge Option
                                    if (priorityLevel != 1) _buildPriorityBadge(priorityLevel),
                                  ],
                                ),
                                if (!isPinned) // Hide chip if pinned icon takes space
                                  Chip(
                                    label: Text(status, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                    backgroundColor: _getStatusColor(status),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    side: BorderSide.none,
                                  ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // ✅ Wrapped the Store Row with a GestureDetector for navigation
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                if (clientId != null && storeId != null && clientId.isNotEmpty && storeId.isNotEmpty) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StoreEquipmentPage(
                                        clientId: clientId,
                                        storeId: storeId,
                                        storeName: storeName,
                                      ),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Les informations du magasin sont incomplètes."),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                              },
                              child: Row(
                                children: [
                                  StoreLogoFetcher(
                                    clientId: clientId,
                                    storeId: storeId,
                                    fallback: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(color: themeBg, shape: BoxShape.circle),
                                      child: Icon(Icons.store_mall_directory_rounded, size: 20, color: themeColor),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          storeName,
                                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "$clientName • $interventionCode",
                                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            if (scheduledAt != null) ...[
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.blue.shade100),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.calendar_today_rounded, size: 14, color: Colors.blue.shade700),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Prévu le : ${DateFormat('dd/MM/yyyy à HH:mm').format(scheduledAt)}",
                                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade900),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            if (hasFlash)
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border(left: BorderSide(color: Colors.blueGrey.shade400, width: 3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.flash_on, size: 14, color: Colors.amber),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            flashNote,
                                            style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.black87),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (flashDate != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          "MàJ ${timeago.format(flashDate, locale: 'fr')}",
                                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                        ),
                                      ),
                                  ],
                                ),
                              )
                            else
                              Row(
                                children: [
                                  Icon(Icons.access_time_rounded, size: 14, color: Colors.grey.shade400),
                                  const SizedBox(width: 6),
                                  Text(
                                    timeAgoDate,
                                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Actions Column
                    if (_canDelete || _canPrioritize)
                      Column(
                        children: [
                          if (_canPrioritize)
                            PopupMenuButton<int>(
                              icon: const Icon(Icons.more_vert, color: Colors.grey),
                              onSelected: (val) {
                                if (val == 99) {
                                  _deleteIntervention(docId, storeName);
                                } else {
                                  _updatePriority(docId, val);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 3, child: Text("🚨 Urgence (Priorité max)")),
                                const PopupMenuItem(value: 2, child: Text("⬆️ Haute priorité")),
                                const PopupMenuItem(value: 1, child: Text("➖ Priorité normale")),
                                const PopupMenuItem(value: 0, child: Text("⬇️ Basse priorité")),
                                if (_canDelete) const PopupMenuDivider(),
                                if (_canDelete) const PopupMenuItem(value: 99, child: Text("🗑️ Supprimer", style: TextStyle(color: Colors.red))),
                              ],
                            )
                          else if (_canDelete)
                            IconButton(
                              icon: const Icon(Icons.more_vert, color: Colors.grey),
                              onPressed: () => _deleteIntervention(docId, storeName),
                            ),

                          // DRAG HANDLE for pinned items
                          if (isPinned)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 16.0),
                              child: Icon(Icons.drag_indicator, color: Colors.grey),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // If the user has permission, wrap it in a Swipe-To-Pin wrapper
    if (_canPrioritize) {
      return Dismissible(
        key: Key('swipe_$docId'),
        direction: DismissDirection.startToEnd,
        confirmDismiss: (direction) async {
          _togglePin(docId, isPinned);
          return false; // Prevent actual dismissal from screen
        },
        background: Container(
          decoration: BoxDecoration(
            color: isPinned ? Colors.grey : Colors.redAccent,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          child: Row(
            children: [
              Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin, color: Colors.white),
              const SizedBox(width: 8),
              Text(isPinned ? "Désépingler" : "Épingler en haut", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        child: card,
      );
    }

    return card;
  }
}

// -----------------------------------------------------------------------------
// LOGO FETCHER WIDGET
// -----------------------------------------------------------------------------
class StoreLogoFetcher extends StatelessWidget {
  final String? clientId;
  final String? storeId;
  final Widget fallback;

  const StoreLogoFetcher({
    super.key,
    required this.clientId,
    required this.storeId,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (clientId == null || storeId == null || clientId!.isEmpty || storeId!.isEmpty) {
      return fallback;
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('clients')
          .doc(clientId)
          .collection('stores')
          .doc(storeId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final String? logoUrl = data?['logoUrl'];

          if (logoUrl != null && logoUrl.isNotEmpty) {
            return CachedNetworkImage(
              imageUrl: logoUrl,
              imageBuilder: (context, imageProvider) => Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade200),
                  image: DecorationImage(
                    image: imageProvider,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              placeholder: (context, url) => _buildPlaceholder(),
              errorWidget: (context, url, error) => fallback,
            );
          }
        }
        return fallback;
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: SizedBox(
          width: 15,
          height: 15,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}