// lib/screens/settings/email_settings_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class EmailSettingsPage extends StatefulWidget {
  const EmailSettingsPage({super.key});

  @override
  State<EmailSettingsPage> createState() => _EmailSettingsPageState();
}

class _EmailSettingsPageState extends State<EmailSettingsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;

  // Local state for the lists
  List<String> _interventionTechEmails = [];
  List<String> _interventionItEmails = [];
  List<String> _savTechEmails = []; // Split SAV
  List<String> _savItEmails = [];   // Split SAV
  List<String> _installationTechEmails = [];
  List<String> _installationItEmails = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final doc = await _firestore.collection('settings').doc('email_config').get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _interventionTechEmails = List<String>.from(data['intervention_cc_tech'] ?? []);
          _interventionItEmails = List<String>.from(data['intervention_cc_it'] ?? []);

          _savTechEmails = List<String>.from(data['sav_cc_tech'] ?? []);
          _savItEmails = List<String>.from(data['sav_cc_it'] ?? []);

          _installationTechEmails = List<String>.from(data['installation_cc_tech'] ?? []);
          _installationItEmails = List<String>.from(data['installation_cc_it'] ?? []);
        });
      }
    } catch (e) {
      debugPrint("Error loading email settings: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur de chargement: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      await _firestore.collection('settings').doc('email_config').set({
        'intervention_cc_tech': _interventionTechEmails,
        'intervention_cc_it': _interventionItEmails,

        'sav_cc_tech': _savTechEmails,
        'sav_cc_it': _savItEmails,

        'installation_cc_tech': _installationTechEmails,
        'installation_cc_it': _installationItEmails,

        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Configuration email sauvegardée avec succès"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur de sauvegarde: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ OPTION 1: Select from Firestore Users
  void _showUserSelectionDialog(List<String> currentList) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Sélectionner un utilisateur", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text("Erreur de chargement"));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              final allUsers = snapshot.data!.docs;

              final availableUsers = allUsers.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return {
                  'email': data['email'] as String? ?? '',
                  'displayName': data['displayName'] as String? ?? 'Utilisateur',
                  'role': data['role'] as String? ?? 'N/A',
                };
              }).where((u) {
                final email = u['email'] as String;
                return email.contains('@') && !currentList.contains(email);
              }).toList();

              availableUsers.sort((a, b) {
                final nameA = (a['displayName'] as String).toLowerCase();
                final nameB = (b['displayName'] as String).toLowerCase();
                return nameA.compareTo(nameB);
              });

              if (availableUsers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline, size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text("Tous les utilisateurs sont déjà ajoutés.", textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.grey)),
                    ],
                  ),
                );
              }

              return ListView.separated(
                itemCount: availableUsers.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final user = availableUsers[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        (user['displayName'] as String)[0].toUpperCase(),
                        style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(user['displayName'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(user['email'] as String, style: const TextStyle(fontSize: 12)),
                    onTap: () {
                      setState(() => currentList.add(user['email'] as String));
                      Navigator.pop(context);
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler"))],
      ),
    );
  }

  // ✅ OPTION 2: Manually Type Email
  void _showManualEntryDialog(List<String> currentList) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Saisir un email", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Ajoutez une adresse email externe ou spécifique."),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: "Adresse Email",
                hintText: "ex: partenaire@externe.com",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () {
              final email = controller.text.trim();
              if (email.contains('@') && email.contains('.')) {
                if (!currentList.contains(email)) {
                  setState(() => currentList.add(email));
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cet email est déjà dans la liste.")));
                }
              }
            },
            child: const Text("Ajouter"),
          ),
        ],
      ),
    );
  }

  void _removeEmail(List<String> list, int index) {
    setState(() => list.removeAt(index));
  }

  Widget _buildEmailSection(String title, List<String> emailList, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // 👤 Button 1: Select User
                IconButton(
                  icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.blue),
                  onPressed: () => _showUserSelectionDialog(emailList),
                  tooltip: "Sélectionner un utilisateur existant",
                ),

                // ⌨️ Button 2: Manual Entry (NEW)
                IconButton(
                  icon: const Icon(Icons.keyboard_alt_outlined, color: Colors.orange), // Edit icon
                  onPressed: () => _showManualEntryDialog(emailList),
                  tooltip: "Saisir manuellement",
                ),
              ],
            ),
            const Divider(),
            if (emailList.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text("Aucun email configuré (liste vide)", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
              ),
            ...emailList.asMap().entries.map((entry) {
              int idx = entry.key;
              String email = entry.value;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.email_outlined, size: 20, color: Colors.grey),
                title: Text(email, style: const TextStyle(fontWeight: FontWeight.w500)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _removeEmail(emailList, idx),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Configuration Emails (CC)", style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.blue),
            onPressed: _isLoading ? null : _saveSettings,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildEmailSection("Interventions (Technique)", _interventionTechEmails, Icons.build, Colors.orange),
            _buildEmailSection("Interventions (IT)", _interventionItEmails, Icons.computer, Colors.purple),

            const SizedBox(height: 10),
            const Divider(thickness: 2),
            const SizedBox(height: 10),

            _buildEmailSection("SAV (Technique)", _savTechEmails, Icons.handyman, Colors.blue),
            _buildEmailSection("SAV (IT)", _savItEmails, Icons.developer_board, Colors.indigo),

            const SizedBox(height: 10),
            const Divider(thickness: 2),
            const SizedBox(height: 10),

            _buildEmailSection("Installations (Technique)", _installationTechEmails, Icons.settings_input_component, Colors.green),
            _buildEmailSection("Installations (IT)", _installationItEmails, Icons.router, Colors.lightGreen),

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save),
                label: const Text("ENREGISTRER LA CONFIGURATION"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2962FF),
                  foregroundColor: Colors.white,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}