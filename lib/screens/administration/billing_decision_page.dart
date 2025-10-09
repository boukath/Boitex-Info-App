// lib/screens/administration/billing_decision_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:boitex_info_app/services/activity_logger.dart';
import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';

class BillingDecisionPage extends StatefulWidget {
  final DocumentSnapshot interventionDoc;
  const BillingDecisionPage({super.key, required this.interventionDoc});

  @override
  State<BillingDecisionPage> createState() => _BillingDecisionPageState();
}

class _BillingDecisionPageState extends State<BillingDecisionPage> {
  bool _isActionInProgress = false;

  Future<void> _closeWithoutBilling() async {
    setState(() => _isActionInProgress = true);
    try {
      final data = widget.interventionDoc.data() as Map<String, dynamic>;

      await FirebaseFirestore.instance.collection('interventions').doc(widget.interventionDoc.id).update({
        'status': 'Clôturé',
        'billingStatus': 'Sans Facture',
        'closedAt': Timestamp.now(),
      });

      await ActivityLogger.logActivity(
        message: "Intervention clôturée sans facture.",
        category: "Facturation",
        interventionId: widget.interventionDoc.id,
        interventionCode: data['interventionCode'],
        storeName: data['storeName'],
        storeLocation: data['storeLocation'],
        clientName: data['clientName'],
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Intervention clôturée sans facture.')));
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
        setState(() => _isActionInProgress = false);
      }
    }
  }

  Future<void> _billAndClose() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result == null) return;

    setState(() => _isActionInProgress = true);
    try {
      final data = widget.interventionDoc.data() as Map<String, dynamic>;
      final file = File(result.files.single.path!);
      final interventionCode = data['interventionCode'] ?? 'unknown';
      final ref = FirebaseStorage.instance.ref().child('invoices/$interventionCode.pdf');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('interventions').doc(widget.interventionDoc.id).update({
        'status': 'Clôturé',
        'billingStatus': 'Facturé',
        'invoiceUrl': url,
        'closedAt': Timestamp.now(),
      });

      await ActivityLogger.logActivity(
        message: "Intervention facturée et clôturée.",
        category: "Facturation",
        interventionId: widget.interventionDoc.id,
        interventionCode: data['interventionCode'],
        storeName: data['storeName'],
        storeLocation: data['storeLocation'],
        clientName: data['clientName'],
        invoiceUrl: url,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Intervention facturée et clôturée.')));
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
        setState(() => _isActionInProgress = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.interventionDoc.data() as Map<String, dynamic>;
    final interventionDate = (data['interventionDate'] as Timestamp).toDate();
    final signatureUrl = data['report_signatureImageUrl'] as String?;
    final interventionCode = data['interventionCode'] ?? 'Intervention';

    return Scaffold(
      appBar: AppBar(
        title: Text('Décision: $interventionCode'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.business_center, color: Colors.teal),
              title: const Text('Client / Magasin'),
              subtitle: Text('${data['clientName']}\n${data['storeName']}', style: const TextStyle(fontSize: 16)),
              isThreeLine: true,
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today, color: Colors.teal),
              title: const Text('Date'),
              subtitle: Text(DateFormat('dd MMMM yyyy', 'fr_FR').format(interventionDate), style: const TextStyle(fontSize: 16)),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.plumbing, color: Colors.teal),
              title: const Text('Diagnostic du technicien'),
              subtitle: Text(data['report_diagnostic'] ?? 'N/A', style: const TextStyle(fontSize: 16)),
            ),
            ListTile(
              leading: const Icon(Icons.build, color: Colors.teal),
              title: const Text('Travaux effectués'),
              subtitle: Text(data['report_workDone'] ?? 'N/A', style: const TextStyle(fontSize: 16)),
            ),
            if (signatureUrl != null) ...[
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.teal),
                title: const Text('Signature du responsable'),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Image.network(signatureUrl, height: 100)
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Card(
              color: Colors.grey.shade50,
              elevation: 2.0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Décision de Facturation', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    if (_isActionInProgress)
                      const Center(child: CircularProgressIndicator())
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.do_not_disturb_alt),
                              onPressed: _closeWithoutBilling,
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
                              onPressed: _billAndClose,
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
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}