// lib/screens/settings/user_role_manager_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:boitex_info_app/firebase_options.dart';

class UserRoleManagerPage extends StatefulWidget {
  const UserRoleManagerPage({super.key});

  @override
  State<UserRoleManagerPage> createState() => _UserRoleManagerPageState();
}

class _UserRoleManagerPageState extends State<UserRoleManagerPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // List of all valid roles
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
        title: const Text('Gestion des Utilisateurs'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.grey[50],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateUserDialog(context),
        label: const Text('Nouvel Utilisateur'),
        icon: const Icon(Icons.person_add),
        backgroundColor: Colors.blue,
      ),
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
                  final fullName = (data['fullName'] ?? '').toString().toLowerCase();
                  final role = (data['role'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) ||
                      fullName.contains(_searchQuery) ||
                      role.contains(_searchQuery);
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final data = users[index].data() as Map<String, dynamic>;
                    final userId = users[index].id;
                    final displayName = data['displayName'] ?? 'Inconnu';
                    final fullName = data['fullName'] ?? '';
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
                        title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (fullName.isNotEmpty)
                              Text(fullName, style: const TextStyle(color: Colors.black87)),
                            Text(role, style: TextStyle(color: _getRoleColor(role), fontWeight: FontWeight.w500, fontSize: 12)),
                            if (email.isNotEmpty)
                              Text(email, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          ],
                        ),
                        // ✅ MODIFIED: Edit icon opens the FULL edit dialog
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                          onPressed: () => _showEditUserDialog(context, userId, data),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ✅ CREATE USER DIALOG (UNCHANGED)
  void _showCreateUserDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final displayNameCtrl = TextEditingController();
    final fullNameCtrl = TextEditingController();
    String selectedRole = UserRoles.technicienST;
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Créer un Utilisateur'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: displayNameCtrl,
                        decoration: const InputDecoration(labelText: 'Display Name (ex: Athmane)', border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'Requis' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: fullNameCtrl,
                        decoration: const InputDecoration(labelText: 'Nom Complet (ex: Athmane B.)', border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'Requis' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => v!.contains('@') ? null : 'Email invalide',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passwordCtrl,
                        decoration: const InputDecoration(labelText: 'Mot de passe', border: OutlineInputBorder()),
                        obscureText: true,
                        validator: (v) => v!.length < 6 ? 'Min 6 caractères' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: const InputDecoration(labelText: 'Rôle', border: OutlineInputBorder()),
                        items: _allRoles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                        onChanged: (val) => setState(() => selectedRole = val!),
                      ),
                      if (isLoading) ...[
                        const SizedBox(height: 20),
                        const CircularProgressIndicator(),
                      ]
                    ],
                  ),
                ),
              ),
              actions: [
                if (!isLoading)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                if (!isLoading)
                  ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      setState(() => isLoading = true);
                      try {
                        FirebaseApp secondaryApp = await Firebase.initializeApp(
                          name: 'SecondaryApp-${DateTime.now().millisecondsSinceEpoch}',
                          options: DefaultFirebaseOptions.currentPlatform,
                        );

                        UserCredential userCredential = await FirebaseAuth.instanceFor(app: secondaryApp)
                            .createUserWithEmailAndPassword(
                          email: emailCtrl.text.trim(),
                          password: passwordCtrl.text.trim(),
                        );

                        final uid = userCredential.user!.uid;
                        await FirebaseFirestore.instance.collection('users').doc(uid).set({
                          'uid': uid,
                          'email': emailCtrl.text.trim(),
                          'displayName': displayNameCtrl.text.trim(),
                          'fullName': fullNameCtrl.text.trim(),
                          'role': selectedRole,
                          'createdAt': FieldValue.serverTimestamp(),
                          'notificationSettings': {
                            'interventions': true,
                            'installations': true,
                            'sav_tickets': true,
                            'missions': true,
                            'livraisons': true,
                            'requisitions': true,
                            'projects': true,
                            'stock': true,
                          }
                        });

                        await secondaryApp.delete();

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Utilisateur ${displayNameCtrl.text} créé !')),
                          );
                        }
                      } catch (e) {
                        setState(() => isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur: $e')),
                        );
                      }
                    },
                    child: const Text('Créer'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // ✅ NEW: EDIT USER DIALOG (With Delete Option)
  void _showEditUserDialog(BuildContext context, String userId, Map<String, dynamic> userData) {
    final formKey = GlobalKey<FormState>();
    final displayNameCtrl = TextEditingController(text: userData['displayName']);
    final fullNameCtrl = TextEditingController(text: userData['fullName']);
    final emailCtrl = TextEditingController(text: userData['email']);

    // Safety check for role
    String currentRole = userData['role'] ?? UserRoles.technicienST;
    if (!_allRoles.contains(currentRole)) currentRole = _allRoles.first;
    String selectedRole = currentRole;

    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Modifier / Supprimer'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: displayNameCtrl,
                        decoration: const InputDecoration(labelText: 'Display Name', border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'Requis' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: fullNameCtrl,
                        decoration: const InputDecoration(labelText: 'Nom Complet', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(labelText: 'Email (Firestore Only)', border: OutlineInputBorder()),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: const InputDecoration(labelText: 'Rôle', border: OutlineInputBorder()),
                        items: _allRoles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                        onChanged: (val) => setState(() => selectedRole = val!),
                      ),
                      const SizedBox(height: 24),
                      // 🗑️ DELETE BUTTON
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmDeleteUser(context, userId, userData['displayName']),
                          icon: const Icon(Icons.delete_forever, color: Colors.red),
                          label: const Text('SUPPRIMER L\'UTILISATEUR', style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    // Don't allow editing self role to prevent lockout
                    if (userId == FirebaseAuth.instance.currentUser?.uid && selectedRole != UserRoles.admin) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Impossible de changer votre propre rôle ici.')),
                      );
                      return;
                    }

                    await FirebaseFirestore.instance.collection('users').doc(userId).update({
                      'displayName': displayNameCtrl.text.trim(),
                      'fullName': fullNameCtrl.text.trim(),
                      'email': emailCtrl.text.trim(),
                      'role': selectedRole,
                    });

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Modifications enregistrées')),
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
      },
    );
  }

  void _confirmDeleteUser(BuildContext parentContext, String userId, String? userName) {
    showDialog(
      context: parentContext,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer "$userName" ?\n\nCela supprimera ses données de l\'application. (Le compte de connexion doit être supprimé manuellement dans Firebase Console pour une sécurité totale).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Safety: Prevent self-delete
              if (userId == FirebaseAuth.instance.currentUser?.uid) {
                Navigator.pop(context);
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(content: Text('Impossible de supprimer votre propre compte !')),
                );
                return;
              }

              await FirebaseFirestore.instance.collection('users').doc(userId).delete();

              if (mounted) {
                Navigator.pop(context); // Close confirm
                Navigator.pop(parentContext); // Close edit dialog
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  SnackBar(content: Text('Utilisateur "$userName" supprimé.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('CONFIRMER'),
          ),
        ],
      ),
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