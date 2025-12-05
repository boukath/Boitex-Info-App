// lib/screens/administration/universal_map_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // OpenStreetMap Engine
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart'; // ✅ 1. Import Clustering
import 'package:latlong2/latlong.dart'; // Coordinates
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:boitex_info_app/screens/commercial/prospect_details_page.dart';
import 'package:boitex_info_app/screens/administration/store_equipment_page.dart';
import 'package:boitex_info_app/models/prospect.dart';

class UniversalMapPage extends StatefulWidget {
  const UniversalMapPage({super.key});

  @override
  State<UniversalMapPage> createState() => _UniversalMapPageState();
}

class _UniversalMapPageState extends State<UniversalMapPage> {
  final MapController _mapController = MapController();

  // 📍 Default Center: Algiers
  LatLng _center = const LatLng(36.7525, 3.0420);
  double _zoom = 11.0;

  // 🔍 Filters
  bool _showProspects = true;
  bool _showClients = true;
  bool _isLoading = true;

  // 📍 Markers
  List<Marker> _markers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _locateUser();
  }

  // --- 1. GET USER LOCATION ---
  Future<void> _locateUser() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _center = LatLng(position.latitude, position.longitude);
        _mapController.move(_center, 13.0);
      });
    } catch (e) {
      debugPrint("GPS Error: $e");
    }
  }

  // --- 2. LOAD DATA ---
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    List<Marker> newMarkers = [];

    try {
      // 🔴 A. FETCH PROSPECTS
      if (_showProspects) {
        final prospectSnapshot = await FirebaseFirestore.instance
            .collection('prospects')
            .get();

        for (var doc in prospectSnapshot.docs) {
          final data = doc.data();
          if (data['latitude'] != null && data['longitude'] != null) {
            final double lat = (data['latitude'] as num).toDouble();
            final double lng = (data['longitude'] as num).toDouble();
            final prospect = Prospect.fromMap({...data, 'id': doc.id});

            newMarkers.add(
              Marker(
                point: LatLng(lat, lng),
                width: 80,
                height: 80,
                child: GestureDetector(
                  onTap: () => _showProspectInfo(prospect),
                  child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                ),
              ),
            );
          }
        }
      }

      // 🟢 B. FETCH CLIENT STORES
      if (_showClients) {
        final storeSnapshot = await FirebaseFirestore.instance
            .collectionGroup('stores')
            .get();

        for (var doc in storeSnapshot.docs) {
          final data = doc.data();
          if (data['latitude'] != null && data['longitude'] != null) {
            final double lat = (data['latitude'] as num).toDouble();
            final double lng = (data['longitude'] as num).toDouble();

            final String clientId = doc.reference.parent.parent?.id ?? '';

            newMarkers.add(
              Marker(
                point: LatLng(lat, lng),
                width: 80,
                height: 80,
                child: GestureDetector(
                  onTap: () => _showStoreInfo(doc.id, data, clientId),
                  child: const Icon(Icons.store, color: Colors.teal, size: 36),
                ),
              ),
            );
          }
        }
      }

      if (mounted) {
        setState(() {
          _markers = newMarkers;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading map data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 3. BOTTOM SHEETS (INFO WINDOWS) ---
  void _showProspectInfo(Prospect p) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_pin_circle, color: Colors.red, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("PROSPECT", style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold, fontSize: 12)),
                      Text(p.companyName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.flag),
              title: Text("Statut: ${p.status}"),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: Text("Commercial: ${p.authorName}"),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.visibility),
                  label: const Text("Détails"),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProspectDetailsPage(prospect: p))),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.directions),
                  label: const Text("GPS"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  onPressed: () => _launchMaps(p.latitude!, p.longitude!),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _showStoreInfo(String storeId, Map<String, dynamic> data, String clientId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.store_mall_directory, color: Colors.teal, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("CLIENT (MAGASIN)", style: TextStyle(color: Colors.teal[700], fontWeight: FontWeight.bold, fontSize: 12)),
                      Text(data['name'] ?? 'Magasin', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(data['location'] ?? 'Adresse inconnue'),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.settings_remote),
                  label: const Text("Équipements"),
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => StoreEquipmentPage(
                            clientId: clientId,
                            storeId: storeId,
                            storeName: data['name'] ?? 'Magasin'
                        ))
                    );
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.directions),
                  label: const Text("GPS"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  onPressed: () {
                    if (data['latitude'] != null && data['longitude'] != null) {
                      _launchMaps(data['latitude'], data['longitude']);
                    }
                  },
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Future<void> _launchMaps(double lat, double lng) async {
    final url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🗺️ MAP LAYER WITH CLUSTERING
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: _zoom,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.boitexinfo.app',
              ),

              // ✅ 2. REPLACED MarkerLayer WITH MarkerClusterLayerWidget
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 45,
                  size: const Size(40, 40),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(50),
                  maxZoom: 15, // Stops clustering when you zoom in close
                  markers: _markers,

                  // How the "Cluster Circle" looks
                  builder: (context, markers) {
                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF667EEA), // Your App Blue
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          markers.length.toString(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // 🔙 BACK BUTTON
          Positioned(
            top: 50,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // 🎛️ FILTER CHIPS
          Positioned(
            top: 50,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FilterChip(
                  label: const Text("Prospects (🔴)"),
                  selected: _showProspects,
                  checkmarkColor: Colors.white,
                  selectedColor: Colors.redAccent,
                  labelStyle: TextStyle(color: _showProspects ? Colors.white : Colors.black),
                  onSelected: (val) {
                    setState(() => _showProspects = val);
                    _loadData();
                  },
                ),
                const SizedBox(height: 8),
                FilterChip(
                  label: const Text("Clients (🟢)"),
                  selected: _showClients,
                  checkmarkColor: Colors.white,
                  selectedColor: Colors.teal,
                  labelStyle: TextStyle(color: _showClients ? Colors.white : Colors.black),
                  onSelected: (val) {
                    setState(() => _showClients = val);
                    _loadData();
                  },
                ),
              ],
            ),
          ),

          // 📍 "LOCATE ME" BUTTON
          Positioned(
            bottom: 30,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.blue,
              child: const Icon(Icons.my_location, color: Colors.white),
              onPressed: _locateUser,
            ),
          ),

          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}