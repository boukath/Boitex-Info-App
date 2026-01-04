// lib/screens/administration/mission_history_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/models/mission.dart';
import 'package:boitex_info_app/screens/administration/mission_details_page.dart';

class MissionHistoryListPage extends StatefulWidget {
  final String serviceType;

  const MissionHistoryListPage({super.key, required this.serviceType});

  @override
  State<MissionHistoryListPage> createState() => _MissionHistoryListPageState();
}

class _MissionHistoryListPageState extends State<MissionHistoryListPage> {
  // ✅ STATE: Default to current year
  int _selectedYear = DateTime.now().year;

  // Generate a list of years (Current year back 4 years)
  List<int> get _availableYears {
    final currentYear = DateTime.now().year;
    return List.generate(4, (index) => currentYear - index);
  }

  Color _getStatusColor(String status) {
    if (status == 'Terminée') {
      return Colors.green;
    }
    return Colors.grey;
  }

  Widget _getStatusChip(String status) {
    return Chip(
      label: Text(status,
          style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: _getStatusColor(status),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ LOGIC: Define the Date Range for the selected year
    final startOfYear = DateTime(_selectedYear, 1, 1);
    final endOfYear = DateTime(_selectedYear, 12, 31, 23, 59, 59);

    return Scaffold(
      appBar: AppBar(
        title: Text('Historique Missions - ${widget.serviceType}'),
        actions: [
          // ✅ UI: Year Selector Dropdown
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedYear,
                dropdownColor: Colors.white,
                icon: const Icon(Icons.arrow_drop_down,
                    color: Colors.blue, size: 24),
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('missions')
            .where('serviceType', isEqualTo: widget.serviceType)
            .where('status', isEqualTo: 'Terminée')
        // ✅ QUERY: Filter by Date Range (Time Machine Logic)
            .where('createdAt', isGreaterThanOrEqualTo: startOfYear)
            .where('createdAt', isLessThanOrEqualTo: endOfYear)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            debugPrint("Firestore Error: ${snapshot.error}");
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune mission terminée en $_selectedYear',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          final missions = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: missions.length,
            itemBuilder: (context, index) {
              final mission = Mission.fromFirestore(missions[index]);
              final formattedStart =
              DateFormat('dd/MM/yyyy').format(mission.startDate);
              final formattedEnd =
              DateFormat('dd/MM/yyyy').format(mission.endDate);

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MissionDetailsPage(mission: mission),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.check_circle,
                                  color: Colors.green.shade700),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${mission.missionCode} - ${mission.title}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _getStatusChip(mission.status),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 16, color: Colors.red.shade400),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                mission.destinationsDisplay,
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.calendar_today,
                                size: 16, color: Colors.blue.shade400),
                            const SizedBox(width: 4),
                            Text(
                              'Du $formattedStart au $formattedEnd',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
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
    );
  }
}