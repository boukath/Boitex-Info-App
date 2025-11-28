// lib/screens/settings/user_role_manager_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/utils/user_roles.dart';

class UserRoleManagerPage extends StatefulWidget {
  const UserRoleManagerPage({super.key});

  @override
  State<UserRoleManagerPage> createState() => _UserRoleManagerPageState();
}

class _UserRoleManagerPageState extends State<UserRoleManagerPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // List of all valid roles in your system
  final List<String> _allRoles = [
    UserRoles.admin,
    UserRoles.pdg,
    UserRoles.responsableAdministratif,
    UserRoles.responsableCommercial,
    UserRoles.responsableTechnique,
    UserRoles.responsableIT,
    UserRoles.chefDeProjet,
    UserRoles.technicienST,
    UserRoles.technicienIT,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Rôles'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher un employé...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.toLowerCase();
                });
              },
            ),
          ),

          // User List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').orderBy('displayName').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Erreur de chargement'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['displayName'] ?? '').toString().toLowerCase();
                  final role = (data['role'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) || role.contains(_searchQuery);
                }).toList();

                if (users.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('Aucun utilisateur trouvé', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final data = users[index].data() as Map<String, dynamic>;
                    final userId = users[index].id;
                    final name = data['displayName'] ?? 'Inconnu';
                    final role = data['role'] ?? 'Sans rôle';
                    final email = data['email'] ?? '';

                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getRoleColor(role),
                          child: Icon(_getRoleIcon(role), color: Colors.white, size: 20),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(role, style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w500)),
                        trailing: const Icon(Icons.edit_rounded, color: Colors.blue),
                        onTap: () => _showRoleEditor(context, userId, name, role),
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

  void _showRoleEditor(BuildContext context, String userId, String name, String currentRole) {
    String selectedRole = _allRoles.contains(currentRole) ? currentRole : _allRoles.first;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Modifier le Rôle'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Utilisateur: $name', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  const Text('Sélectionner un nouveau rôle:'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedRole,
                        isExpanded: true,
                        items: _allRoles.map((role) {
                          return DropdownMenuItem(
                            value: role,
                            child: Text(role),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => selectedRole = val);
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance.collection('users').doc(userId).update({
                  'role': selectedRole,
                });
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Rôle de $name mis à jour vers $selectedRole')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
  }

  Color _getRoleColor(String role) {
    final r = role.toLowerCase();
    if (r.contains('admin')) return Colors.red;
    if (r.contains('pdg')) return Colors.purple;
    if (r.contains('technique') || r.contains('st')) return Colors.green;
    if (r.contains('it')) return Colors.blue;
    if (r.contains('commercial')) return Colors.orange;
    return Colors.grey;
  }

  IconData _getRoleIcon(String role) {
    final r = role.toLowerCase();
    if (r.contains('admin')) return Icons.admin_panel_settings;
    if (r.contains('pdg')) return Icons.business_center;
    if (r.contains('technique') || r.contains('st')) return Icons.engineering;
    if (r.contains('it')) return Icons.computer;
    return Icons.person;
  }
}