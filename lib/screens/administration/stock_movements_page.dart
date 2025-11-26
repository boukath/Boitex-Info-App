// lib/screens/administration/stock_movements_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

enum StockMovementType { entry, exit }

class StockMovementsPage extends StatelessWidget {
  final StockMovementType type;

  const StockMovementsPage({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final isEntry = type == StockMovementType.entry;
    final title = isEntry ? "Détails des Entrées" : "Détails des Sorties";
    final color = isEntry ? Colors.green : Colors.redAccent;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(title, style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 🔍 Query the 'stock_history' collection group
        stream: FirebaseFirestore.instance
            .collectionGroup('stock_history')
            .where('change', isGreaterThan: isEntry ? 0 : null)
            .where('change', isLessThan: isEntry ? null : 0)
            .orderBy('change', descending: isEntry)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // 🔴 ERROR HANDLING
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 50, color: Colors.orange),
                    const SizedBox(height: 16),
                    Text("Erreur", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SelectableText(snapshot.error.toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text("Aucun mouvement trouvé", style: GoogleFonts.poppins(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final int change = data['change'] ?? 0;
              final String reason = data['reason'] ?? "Mise à jour";
              final String user = data['user'] ?? "Système";
              final Timestamp? ts = data['timestamp'];
              final String dateStr = ts != null
                  ? DateFormat('dd/MM/yyyy HH:mm').format(ts.toDate())
                  : "Date inconnue";

              // 🔗 Get Product Reference
              final DocumentReference productRef = doc.reference.parent.parent!;

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isEntry ? Icons.arrow_downward : Icons.arrow_upward,
                      color: color,
                      size: 20,
                    ),
                  ),
                  // 🔹 FETCH PRODUCT NAME
                  title: FutureBuilder<DocumentSnapshot>(
                    future: productRef.get(),
                    builder: (context, productSnap) {
                      if (!productSnap.hasData) return Text("Chargement...", style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey));

                      final productData = productSnap.data!.data() as Map<String, dynamic>?;

                      // ✅ FIX: Added 'nom' (French) as the primary check
                      final productName = productData?['nom'] ?? productData?['name'] ?? "Produit Inconnu";

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
                        Text("$reason • $user", style: GoogleFonts.poppins(fontSize: 12)),
                        Text(dateStr, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  trailing: Text(
                    "${isEntry ? '+' : ''}$change",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: color,
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