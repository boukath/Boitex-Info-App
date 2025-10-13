// lib/screens/administration/sav_billing_decision_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:boitex_info_app/models/sav_ticket.dart';
import 'package:boitex_info_app/services/activity_logger.dart';
import 'package:intl/intl.dart';

class SavBillingDecisionPage extends StatefulWidget {
  final SavTicket ticket;
  const SavBillingDecisionPage({super.key, required this.ticket});

  @override
  State<SavBillingDecisionPage> createState() => _SavBillingDecisionPageState();
}

class _SavBillingDecisionPageState extends State<SavBillingDecisionPage> {
  bool _isActionInProgress = false;

  Future<void> _approveAndReturn({String? invoiceUrl}) async {
    setState(() => _isActionInProgress = true);
    try {
      final billingStatus = invoiceUrl != null ? 'Facturé' : 'Sans Facture';

      await FirebaseFirestore.instance
          .collection('sav_tickets')
          .doc(widget.ticket.id)
          .update({
        'status': 'Approuvé - Prêt pour retour',
        'billingStatus': billingStatus,
        'invoiceUrl': invoiceUrl,
      });

      // ✅ FIXED: Corrected the ActivityLogger call
      await ActivityLogger.logActivity(
        message:
        "Le ticket SAV ${widget.ticket.savCode} a été approuvé pour retour ($billingStatus).",
        interventionId: widget.ticket.id,
        category: 'SAV',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ticket SAV approuvé pour retour.'),
              backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
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
        setState(() => _isActionInProgress = false);
      }
    }
  }

  Future<void> _pickAndUploadInvoice() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => _isActionInProgress = true);
      final file = File(result.files.single.path!);
      final fileName =
          'invoices/sav/${widget.ticket.savCode}-${DateTime.now().millisecondsSinceEpoch}.pdf';

      try {
        final ref = FirebaseStorage.instance.ref().child(fileName);
        final uploadTask = ref.putFile(file);
        final snapshot = await uploadTask.whenComplete(() => null);
        final downloadUrl = await snapshot.ref.getDownloadURL();

        await _approveAndReturn(invoiceUrl: downloadUrl);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Erreur lors de l\'upload: ${e.toString()}'),
                backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isActionInProgress = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Décision SAV: ${widget.ticket.savCode}'),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 24),
            _buildTechnicianReportCard(),
            const SizedBox(height: 32),
            if (_isActionInProgress)
              const Center(child: CircularProgressIndicator())
            else
              _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Détails du Ticket',
                style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 20),
            _buildInfoRow('Code SAV:', widget.ticket.savCode),
            _buildInfoRow('Client:', widget.ticket.clientName),
            _buildInfoRow('Produit:', widget.ticket.productName),
            _buildInfoRow('N° de Série:', widget.ticket.serialNumber),
            _buildInfoRow(
                'Date de création:',
                DateFormat('dd MMM yyyy', 'fr_FR')
                    .format(widget.ticket.createdAt)),
          ],
        ),
      ),
    );
  }

  Widget _buildTechnicianReportCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rapport du Technicien',
                style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 20),
            Text(
              widget.ticket.technicianReport ?? 'Aucun rapport fourni.',
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Text(
          'Approuver le ticket pour retour au client',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.do_not_disturb_alt),
                onPressed: () => _approveAndReturn(),
                label: const Text('Sans Facture'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade800,
                  side: BorderSide(color: Colors.grey.shade400),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _pickAndUploadInvoice,
                icon: const Icon(Icons.upload_file),
                label: const Text('Facturer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}