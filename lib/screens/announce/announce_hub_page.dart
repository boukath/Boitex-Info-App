import 'package:boitex_info_app/models/channel_model.dart';
import 'package:boitex_info_app/services/announce_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'channel_chat_page.dart';

class AnnounceHubPage extends StatefulWidget {
  const AnnounceHubPage({super.key});

  @override
  State<AnnounceHubPage> createState() => _AnnounceHubPageState();
}

class _AnnounceHubPageState extends State<AnnounceHubPage> {
  final AnnounceService _announceService = AnnounceService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _currentUserRole;
  bool _isLoadingRole = true;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserRole();
  }

  /// Fetches the user's role from the 'users' collection
  Future<void> _fetchCurrentUserRole() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      setState(() {
        _isLoadingRole = false;
      });
      return;
    }

    try {
      final doc =
      await _firestore.collection('users').doc(currentUser.uid).get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          _currentUserRole = doc.data()!['role'];
          _isLoadingRole = false;
        });
      } else {
        setState(() {
          _isLoadingRole = false;
          // Handle case where user document doesn't exist, if necessary
          print('User document not found for uid: ${currentUser.uid}');
        });
      }
    } catch (e) {
      print("Error fetching user role: $e");
      setState(() {
        _isLoadingRole = false;
      });
    }
  }

  /// Your permission logic, translated to Dart
  bool _isSuperManager(String? role) {
    if (role == null) return false;
    const List<String> managerRoles = [
      'Admin',
      'PDG',
      'Responsable Administratif',
      'Responsable Commercial',
      'Responsable Technique',
      'Responsable IT',
      'Chef de Projet',
    ];
    return managerRoles.contains(role);
  }

  /// Shows the dialog to create a new channel
  void _showCreateChannelDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Créer un Salon'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du Salon',
                    hintText: '#projet-alpha',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le nom ne peut pas être vide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optionnel)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    await _announceService.createChannel(
                      nameController.text,
                      descController.text,
                    );
                    Navigator.pop(context); // Close dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Salon "${nameController.text}" créé avec succès!')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur: $e')),
                    );
                  }
                }
              },
              child: const Text('Créer'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine if the "Create" button should be shown
    final bool canCreate = !_isLoadingRole && _isSuperManager(_currentUserRole);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements 📢'),
      ),
      body: StreamBuilder<List<ChannelModel>>(
        stream: _announceService.getChannels(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: _isLoadingRole // Show a loader while checking role
                  ? const CircularProgressIndicator()
                  : const Text('No channels found. Contact an admin.'),
            );
          }

          final channels = snapshot.data!;
          // Sort channels, e.g., alphabetically
          channels.sort((a, b) => a.name.compareTo(b.name));

          return ListView.builder(
            itemCount: channels.length,
            itemBuilder: (context, index) {
              final channel = channels[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: const Icon(Icons.forum_outlined),
                  title: Text(
                    channel.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: channel.description != null
                      ? Text(channel.description!)
                      : null,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChannelChatPage(channel: channel),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      // NEW Floating Action Button
      floatingActionButton: Visibility(
        visible: canCreate,
        child: FloatingActionButton(
          onPressed: _showCreateChannelDialog,
          tooltip: 'Créer un Salon',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}