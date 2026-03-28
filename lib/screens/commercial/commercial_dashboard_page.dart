// lib/screens/commercial/commercial_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:boitex_info_app/screens/commercial/add_prospect_page.dart';
import 'package:boitex_info_app/screens/commercial/prospect_details_page.dart';
import 'package:boitex_info_app/models/prospect.dart';
import 'package:boitex_info_app/screens/commercial/commercial_leaderboard_page.dart';
// ✅ ADDED: Async import for Timer
import 'dart:async';

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

  // ✅ ADDED: Time Tracking State for Adaptive Colors
  late Timer _timeTimer;
  late DateTime _currentTime;

  final List<String> _communesAlger = [
    'Alger-Centre', "Sidi M'Hamed", 'El Madania', 'Belouizdad', 'Bab El Oued',
    'Bologhine', 'Casbah', 'Oued Koriche', 'Bir Mourad Raïs', 'El Biar',
    'Bouzareah', 'Birkhadem', 'El Harrach', 'Baraki', 'Oued Smar',
    'Bachdjerrah', 'Hussein Dey', 'Kouba', 'Bourouba', 'Dar El Beïda',
    'Bab Ezzouar', 'Ben Aknoun', 'Dely Ibrahim', 'Hammamet', 'Raïs Hamidou',
    'Djasr Kasentina', 'El Mouradia', 'Hydra', 'Mohammadia', 'Bordj El Kiffan',
    'El Magharia', 'Beni Messous', 'Les Eucalyptus', 'Birtouta', 'Tessala El Merdja',
    'Ouled Chebel', 'Sidi Moussa', 'Aïn Taya', 'Bordj El Bahri', 'El Marsa',
    "H'Raoua", 'Rouïba', 'Reghaïa', 'Aïn Benian', 'Staoueli',
    'Zeralda', 'Mahelma', 'Rahmania', 'Souidania', 'Cheraga',
    'Ouled Fayet', 'El Achour', 'Draria', 'Douera', 'Baba Hassen',
    'Khraicia', 'Saoula'
  ]..sort();

  final List<String> _serviceTypes = [
    'Fast Food / Snack',
    'Restaurant',
    'Magasin de Vêtements',
    'Supermarché / Supérette',
    'Pharmacie',
    'Boulangerie',
    'Autre',
  ];

  @override
  void initState() {
    super.initState();
    // ✅ ADDED: Initialize Time Tracker
    _currentTime = DateTime.now();
    _timeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    // ✅ ADDED: Cancel timer to prevent memory leaks
    _timeTimer.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ✅ ADDED: Adaptive Color Logic
  List<Color> _getTimeBasedGradientColors() {
    final hour = _currentTime.hour;
    if (hour >= 6 && hour < 12) {
      // Morning
      return const [Color(0xFF8CA6DB), Color(0xFFFFB347), Color(0xFFFF7B54)];
    } else if (hour >= 12 && hour < 18) {
      // Afternoon
      return const [Color(0xFF667EEA), Color(0xFF764BA2), Color(0xFFF093FB)];
    } else {
      // Evening/Night
      return const [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2A0845)];
    }
  }

  // Helper to extract Commune from address string (Fallback for old data)
  String _getCommuneLegacy(String address) {
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

  // ⚡ KEY IMPROVEMENT: Database-Level Filtering
  Stream<QuerySnapshot> _getFilteredStream() {
    Query query = FirebaseFirestore.instance.collection('prospects');

    if (_selectedActivity != null) {
      query = query.where('serviceType', isEqualTo: _selectedActivity);
    }

    if (_selectedCommune != null) {
      query = query.where('commune', isEqualTo: _selectedCommune);
    }

    query = query.orderBy('createdAt', descending: true);
    return query.limit(50).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ CHANGED: Wrapped Scaffold in AnimatedContainer for full-screen adaptive gradient
    return AnimatedContainer(
      duration: const Duration(seconds: 4),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _getTimeBasedGradientColors(),
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Scaffold(
        // ✅ CHANGED: Made Scaffold transparent to show the gradient underneath
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Commercial"),
          // ✅ CHANGED: Made AppBar transparent
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          actions: [
            // 🏆 LEADERBOARD BUTTON
            IconButton(
              icon: const Icon(Icons.emoji_events),
              tooltip: "Classement",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CommercialLeaderboardPage()),
                );
              },
            ),

            // Filter Reset Action
            if (_selectedActivity != null || _selectedCommune != null || _selectedDate != null || _searchText.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.filter_alt_off),
                tooltip: "Réinitialiser les filtres",
                onPressed: _resetFilters,
              ),
          ],
        ),
        body: Column(
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
                        // Date Filter (Still Client Side for now)
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
                          items: _serviceTypes,
                          icon: Icons.store,
                          onChanged: (val) => setState(() => _selectedActivity = val),
                        ),
                        const SizedBox(width: 8),

                        // Commune Filter
                        _buildDropdownFilter(
                          label: "Commune",
                          value: _selectedCommune,
                          items: _communesAlger,
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
              child: StreamBuilder<QuerySnapshot>(
                // ⚡ Use the optimized stream
                stream: _getFilteredStream(),
                builder: (context, snapshot) {
                  // 1. Loading State
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  }

                  // 2. Error State
                  if (snapshot.hasError) {
                    return Center(child: Text("Erreur: ${snapshot.error}", style: const TextStyle(color: Colors.white)));
                  }

                  // 3. Data Processing & Client-Side Filtering (Search Text)
                  final rawDocs = snapshot.data?.docs ?? [];

                  final filteredDocs = rawDocs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    // A. Text Search
                    final company = (data['companyName'] ?? '').toString().toLowerCase();
                    final contact = (data['contactName'] ?? '').toString().toLowerCase();
                    final author = (data['authorName'] ?? '').toString().toLowerCase();
                    final search = _searchText.toLowerCase();

                    final matchesText = search.isEmpty ||
                        company.contains(search) ||
                        contact.contains(search) ||
                        author.contains(search);

                    // B. Date Filter
                    final timestamp = data['createdAt'] as Timestamp?;
                    final matchesDate = _selectedDate == null ||
                        (timestamp != null && _isSameDay(timestamp.toDate(), _selectedDate!));

                    return matchesText && matchesDate;
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.filter_list_off, size: 60, color: Colors.white.withOpacity(0.6)),
                          const SizedBox(height: 16),
                          const Text(
                            "Aucun résultat",
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          if (_selectedActivity != null || _selectedCommune != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                "(Vérifiez vos filtres Activité/Commune)",
                                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                              ),
                            ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _resetFilters,
                            style: TextButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                            ),
                            child: const Text("Réinitialiser tout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      final prospectObj = Prospect.fromMap({
                        ...data,
                        'id': doc.id,
                      });

                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
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
                                        prospectObj.serviceType.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFE65100),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      timeago.format(prospectObj.createdAt, locale: 'fr'),
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
                                            prospectObj.companyName,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF333333),
                                            ),
                                          ),
                                          const SizedBox(height: 4),

                                          // ⚡ NEW: Author Name Badge
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 4),
                                            child: Row(
                                              children: [
                                                Icon(Icons.badge, size: 14, color: Colors.blueAccent),
                                                const SizedBox(width: 4),
                                                Text(
                                                  prospectObj.authorName, // e.g. "Amine Tounsi"
                                                  style: TextStyle(
                                                      color: Colors.blueAccent.shade700,
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          if (prospectObj.contactName.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 2),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                                                  const SizedBox(width: 4),
                                                  Text(prospectObj.contactName, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                                                ],
                                              ),
                                            ),
                                          Row(
                                            children: [
                                              Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  prospectObj.commune.isNotEmpty
                                                      ? prospectObj.commune
                                                      : _getCommuneLegacy(prospectObj.address),
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
                  );
                },
              ),
            ),
          ],
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