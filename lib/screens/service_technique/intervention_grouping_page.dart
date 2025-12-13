import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

/// A generic page that queries interventions and groups them by a specific field.
/// Used for: Client -> [Stores] -> [Locations] -> Final List
class InterventionGroupingPage extends StatelessWidget {
  final String pageTitle;
  final String serviceType;
  final String groupByField; // e.g., 'storeName' or 'storeLocation'
  final List<Query> filters; // Previous filters (e.g., clientName == 'Carrefour')
  final Widget Function(String selectedValue) onSelection; // Where to go next

  const InterventionGroupingPage({
    super.key,
    required this.pageTitle,
    required this.serviceType,
    required this.groupByField,
    required this.filters,
    required this.onSelection,
  });

  @override
  Widget build(BuildContext context) {
    // Build the base query
    Query query = FirebaseFirestore.instance
        .collection('interventions')
        .where('serviceType', isEqualTo: serviceType)
        .where('status', whereIn: ['Terminé', 'Clôturé']);

    // Apply all previous hierarchy filters
    // (Note: In Firestore, you can't chain .where on a Query object easily in a list
    // without casting, so we construct the query in the StreamBuilder for simplicity
    // or pass specific values. For this specific app flow, passing parent params is safer).
    // See implementation below in "Step 2" usage.

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(pageTitle, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // We reconstruct the query based on the provided list of filters isn't strictly
    // needed if we just pass the stream, but for this generic widget,
    // let's accept the specific constraints as arguments in the StreamBuilder below.
    return const Center(child: Text("Please use the implemented StreamBuilder in the usage example"));
  }
}