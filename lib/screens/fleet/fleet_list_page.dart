// lib/screens/fleet/fleet_list_page.dart

import 'dart:ui'; // For ImageFilter (Blur)
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/models/vehicle.dart';
import 'package:boitex_info_app/screens/fleet/vehicle_passport_page.dart';

class FleetListPage extends StatefulWidget {
  const FleetListPage({super.key});

  @override
  State<FleetListPage> createState() => _FleetListPageState();
}

class _FleetListPageState extends State<FleetListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedFilter = 'Tous'; // 'Tous', 'Critique', 'Maintenance'

  @override
  Widget build(BuildContext context) {
    // 🎨 2026 Theme: Pure White Canvas
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true, // Allow body to scroll behind header
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Fully transparent
        elevation: 0,
        toolbarHeight: 0, // We build our own floating header
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: Stack(
        children: [
          // 1. THE SHOWROOM LIST
          Positioned.fill(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('vehicles')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("Erreur système"));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CupertinoActivityIndicator(radius: 16));
                }

                final docs = snapshot.data!.docs;

                // 🔍 Filter & Search Logic
                final vehicles = docs.map((doc) => Vehicle.fromFirestore(doc)).where((v) {
                  // 1. Text Search
                  final query = _searchQuery.trim();
                  final matchesSearch = query.isEmpty ||
                      v.model.toLowerCase().contains(query) ||
                      v.plateNumber.toLowerCase().contains(query) ||
                      v.vehicleCode.toLowerCase().contains(query);

                  // 2. Category Filter
                  bool matchesFilter = true;
                  if (_selectedFilter == 'Critique') {
                    matchesFilter = v.isAssuranceCritical;
                  } else if (_selectedFilter == 'Maintenance') {
                    matchesFilter = v.needsOilChange;
                  }

                  return matchesSearch && matchesFilter;
                }).toList();

                if (vehicles.isEmpty) return _buildEmptyState();

                return ListView.separated(
                  // ✅ FIX: Increased top padding from 180 to 260 to clear the Floating Header
                  padding: const EdgeInsets.only(top: 260, left: 20, right: 20, bottom: 40),
                  physics: const BouncingScrollPhysics(),
                  itemCount: vehicles.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 24),
                  itemBuilder: (context, index) {
                    return _buildShowroomPod(context, vehicles[index]);
                  },
                );
              },
            ),
          ),

          // 2. THE FLOATING COCKPIT (Header + Search + Chips)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildFloatingHeader(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🏎️ THE SHOWROOM POD (Card)
  // ---------------------------------------------------------------------------
  Widget _buildShowroomPod(BuildContext context, Vehicle vehicle) {
    // Status Logic
    Color statusColor = const Color(0xFF34C759); // Green
    if (vehicle.isAssuranceCritical) statusColor = const Color(0xFFFF3B30); // Red
    else if (vehicle.isAssuranceWarning) statusColor = const Color(0xFFFF9500); // Orange

    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA), // Ceramic White
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06), // Soft Ambient Shadow
            blurRadius: 30,
            offset: const Offset(0, 15),
            spreadRadius: -5,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => VehiclePassportPage(vehicle: vehicle)),
            );
          },
          child: Row(
            children: [
              // 1. THE LASER STATUS LINE
              Container(
                width: 6,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
                ),
              ),

              // 2. CAR VISUAL (Left) - ✅ UPDATED FOR REAL PHOTOS
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: vehicle.photoUrl != null
                          ? Image.network(
                        vehicle.photoUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback if URL fails
                          return Center(
                            child: Icon(CupertinoIcons.car_detailed, size: 48, color: Colors.grey.shade300),
                          );
                        },
                      )
                          : Center(
                        child: Icon(CupertinoIcons.car_detailed, size: 48, color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),
              ),

              // 3. DATA HUD (Right)
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 20, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Model Name
                      Text(
                        vehicle.model,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 8),

                      // License Plate Badge
                      _buildLicensePlate(vehicle.plateNumber),

                      const Spacer(),

                      // Technical Stats (Monospace)
                      Row(
                        children: [
                          _buildTechStat(
                              "${NumberFormat('#,###').format(vehicle.currentMileage)} km",
                              Icons.speed_rounded
                          ),
                          const SizedBox(width: 12),
                          _buildTechStat(
                              "${vehicle.year}",
                              Icons.calendar_today_rounded
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLicensePlate(String plate) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black12, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        plate,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900, // Plate Font
          color: Colors.black87,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildTechStat(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 12, color: Colors.grey.shade400),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'Courier', // Monospace for tech feel
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 🚁 FLOATING COCKPIT HEADER
  // ---------------------------------------------------------------------------
  Widget _buildFloatingHeader() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), // Frosted Glass
        child: Container(
          color: Colors.white.withOpacity(0.8), // Translucent White
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 10,
            bottom: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Title Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Le Garage",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
                      letterSpacing: -1.0,
                      color: Colors.black,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.black, size: 20),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 2. Search Pill
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: "Trouver un véhicule...",
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    prefixIcon: const Icon(CupertinoIcons.search, color: Colors.black),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 3. Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildFilterChip('Tous', isActive: _selectedFilter == 'Tous'),
                    const SizedBox(width: 10),
                    _buildFilterChip('Critique', isActive: _selectedFilter == 'Critique', isAlert: true),
                    const SizedBox(width: 10),
                    _buildFilterChip('Maintenance', isActive: _selectedFilter == 'Maintenance'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, {bool isActive = false, bool isAlert = false}) {
    Color bgColor = isActive ? Colors.black : Colors.grey.shade100;
    Color textColor = isActive ? Colors.white : Colors.grey.shade600;

    if (isActive && isAlert) {
      bgColor = const Color(0xFFFF3B30); // Active Red
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilter = label);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: isActive ? null : Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: 13,
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
          Icon(CupertinoIcons.car_detailed, size: 80, color: Colors.grey.shade100),
          const SizedBox(height: 16),
          Text(
            "Garage Vide",
            style: TextStyle(
                color: Colors.grey.shade300,
                fontWeight: FontWeight.w800,
                fontSize: 20
            ),
          ),
        ],
      ),
    );
  }
}