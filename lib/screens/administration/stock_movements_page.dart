// lib/screens/administration/stock_movements_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

enum StockMovementType { entry, exit }

class StockMovementsPage extends StatefulWidget {
  final StockMovementType type;

  const StockMovementsPage({super.key, required this.type});

  @override
  State<StockMovementsPage> createState() => _StockMovementsPageState();
}

class _StockMovementsPageState extends State<StockMovementsPage> {
  // Start with the current month
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null);
  }

  // Generate the last 12 months for the tabs
  List<DateTime> _getTabMonths() {
    List<DateTime> months = [];
    DateTime now = DateTime.now();
    for (int i = 0; i < 12; i++) {
      months.add(DateTime(now.year, now.month - i, 1));
    }
    return months;
  }

  void _onMonthSelected(DateTime month) {
    setState(() {
      _selectedMonth = month;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEntry = widget.type == StockMovementType.entry;
    final title = isEntry ? "Détails des Entrées" : "Détails des Sorties";
    final themeColor = isEntry ? Colors.green : Colors.redAccent;
    final typeString = isEntry ? 'Entrée' : 'Sortie';

    // Calculate Start and End of the selected month for the query
    final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          title,
          style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          // 🗓️ MONTH SELECTOR TABS
          Container(
            height: 70,
            color: Colors.white,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              itemCount: _getTabMonths().length,
              itemBuilder: (context, index) {
                final monthDate = _getTabMonths()[index];
                final isSelected = monthDate.month == _selectedMonth.month &&
                    monthDate.year == _selectedMonth.year;
                final label = DateFormat.yMMMM('fr_FR').format(monthDate);

                return GestureDetector(
                  onTap: () => _onMonthSelected(monthDate),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? themeColor : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: isSelected
                          ? [BoxShadow(color: themeColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                          : [],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label[0].toUpperCase() + label.substring(1), // Capitalize first letter
                      style: GoogleFonts.poppins(
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 📄 LIST OF MOVEMENTS
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collectionGroup('stock_history')
                  .where('type', isEqualTo: typeString) // Filter by "Entrée" or "Sortie"
                  .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth)) // Start Date
                  .where('timestamp', isLessThan: Timestamp.fromDate(endOfMonth)) // End Date
                  .orderBy('timestamp', descending: true) // ✅ SORTED NEWEST FIRST
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  print("Error: ${snapshot.error}");
                  return Center(child: Text("Erreur de chargement (Vérifiez les index)"));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off, size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          "Aucun mouvement pour ce mois.",
                          style: GoogleFonts.poppins(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final change = data['change'] ?? 0;
                    final reason = data['reason'] ?? "Mise à jour";
                    final user = data['user'] ?? "Inconnu";
                    final timestamp = data['timestamp'] as Timestamp?;
                    final dateStr = timestamp != null
                        ? DateFormat('dd MMM yyyy • HH:mm', 'fr_FR').format(timestamp.toDate())
                        : "Date inconnue";

                    // Fetch Parent Product (We need to go up the reference tree)
                    final productRef = docs[index].reference.parent.parent;

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: themeColor.withOpacity(0.1),
                          child: Icon(
                            isEntry ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                            color: themeColor,
                            size: 20,
                          ),
                        ),
                        title: FutureBuilder<DocumentSnapshot>(
                          future: productRef!.get(),
                          builder: (context, productSnap) {
                            if (!productSnap.hasData) return Text("Chargement...", style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey));

                            final productData = productSnap.data!.data() as Map<String, dynamic>?;
                            final productName = productData?['nom'] ?? productData?['name'] ?? "Produit Supprimé";

                            return Text(
                              productName,
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
                            );
                          },
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("$reason", style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87)),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.person_outline, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(user, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                                  const SizedBox(width: 10),
                                  Icon(Icons.access_time, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(dateStr, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: themeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "${isEntry ? '+' : ''}$change",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: themeColor,
                            ),
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