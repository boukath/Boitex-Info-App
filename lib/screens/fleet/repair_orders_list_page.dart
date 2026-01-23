// lib/screens/fleet/repair_orders_list_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/models/repair_order.dart';
import 'package:boitex_info_app/screens/fleet/create_repair_order_page.dart';
// Note: We will build the Details Page in Step 4, so for now tapping might just show a "Coming Soon" or open the creation page in edit mode.

class RepairOrdersListPage extends StatefulWidget {
  const RepairOrdersListPage({super.key});

  @override
  State<RepairOrdersListPage> createState() => _RepairOrdersListPageState();
}

class _RepairOrdersListPageState extends State<RepairOrdersListPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 🔹 QUERY BUILDER
  Stream<QuerySnapshot> _getStream(int tabIndex) {
    final ref = FirebaseFirestore.instance.collection('repair_orders');

    switch (tabIndex) {
      case 0: // EN COURS (Draft, Scheduled, InProgress)
        return ref.where('status', whereIn: ['draft', 'scheduled', 'inProgress'])
            .orderBy('createdAt', descending: true).snapshots();
      case 1: // TERMINÉ (Completed, Archived)
        return ref.where('status', whereIn: ['completed', 'archived'])
            .orderBy('createdAt', descending: true).snapshots();
      default: // TOUS
        return ref.orderBy('createdAt', descending: true).snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("SUIVI ATELIER", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2, color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.black,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          onTap: (index) => setState(() {}), // Refresh stream on tap
          tabs: const [
            Tab(text: "EN COURS"),
            Tab(text: "HISTORIQUE"),
            Tab(text: "TOUT"),
          ],
        ),
      ),

      // 🔹 BODY: THE LIST
      body: StreamBuilder<QuerySnapshot>(
        stream: _getStream(_tabController.index),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Erreur: ${snapshot.error}"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CupertinoActivityIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final order = RepairOrder.fromFirestore(docs[index]);
              return _buildOrderCard(order);
            },
          );
        },
      ),

      // 🔹 FAB: CREATE NEW ORDER (Note: Usually you create from a Vehicle, but global create is fine too if we add vehicle selector later)
      // For now, we assume creation happens from Vehicle Profile -> CreateRepairOrderPage
    );
  }

  // ---------------------------------------------------------------------------
  // 🃏 THE CARD
  // ---------------------------------------------------------------------------
  Widget _buildOrderCard(RepairOrder order) {
    final dateLabel = order.appointmentDate != null
        ? "RDV: ${DateFormat('dd/MM/yyyy').format(order.appointmentDate!)}"
        : "Créé le: ${DateFormat('dd/MM/yyyy').format(order.createdAt)}";

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // TODO: Navigate to Step 4: RepairOrderDetailsPage
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Détails à venir (Step 4)")));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER: Status Badge & Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: order.statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: order.statusColor.withOpacity(0.5)),
                    ),
                    child: Text(
                      order.statusLabel,
                      style: TextStyle(color: order.statusColor, fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ),
                  Text(dateLabel, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 12),

              // VEHICLE INFO
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.directions_car, color: Colors.black87),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.vehicleName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      if (order.garageName != null && order.garageName!.isNotEmpty)
                        Text("📍 ${order.garageName}", style: const TextStyle(color: Colors.grey, fontSize: 12))
                      else
                        const Text("Garage non assigné", style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
                    ],
                  )
                ],
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(),
              ),

              // STATS: Items count & Cost
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.build_circle_outlined, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text("${order.items.length} Tâches", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (order.estimatedCost > 0)
                    Text(
                      "${order.estimatedCost.toStringAsFixed(0)} DZD",
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black),
                    ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_outlined, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "Aucun ordre de réparation",
            style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}