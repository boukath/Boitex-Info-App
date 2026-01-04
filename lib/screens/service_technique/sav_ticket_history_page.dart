// lib/screens/service_technique/sav_ticket_history_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/models/sav_ticket.dart';
import 'package:boitex_info_app/screens/service_technique/sav_ticket_details_page.dart';

class SavTicketHistoryPage extends StatefulWidget {
  final String serviceType;

  const SavTicketHistoryPage({super.key, required this.serviceType});

  @override
  State<SavTicketHistoryPage> createState() => _SavTicketHistoryPageState();
}

class _SavTicketHistoryPageState extends State<SavTicketHistoryPage> {
  // ✅ STATE: Search Query
  String _searchQuery = '';

  // ✅ STATE: Year Selection (Default to current year)
  int _selectedYear = DateTime.now().year;

  // Generate a list of years (Current year back 4 years)
  List<int> get _availableYears {
    final currentYear = DateTime.now().year;
    return List.generate(4, (index) => currentYear - index);
  }

  @override
  Widget build(BuildContext context) {
    // ✅ LOGIC: Define the Date Range for the selected year
    final startOfYear = DateTime(_selectedYear, 1, 1);
    final endOfYear = DateTime(_selectedYear, 12, 31, 23, 59, 59);

    return Scaffold(
      appBar: AppBar(
        title: Text('Historique SAV - ${widget.serviceType}'),
        backgroundColor: Colors.orange,
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
                dropdownColor: Colors.orange.shade700,
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
      body: Column(
        children: [
          // Search bar UI (Unchanged)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: const InputDecoration(
                labelText: 'Rechercher (Code, Client, Produit...)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12.0)),
                ),
              ),
            ),
          ),
          // Expanded List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('sav_tickets')
                  .where('serviceType', isEqualTo: widget.serviceType)
                  .where('status', whereIn: ['Retourné', 'Dépose'])
              // ✅ QUERY: Filter by Date Range (Time Machine Logic)
                  .where('createdAt', isGreaterThanOrEqualTo: startOfYear)
                  .where('createdAt', isLessThanOrEqualTo: endOfYear)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (BuildContext context,
                  AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.hasError) {
                  debugPrint("Firestore Error: ${snapshot.error}");
                  return const Center(child: Text('Une erreur est survenue.'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                      child: Text('Aucun ticket SAV en $_selectedYear.'));
                }

                // Filtering logic (Search) applied to the Year's data
                final allTickets = snapshot.data!.docs.map((doc) {
                  return SavTicket.fromFirestore(
                      doc as DocumentSnapshot<Map<String, dynamic>>);
                }).toList();

                final filteredTickets = allTickets.where((ticket) {
                  final query = _searchQuery.toLowerCase();
                  return ticket.savCode.toLowerCase().contains(query) ||
                      ticket.clientName.toLowerCase().contains(query) ||
                      ticket.productName.toLowerCase().contains(query) ||
                      ticket.serialNumber.toLowerCase().contains(query);
                }).toList();

                if (filteredTickets.isEmpty) {
                  return const Center(child: Text('Aucun résultat trouvé pour cette recherche.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  itemCount: filteredTickets.length,
                  itemBuilder: (context, index) {
                    final ticket = filteredTickets[index];

                    // Visual distinction for 'Dépose' vs 'Retourné'
                    final isDepose = ticket.status == 'Dépose';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) =>
                                SavTicketDetailsPage(ticket: ticket),
                          ));
                        },
                        borderRadius: BorderRadius.circular(12.0),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: isDepose ? Colors.blueGrey : Colors.grey,
                                child: Icon(
                                    isDepose ? Icons.remove_circle_outline : Icons.history,
                                    color: Colors.white
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(ticket.savCode,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16)),
                                        // Show a small tag for the status
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isDepose ? Colors.blueGrey.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            ticket.status,
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: isDepose ? Colors.blueGrey : Colors.grey[700],
                                                fontWeight: FontWeight.bold
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Client: ${ticket.clientName}',
                                      style: TextStyle(
                                          color: Colors.grey.shade700),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Produit: ${ticket.productName}',
                                      style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}