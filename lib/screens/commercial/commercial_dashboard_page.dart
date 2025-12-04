// lib/screens/commercial/commercial_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:boitex_info_app/screens/commercial/add_prospect_page.dart';
import 'package:boitex_info_app/screens/commercial/prospect_details_page.dart';
import 'package:boitex_info_app/models/prospect.dart';

class CommercialDashboardPage extends StatefulWidget {
  const CommercialDashboardPage({super.key});

  @override
  State<CommercialDashboardPage> createState() => _CommercialDashboardPageState();
}

class _CommercialDashboardPageState extends State<CommercialDashboardPage> {
  // Filter States
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";
  String? _selectedActivity;
  String? _selectedCommune;
  DateTime? _selectedDate;

  // Helper to extract Commune from address string
  String _getCommune(String address) {
    return address.contains('-') ? address.split('-')[0].trim() : address;
  }

  // Helper to format Date for comparison (ignoring time)
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // Reset all filters
  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _searchText = "";
      _selectedActivity = null;
      _selectedCommune = null;
      _selectedDate = null;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tableau de Bord Commercial"),
        backgroundColor: const Color(0xFFFF9966),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        actions: [
          // Filter Reset Action
          if (_selectedActivity != null || _selectedCommune != null || _selectedDate != null || _searchText.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: "Réinitialiser les filtres",
              onPressed: _resetFilters,
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFFF9966).withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('prospects')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            // 1. Loading State
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // 2. Error State
            if (snapshot.hasError) {
              return Center(child: Text("Erreur: ${snapshot.error}"));
            }

            // 3. Data Processing
            final allDocs = snapshot.data?.docs ?? [];

            // --- A. DYNAMIC FILTER OPTIONS GENERATION ---
            // We extract unique values from the data to populate dropdowns
            final Set<String> activities = {};
            final Set<String> communes = {};

            for (var doc in allDocs) {
              final data = doc.data() as Map<String, dynamic>;
              if (data['serviceType'] != null) activities.add(data['serviceType']);
              if (data['address'] != null) communes.add(_getCommune(data['address']));
            }

            // --- B. APPLY FILTERS ---
            final filteredDocs = allDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;

              // 1. Text Search (Name or Contact)
              final company = (data['companyName'] ?? '').toString().toLowerCase();
              final contact = (data['contactName'] ?? '').toString().toLowerCase();
              final search = _searchText.toLowerCase();
              final matchesText = search.isEmpty || company.contains(search) || contact.contains(search);

              // 2. Activity Filter
              final matchesActivity = _selectedActivity == null || data['serviceType'] == _selectedActivity;

              // 3. Commune Filter
              final matchesCommune = _selectedCommune == null || _getCommune(data['address'] ?? '') == _selectedCommune;

              // 4. Date Filter
              final timestamp = data['createdAt'] as Timestamp?;
              final matchesDate = _selectedDate == null ||
                  (timestamp != null && _isSameDay(timestamp.toDate(), _selectedDate!));

              return matchesText && matchesActivity && matchesCommune && matchesDate;
            }).toList();


            return Column(
              children: [
                // --- SEARCH & FILTER BAR ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5)),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Search Input
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: "Rechercher une enseigne, un contact...",
                          prefixIcon: const Icon(Icons.search, color: Color(0xFFFF9966)),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchText = val;
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // Filter Rows (Horizontal Scroll)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // Date Filter
                            _buildFilterChip(
                              label: _selectedDate == null
                                  ? "Date"
                                  : DateFormat('dd/MM').format(_selectedDate!),
                              icon: Icons.calendar_today,
                              isSelected: _selectedDate != null,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2023),
                                  lastDate: DateTime.now(),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: const ColorScheme.light(
                                          primary: Color(0xFFFF9966),
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (picked != null) setState(() => _selectedDate = picked);
                              },
                              onClear: _selectedDate != null ? () => setState(() => _selectedDate = null) : null,
                            ),
                            const SizedBox(width: 8),

                            // Activity Filter
                            _buildDropdownFilter(
                              label: "Activité",
                              value: _selectedActivity,
                              items: activities.toList()..sort(),
                              icon: Icons.store,
                              onChanged: (val) => setState(() => _selectedActivity = val),
                            ),
                            const SizedBox(width: 8),

                            // Commune Filter
                            _buildDropdownFilter(
                              label: "Commune",
                              value: _selectedCommune,
                              items: communes.toList()..sort(),
                              icon: Icons.location_on,
                              onChanged: (val) => setState(() => _selectedCommune = val),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // --- RESULTS LIST ---
                Expanded(
                  child: filteredDocs.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.filter_list_off, size: 60, color: Colors.grey.withOpacity(0.4)),
                        const SizedBox(height: 16),
                        Text(
                          "Aucun résultat pour ces filtres",
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                        ),
                        TextButton(
                          onPressed: _resetFilters,
                          child: const Text("Réinitialiser", style: TextStyle(color: Color(0xFFFF9966))),
                        )
                      ],
                    ),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final createdTimestamp = data['createdAt'] as Timestamp?;
                      final date = createdTimestamp?.toDate() ?? DateTime.now();

                      final companyName = data['companyName'] ?? 'Sans nom';
                      final serviceType = data['serviceType'] ?? 'Inconnu';
                      final contactName = data['contactName'] ?? 'Aucun contact';
                      final address = data['address'] ?? '';
                      final commune = _getCommune(address);

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            // Reconstruct object and Navigate
                            final prospectObj = Prospect.fromMap({
                              ...data,
                              'id': doc.id,
                              'createdAt': data['createdAt'],
                            });

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProspectDetailsPage(prospect: prospectObj),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF9966).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFFF9966).withOpacity(0.5)),
                                      ),
                                      child: Text(
                                        serviceType.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFE65100),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      timeago.format(date, locale: 'fr'),
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.store, color: Color(0xFFFF9966)),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            companyName,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF333333),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          if (contactName.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 2),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                                                  const SizedBox(width: 4),
                                                  Text(contactName, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                                                ],
                                              ),
                                            ),
                                          Row(
                                            children: [
                                              Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  commune,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right, color: Colors.grey),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddProspectPage(),
            ),
          );
        },
        backgroundColor: const Color(0xFFFF9966),
        icon: const Icon(Icons.add_business),
        label: const Text("Nouveau Prospect"),
      ),
    );
  }

  // --- BUILDER HELPERS FOR FILTERS ---

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    VoidCallback? onClear
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF9966) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF9966) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey.shade700),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade800,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isSelected && onClear != null) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: onClear,
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownFilter({
    required String label,
    required String? value,
    required List<String> items,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    // Determine status
    final isSelected = value != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFF9966) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? const Color(0xFFFF9966) : Colors.grey.shade300,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey.shade700),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: Colors.grey.shade800, fontSize: 14)),
            ],
          ),
          icon: Icon(Icons.arrow_drop_down, color: isSelected ? Colors.white : Colors.grey.shade600),
          dropdownColor: Colors.white,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          selectedItemBuilder: (context) {
            return items.map((item) {
              return Row(
                children: [
                  Icon(icon, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                      item.length > 15 ? '${item.substring(0, 12)}...' : item,
                      style: const TextStyle(color: Colors.white)
                  ),
                ],
              );
            }).toList();
          },
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.normal),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}