// lib/screens/service_technique/intervention_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart'; // ✅ Added for the Premium Font look
import 'package:intl/intl.dart';
import 'package:boitex_info_app/screens/service_technique/add_intervention_page.dart';
import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';
import 'package:boitex_info_app/screens/service_technique/intervention_history_clients_page.dart';
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

  @override
  void initState() {
    super.initState();
    _checkUserPermissions();
  }

  Future<void> _checkUserPermissions() async {
    final canDelete = await RolePermissions.canCurrentUserDeleteIntervention();
    if (mounted) {
      setState(() {
        _canDelete = canDelete;
      });
    }
  }

  // --- ⚡️ FLASH INFO DIALOG (Preserved) ---
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
    // 1. Facturable (Money)
    if (type == 'Facturable' || type == 'Intervention Facturable' || billingStatus == 'FACTURABLE') {
      return {
        'color': Colors.amber.shade700,
        'bg': Colors.amber.shade50,
        'icon': Icons.monetization_on_outlined, // 💲
        'label': 'FACTURABLE',
        'gradient': [Colors.amber.shade300, Colors.orange.shade400],
      };
    }
    // 2. Corrective (Urgent)
    if (type == 'Corrective' || type == 'Maintenance Corrective') {
      return {
        'color': const Color(0xFFFF5722), // Deep Orange
        'bg': const Color(0xFFFBE9E7),
        'icon': Icons.build_circle_outlined, // 🛠
        'label': 'CORRECTIF',
        'gradient': [Colors.deepOrange.shade300, Colors.red.shade400],
      };
    }
    // 3. Sous Garantie (Safe)
    if (type == 'Garantie' || type == 'Sous Garantie' || billingStatus == 'GRATUIT') {
      return {
        'color': const Color(0xFF00C853), // Emerald Green
        'bg': const Color(0xFFE8F5E9),
        'icon': Icons.verified_user_outlined, // 🛡
        'label': 'GARANTIE',
        'gradient': [Colors.green.shade300, Colors.teal.shade400],
      };
    }
    // 4. Preventive (Routine)
    if (type == 'Preventive' || type == 'Maintenance Préventive') {
      return {
        'color': const Color(0xFF3F51B5), // Indigo
        'bg': const Color(0xFFE8EAF6),
        'icon': Icons.calendar_month_outlined, // 📅
        'label': 'PRÉVENTIF',
        'gradient': [Colors.indigo.shade300, Colors.blue.shade400],
      };
    }

    // Default (Unknown)
    return {
      'color': Colors.blueGrey,
      'bg': Colors.grey.shade50,
      'icon': Icons.work_outline,
      'label': 'INTERVENTION',
      'gradient': [Colors.grey.shade400, Colors.blueGrey.shade400],
    };
  }

  // Helper for Status Badge Color (Top Right)
  Color _getStatusColor(String? status) {
    switch (status) {
      case 'En cours':
        return Colors.orange.shade700;
      case 'Nouveau':
      case 'Nouvelle Demande':
        return Colors.blue.shade700;
      case 'Terminé':
        return Colors.green.shade700;
      case 'En attente':
        return Colors.purple.shade700;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final serviceType = widget.serviceType;
    final userRole = widget.userRole;

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('interventions')
        .where('serviceType', isEqualTo: serviceType)
        .where('status', whereIn: ['Nouvelle Demande', 'Nouveau', 'En cours', 'En attente'])
        .orderBy('status', descending: true)
        .orderBy('createdAt', descending: true);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Modern Light Grey Bg
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
          if (snapshot.hasError) return Center(child: Text('Erreur: ${snapshot.error}'));
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

          final interventions = snapshot.data!.docs;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: interventions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final interventionDoc = interventions[index];
              final data = interventionDoc.data();
              final String docId = interventionDoc.id;

              // Data Extraction
              final String storeName = data['storeName'] ?? 'Magasin Inconnu';
              final String clientName = data['clientName'] ?? 'Client Inconnu';
              final String interventionCode = data['interventionCode'] ?? 'INT-XX';
              final String status = data['status'] ?? 'Inconnu';
              final DateTime? createdAt = (data['createdAt'] as Timestamp?)?.toDate();
              final String timeAgoDate = createdAt != null ? timeago.format(createdAt, locale: 'fr') : 'N/A';

              // 🔍 TYPE DETECTION
              final String? type = data['interventionType']; // Correct field
              final String? billingStatus = data['billingStatus'];

              // 🎨 GET THE VIBE
              final style = _getInterventionStyle(type, billingStatus);
              final Color themeColor = style['color'];
              final Color themeBg = style['bg'];
              final IconData themeIcon = style['icon'];

              // Flash Note Data
              final String? flashNote = data['lastFollowUpNote'];
              final DateTime? flashDate = (data['lastFollowUpDate'] as Timestamp?)?.toDate();
              final bool hasFlash = flashNote != null && flashNote.isNotEmpty;

              return Container(
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onLongPress: () => _showQuickUpdateDialog(docId, flashNote), // ⚡️ Quick Note
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => InterventionDetailsPage(interventionDoc: interventionDoc),
                        ),
                      );
                    },
                    child: Stack(
                      children: [
                        // ✨ WATERMARK ICON (Bottom Right)
                        Positioned(
                          bottom: -20,
                          right: -20,
                          child: Icon(
                            themeIcon,
                            size: 140,
                            color: themeColor.withOpacity(0.15), // Subtle watermark
                          ),
                        ),

                        // MAIN LAYOUT
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 🎨 LEFT ACCENT BAR
                              Container(
                                width: 6,
                                decoration: BoxDecoration(
                                  color: themeColor,
                                ),
                              ),

                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // --- HEADER ROW ---
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          // IDENTITY BADGE
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
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: themeColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // STATUS CHIP (Moved Here for Clarity)
                                          Chip(
                                            label: Text(
                                                status,
                                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                                            ),
                                            backgroundColor: _getStatusColor(status),
                                            padding: EdgeInsets.zero,
                                            visualDensity: VisualDensity.compact,
                                            side: BorderSide.none, // Clean look
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 8),

                                      // --- TITLES ---
                                      Text(
                                        storeName,
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black87,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "$clientName • $interventionCode", // Combined for cleaner look
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),

                                      const SizedBox(height: 16),

                                      // --- ⚡️ FLASH INFO or TIME ---
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
                                      // 🟢 FINAL CLEAN FOOTER (Date Only)
                                        Row(
                                          children: [
                                            Icon(Icons.access_time_rounded, size: 14, color: Colors.grey.shade400),
                                            const SizedBox(width: 6),
                                            Text(
                                              timeAgoDate, // Minimalist: "5 jours"
                                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ),

                              // DELETE OPTION (If allowed)
                              if (_canDelete)
                                Column(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                                      onPressed: () => _deleteIntervention(docId, storeName),
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
            },
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
}