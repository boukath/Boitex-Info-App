// lib/screens/administration/portal_request_details_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; // For opening media/maps

class PortalRequestDetailsPage extends StatefulWidget {
  final String interventionId;

  const PortalRequestDetailsPage({super.key, required this.interventionId});

  @override
  State<PortalRequestDetailsPage> createState() => _PortalRequestDetailsPageState();
}

class _PortalRequestDetailsPageState extends State<PortalRequestDetailsPage> {
  // --- STATE ---
  bool _isProcessing = false;
  String _selectedServiceType = 'Service Technique'; // Default, but can be changed

  @override
  void initState() {
    super.initState();
    // We will initialize the service type from the doc in the FutureBuilder
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// --------------------------------------------------------------------------
  /// 1. APPROVAL LOGIC (THE TRANSACTION)
  /// --------------------------------------------------------------------------
  Future<void> _approveRequest(DocumentSnapshot doc) async {
    setState(() => _isProcessing = true);

    try {
      final currentYear = DateFormat('yyyy').format(DateTime.now());
      final counterRef = FirebaseFirestore.instance
          .collection('counters')
          .doc('intervention_counter_$currentYear');
      final interventionRef = doc.reference;

      // 🛑 TRANSACTION START
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final counterDoc = await transaction.get(counterRef);

        // A. Calculate New ID
        int newCount;
        if (counterDoc.exists) {
          final data = counterDoc.data() as Map<String, dynamic>;
          final lastResetYear = data['lastReset'] as String?;
          final currentCount = data['count'] as int? ?? 0;

          if (lastResetYear == currentYear) {
            newCount = currentCount + 1;
          } else {
            newCount = 1;
          }
        } else {
          newCount = 1;
        }

        final newInterventionCode = 'INT-$newCount/$currentYear';

        // C. Update Operations
        // 1. Increment Counter
        transaction.set(counterRef, {
          'count': newCount,
          'lastReset': currentYear,
        });

        // 2. Transform the Intervention
        // ✅ Status becomes "Nouvelle Demande" to enter the standard workflow
        transaction.update(interventionRef, {
          'interventionCode': newInterventionCode, // 🌟 THE OFFICIAL ID
          'status': 'Nouvelle Demande',
          'serviceType': _selectedServiceType,

          'approvedBy': 'Admin', // In real app, put current user ID
          'approvedAt': FieldValue.serverTimestamp(),
        });
      });
      // 🛑 TRANSACTION END

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Demande validée et transférée avec succès !"), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Go back to list
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la validation: $e"), backgroundColor: Colors.red),
      );
    }
  }

  /// --------------------------------------------------------------------------
  /// 2. REJECTION LOGIC
  /// --------------------------------------------------------------------------
  Future<void> _rejectRequest() async {
    // Show confirmation dialog first
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Refuser la demande ?"),
        content: const Text("Cette action est irréversible. La demande sera marquée comme 'Rejetée'."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text("REFUSER")
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);

    try {
      await FirebaseFirestore.instance
          .collection('interventions')
          .doc(widget.interventionId)
          .update({
        'status': 'Rejetée',
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
    }
  }

  /// --------------------------------------------------------------------------
  /// 3. UI BUILDER
  /// --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Détails de la Demande"),
        backgroundColor: const Color(0xFF667EEA),
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('interventions')
            .doc(widget.interventionId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Erreur: ${snapshot.error}"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final doc = snapshot.data!;
          final data = doc.data() as Map<String, dynamic>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(data),
                const SizedBox(height: 16),
                _buildInfoCard(data),
                const SizedBox(height: 16),
                _buildMediaGallery(data['mediaUrls']),
                const SizedBox(height: 24),

                // --- ACTION ZONE ---
                const Text(
                  "ROUTAGE & VALIDATION",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1),
                ),
                const SizedBox(height: 12),

                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Sélectionnez le service concerné :",
                          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                        ),
                        const SizedBox(height: 12),
                        // 1. Service Type Switcher
                        _buildServiceSwitcher(),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // --- BUTTONS ---
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isProcessing ? null : _rejectRequest,
                        icon: const Icon(Icons.close),
                        label: const Text("REFUSER"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : () => _approveRequest(doc),
                        icon: _isProcessing
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check),
                        label: Text(_isProcessing ? "Traitement..." : "ACCEPTER"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- WIDGET HELPER METHODS ---

  Widget _buildHeader(Map<String, dynamic> data) {
    final date = (data['createdAt'] as Timestamp?)?.toDate();
    final formattedDate = date != null ? DateFormat('dd MMM yyyy à HH:mm').format(date) : '-';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.pending_actions, color: Colors.orange, size: 30),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Demande en Attente",
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
              ),
              Text(
                "Reçue le $formattedDate",
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(Map<String, dynamic> data) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Client & Store
            Row(
              children: [
                const Icon(Icons.store, color: Color(0xFF667EEA)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['storeName'] ?? 'Magasin Inconnu',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        data['clientName'] ?? 'Client Inconnu',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Description
            const Text("Problème signalé :", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                data['requestDescription'] ?? "Pas de description.",
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
            ),

            const SizedBox(height: 16),

            // Contact
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(data['managerName'] ?? "Nom inconnu"),
                const SizedBox(width: 16),
                const Icon(Icons.phone, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(data['clientPhone'] ?? "Non renseigné"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaGallery(dynamic mediaUrls) {
    if (mediaUrls == null || (mediaUrls is List && mediaUrls.isEmpty)) {
      return const SizedBox.shrink();
    }

    final List urls = mediaUrls as List;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "PIÈCES JOINTES",
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: urls.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final url = urls[index].toString();
              return GestureDetector(
                onTap: () => _launchUrl(url),
                child: Container(
                  width: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade200,
                    image: DecorationImage(
                      image: NetworkImage(url),
                      fit: BoxFit.cover,
                      onError: (_, __) => const Icon(Icons.broken_image),
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.black12,
                    ),
                    child: const Center(
                      child: Icon(Icons.visibility, color: Colors.white),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildServiceSwitcher() {
    return Row(
      children: [
        Expanded(
          child: _buildServiceOption(
            "Service Technique",
            Icons.build,
            _selectedServiceType == "Service Technique",
                () => setState(() {
              _selectedServiceType = "Service Technique";
            }),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildServiceOption(
            "Service IT",
            Icons.computer,
            _selectedServiceType == "Service IT",
                () => setState(() {
              _selectedServiceType = "Service IT";
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceOption(String label, IconData icon, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF667EEA) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF667EEA) : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: isSelected ? [
            BoxShadow(color: const Color(0xFF667EEA).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
          ] : [],
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 12
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}