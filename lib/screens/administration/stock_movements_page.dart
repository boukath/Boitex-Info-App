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

  // ⏩ Navigate Next/Previous Month
  void _changeMonth(int monthsToAdd) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + monthsToAdd,
        1,
      );
    });
  }

  // 📅 Pick Any Date (Jump to 2026 etc)
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale("fr", "FR"),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: widget.type == StockMovementType.entry ? Colors.green : Colors.redAccent,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        // Always set to the 1st of the picked month to avoid bugs
        _selectedMonth = DateTime(picked.year, picked.month, 1);
      });
    }
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

    final monthLabel = DateFormat.yMMMM('fr_FR').format(_selectedMonth);
    // Capitalize first letter (e.g., "novembre" -> "Novembre")
    final formattedDate = monthLabel[0].toUpperCase() + monthLabel.substring(1);

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
          // 🗓️ NEW: NAVIGATION HEADER
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Colors.white,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Previous Month Button
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () => _changeMonth(-1),
                    color: Colors.grey.shade700,
                  ),

                  // Date Display (Clickable)
                  GestureDetector(
                    onTap: _pickDate,
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month_rounded, size: 18, color: themeColor),
                        const SizedBox(width: 8),
                        Text(
                          formattedDate,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Next Month Button
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: () => _changeMonth(1),
                    color: Colors.grey.shade700,
                  ),
                ],
              ),
            ),
          ),

          // 📄 LIST OF MOVEMENTS (Same robust logic as before)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collectionGroup('stock_history')
                  .where('type', isEqualTo: typeString)
                  .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
                  .where('timestamp', isLessThan: Timestamp.fromDate(endOfMonth))
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Erreur: ${snapshot.error}"));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          "Aucun mouvement en $formattedDate",
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
                        ? DateFormat('dd MMM • HH:mm', 'fr_FR').format(timestamp.toDate())
                        : "Date inconnue";

                    // Fetch Parent Product
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
                            if (!productSnap.hasData) return Text("...", style: GoogleFonts.poppins(color: Colors.grey));
                            final productData = productSnap.data!.data() as Map<String, dynamic>?;
                            final productName = productData?['nom'] ?? "Produit Inconnu";
                            return Text(
                              productName,
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
                            );
                          },
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(reason, style: GoogleFonts.poppins(fontSize: 13)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.person_outline, size: 12, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(user, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                                const SizedBox(width: 12),
                                Icon(Icons.access_time, size: 12, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(dateStr, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ],
                        ),
                        trailing: Text(
                          "${isEntry ? '+' : ''}$change",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: themeColor,
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