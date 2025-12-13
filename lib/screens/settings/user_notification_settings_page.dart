// lib/screens/settings/user_notification_settings_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserNotificationSettingsPage extends StatefulWidget {
  final String userId;
  final String userName;
  final String userRole;

  const UserNotificationSettingsPage({
    super.key,
    required this.userId,
    required this.userName,
    required this.userRole,
  });

  @override
  State<UserNotificationSettingsPage> createState() => _UserNotificationSettingsPageState();
}

class _UserNotificationSettingsPageState extends State<UserNotificationSettingsPage> {
  // Default: True (Receive everything unless turned off)
  Map<String, bool> _settings = {
    'interventions': true,
    'installations': true, // ✅ NEW
    'sav_tickets': true,
    'missions': true,
    'livraisons': true,    // ✅ NEW
    'requisitions': true,
    'projects': true,
    'stock': true,
    'announcements': true, // ✅ ADDED: Announcements default
  };

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (doc.exists && doc.data()!.containsKey('notificationSettings')) {
        final data = doc.data()!['notificationSettings'] as Map<String, dynamic>;
        setState(() {
          _settings = {
            'interventions': data['interventions'] ?? true,
            'installations': data['installations'] ?? true, // ✅ LOAD IT
            'sav_tickets': data['sav_tickets'] ?? true,
            'missions': data['missions'] ?? true,
            'livraisons': data['livraisons'] ?? true,       // ✅ LOAD IT
            'requisitions': data['requisitions'] ?? true,
            'projects': data['projects'] ?? true,
            'stock': data['stock'] ?? true,
            'announcements': data['announcements'] ?? true, // ✅ ADDED: Load announcements
          };
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleSetting(String key, bool value) async {
    // 1. Optimistic Update
    setState(() {
      _settings[key] = value;
    });

    // 2. Background Save
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).set({
        'notificationSettings': {
          key: value,
        }
      }, SetOptions(merge: true));
    } catch (e) {
      // Revert if error
      setState(() {
        _settings[key] = !value;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de sauvegarde: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Préférences de Notification', style: TextStyle(fontSize: 16)),
            Text(widget.userName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoCard(),
          const SizedBox(height: 20),
          const Text(
            'CANAUX DE NOTIFICATION',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          // 1. Interventions
          _buildSwitch('Interventions', 'Dépannages et maintenance', 'interventions', Icons.build_rounded, Colors.orange),

          // 2. ✅ Installations (NEW)
          _buildSwitch('Installations', 'Nouvelles installations système', 'installations', Icons.settings_input_component_rounded, Colors.teal),

          // 3. SAV
          _buildSwitch('SAV & Réparations', 'Tickets SAV et retours', 'sav_tickets', Icons.handyman_rounded, Colors.blue),

          // 4. Missions
          _buildSwitch('Missions', 'Affectations et ordres de mission', 'missions', Icons.map_rounded, Colors.purple),

          // 5. ✅ Livraisons (NEW)
          _buildSwitch('Livraisons', 'Suivi des livraisons clients', 'livraisons', Icons.local_shipping_rounded, Colors.redAccent),

          // 6. Achats
          _buildSwitch('Achats & Demandes', 'Validations de réquisitions', 'requisitions', Icons.shopping_cart_rounded, Colors.green),

          // 7. Projets
          _buildSwitch('Projets', 'Suivi des projets long terme', 'projects', Icons.folder_special_rounded, Colors.indigo),

          // 8. Stock
          _buildSwitch('Stock & Logistique', 'Mouvements de stock', 'stock', Icons.inventory_2_rounded, Colors.brown),

          // 9. ✅ Annonces (ADDED)
          _buildSwitch('Annonces & Infos', 'Messages généraux et annonces', 'announcements', Icons.campaign_rounded, Colors.deepPurple),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'En désactivant une option, ${widget.userName} ne recevra plus les notifications Push ni les alertes Web pour cette catégorie.',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitch(String title, String subtitle, String key, IconData icon, Color color) {
    final isOn = _settings[key] ?? true;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: SwitchListTile(
        value: isOn,
        activeColor: color,
        onChanged: (val) => _toggleSetting(key, val),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(left: 44),
          child: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ),
      ),
    );
  }
}