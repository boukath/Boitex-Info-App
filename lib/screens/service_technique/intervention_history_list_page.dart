// lib/screens/service_technique/intervention_history_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';

class InterventionHistoryListPage extends StatefulWidget {
  final String serviceType;

  const InterventionHistoryListPage({super.key, required this.serviceType});

  @override
  State<InterventionHistoryListPage> createState() =>
      _InterventionHistoryListPageState();
}

class _InterventionHistoryListPageState
    extends State<InterventionHistoryListPage> {
  // ✅ STATE: Default to current year (e.g., 2026)
  int _selectedYear = DateTime.now().year;

  // Generate a list of years for the dropdown (Current year back to 2023)
  List<int> get _availableYears {
    final currentYear = DateTime.now().year;
    return List.generate(4, (index) => currentYear - index);
  }

  @override
  Widget build(BuildContext context) {
    // ✅ LOGIC: Define the start and end of the selected year
    final startOfYear = DateTime(_selectedYear, 1, 1);
    final endOfYear = DateTime(_selectedYear, 12, 31, 23, 59, 59);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des Interventions'),
        actions: [
          // ✅ UI: Year Selector Dropdown
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedYear,
                dropdownColor: Colors.blue.shade800,
                icon: const Icon(Icons.calendar_today, color: Colors.white, size: 18),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
                items: _availableYears.map((year) {
                  return DropdownMenuItem(
                    value: year,
                    child: Text("Année $year"),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedYear = val);
                  }
                },
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        // ✅ QUERY CHANGE: Added Date Range Filter
        stream: FirebaseFirestore.instance
            .collection('interventions')
            .where('serviceType', isEqualTo: widget.serviceType)
            .where('status', whereIn: ['Terminé', 'Clôturé'])
        // Filter by Created Date (Jan 1 - Dec 31)
            .where('createdAt', isGreaterThanOrEqualTo: startOfYear)
            .where('createdAt', isLessThanOrEqualTo: endOfYear)
        // Note: Firestore requires the first orderBy to match the inequality filter
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            // Helpful debug info for index errors
            debugPrint("Firestore Error: ${snapshot.error}");
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history_toggle_off,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune intervention trouvée\npour l\'année $_selectedYear.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;
          final grouped = _groupInterventions(docs);

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: grouped.keys.length,
            itemBuilder: (context, index) {
              final clientName = grouped.keys.elementAt(index);
              final stores = grouped[clientName]!;
              return _buildClientTile(context, clientName, stores);
            },
          );
        },
      ),
    );
  }

  // client -> store -> location -> list of docs
  Map<String,
      Map<String,
          Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>>>
  _groupInterventions(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    final Map<
        String,
        Map<String,
            Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>>>
    grouped = {};

    for (final doc in docs) {
      final data = doc.data();
      final String clientName =
          (data['clientName'] as String?) ?? 'Client non spécifié';
      final String storeName =
          (data['storeName'] as String?) ?? 'Magasin non spécifié';
      final String locationName =
          (data['storeLocation'] as String?) ?? 'Emplacement non spécifié';

      grouped.putIfAbsent(clientName, () => {});
      grouped[clientName]!.putIfAbsent(storeName, () => {});
      grouped[clientName]![storeName]!.putIfAbsent(locationName, () => []);
      grouped[clientName]![storeName]![locationName]!.add(doc);
    }

    return grouped;
  }

  Widget _buildClientTile(
      BuildContext context,
      String clientName,
      Map<String,
          Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>>
      stores,
      ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: const Icon(Icons.business, color: Colors.blueGrey),
        title: Text(
          clientName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        children: stores.keys.map((storeName) {
          final locations = stores[storeName]!;
          return _buildStoreTile(context, storeName, locations);
        }).toList(),
      ),
    );
  }

  Widget _buildStoreTile(
      BuildContext context,
      String storeName,
      Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> locations,
      ) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0),
      child: ExpansionTile(
        leading: const Icon(Icons.store, color: Colors.teal),
        title: Text(storeName),
        children: locations.keys.map((locationName) {
          final interventions = locations[locationName]!;
          return _buildLocationTile(context, locationName, interventions);
        }).toList(),
      ),
    );
  }

  Widget _buildLocationTile(
      BuildContext context,
      String locationName,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> interventions,
      ) {
    return Padding(
      padding: const EdgeInsets.only(left: 32.0),
      child: ExpansionTile(
        leading: const Icon(Icons.location_on, color: Colors.orange),
        title: Text(locationName),
        children: interventions
            .map((interventionDoc) =>
            _buildInterventionTile(context, interventionDoc))
            .toList(),
      ),
    );
  }

  Widget _buildInterventionTile(
      BuildContext context,
      DocumentSnapshot<Map<String, dynamic>> interventionDoc,
      ) {
    final data = interventionDoc.data() ?? {};
    final String status = data['status'] ?? 'N/A'; // Get the status

    // Define UI variables based on status
    final IconData iconData;
    final Color iconColor;
    final String titleText;
    final String subtitleText;

    if (status == 'Clôturé') {
      // --- UI for "Clôturé" (Green Icon) ---
      final DateTime? closedDate = (data['closedAt'] as Timestamp?)?.toDate();
      final String billingStatus = (data['billingStatus'] as String?) ?? 'N/A';

      iconData = Icons.check_circle;
      iconColor = Colors.green;
      titleText =
      'Clôturée le: ${closedDate != null ? DateFormat('dd MMM yyyy', 'fr_FR').format(closedDate) : 'N/A'}';
      subtitleText = 'Statut: $billingStatus';
    } else {
      // --- UI for "Terminé" (Yellow Icon) ---
      // Assumed 'Terminé'
      final DateTime? completedDate =
      (data['completedAt'] as Timestamp?)?.toDate();

      iconData = Icons.pending_actions; // Yellow "pending" icon
      iconColor = Colors.orange;
      titleText =
      'Terminée le: ${completedDate != null ? DateFormat('dd MMM yyyy', 'fr_FR').format(completedDate) : 'N/A'}';
      subtitleText = 'Statut: En attente de facturation'; // Clear message
    }

    return ListTile(
      contentPadding: const EdgeInsets.only(left: 48.0, right: 16.0),
      leading:
      Icon(iconData, color: iconColor, size: 20), // Use dynamic icon/color
      title: Text(titleText), // Use dynamic title
      subtitle: Text(subtitleText), // Use dynamic subtitle
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                InterventionDetailsPage(interventionDoc: interventionDoc),
          ),
        );
      },
    );
  }
}