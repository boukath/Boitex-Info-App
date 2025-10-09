import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
// **CHANGE**: Import the new scanner page
import 'package:boitex_info_app/screens/administration/barcode_scanner_page.dart';

class SystemDetailsPage extends StatelessWidget {
  final String clientId;
  final String storeId;
  final String systemId;

  const SystemDetailsPage({
    super.key,
    required this.clientId,
    required this.storeId,
    required this.systemId,
  });

  // **NEW**: Function to save a new antenna
  Future<void> _addAntenna(String serialNumber) async {
    if (serialNumber.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('clients').doc(clientId)
        .collection('stores').doc(storeId)
        .collection('systems').doc(systemId)
        .collection('antennas').add({
      'serialNumber': serialNumber,
      'createdAt': Timestamp.now(), // Good practice to store a timestamp
    });
  }

  @override
  Widget build(BuildContext context) {
    final systemRef = FirebaseFirestore.instance
        .collection('clients').doc(clientId)
        .collection('stores').doc(storeId)
        .collection('systems').doc(systemId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du Système'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: systemRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final systemData = snapshot.data!.data() as Map<String, dynamic>;
          final installDate = (systemData['installationDate'] as Timestamp?)?.toDate();
          final warrantyDate = (systemData['warrantyDate'] as Timestamp?)?.toDate();
          final DateFormat formatter = DateFormat('dd MMMM yyyy', 'fr_FR');

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Text('${systemData['name'] ?? ''} - ${systemData['type'] ?? ''}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(leading: const Icon(Icons.check_circle_outline, color: Colors.green), title: const Text('Statut'), subtitle: Text(systemData['status'] ?? 'N/A')),
              ListTile(leading: const Icon(Icons.calendar_today_outlined), title: const Text('Date d\'installation'), subtitle: Text(installDate != null ? formatter.format(installDate) : 'Non définie')),
              ListTile(leading: const Icon(Icons.shield_outlined), title: const Text('Date de fin de garantie'), subtitle: Text(warrantyDate != null ? formatter.format(warrantyDate) : 'Non définie')),
              const Divider(height: 32),

              // **CHANGE**: Section title and scan button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Portique (Antennes)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: () async {
                      final scannedCode = await Navigator.of(context).push<String>(
                        MaterialPageRoute(builder: (context) => const BarcodeScannerPage()),
                      );
                      if (scannedCode != null) {
                        await _addAntenna(scannedCode);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              StreamBuilder<QuerySnapshot>(
                stream: systemRef.collection('antennas').orderBy('createdAt').snapshots(),
                builder: (context, antennaSnapshot) {
                  if (!antennaSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                  if (antennaSnapshot.data!.docs.isEmpty) return const Text('Aucun numéro de série ajouté.');

                  return Column(
                    children: antennaSnapshot.data!.docs.map((doc) {
                      final antennaData = doc.data() as Map<String, dynamic>;
                      return ListTile(
                        leading: const Icon(Icons.qr_code_scanner),
                        title: const Text('Numéro de série'),
                        subtitle: Text(antennaData['serialNumber'] ?? 'N/A'),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}