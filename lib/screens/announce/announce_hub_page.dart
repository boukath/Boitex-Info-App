import 'package:boitex_info_app/models/channel_model.dart';
import 'package:boitex_info_app/services/announce_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'channel_chat_page.dart';

class AnnounceHubPage extends StatefulWidget {
  const AnnounceHubPage({super.key});
  @override
  State createState() => _AnnounceHubPageState();
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
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingRole = false;
      });
    }
  }

  bool _isSuperManager(String? role) {
    if (role == null) return false;
    const List managerRoles = [
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
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Salon "${nameController.text}" créé avec succès!')),
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
    final bool canCreate = !_isLoadingRole && _isSuperManager(_currentUserRole);
    final width = MediaQuery.of(context).size.width;
    final bool isWeb = width > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements 📢'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF3B82F6),
              Color(0xFF1E40AF),
              Color(0xFF1E3A8A),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: isWeb ? _buildWebLayout(canCreate) : _buildMobileLayout(canCreate),
        ),
      ),
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

  Widget _buildWebLayout(bool canCreate) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
          child: StreamBuilder<List<ChannelModel>>(
            stream: _announceService.getChannels(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: _isLoadingRole
                      ? const CircularProgressIndicator()
                      : const Text('No channels found. Contact an admin.',
                      style: TextStyle(color: Colors.white, fontSize: 22)),
                );
              }
              final channels = snapshot.data!..sort((a, b) => a.name.compareTo(b.name));
              return GridView.builder(
                padding: EdgeInsets.symmetric(vertical: 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisExtent: 120,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                ),
                itemCount: channels.length,
                itemBuilder: (context, index) {
                  final channel = channels[index];
                  return Card(
                    color: Colors.white.withOpacity(0.12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: ListTile(
                      leading: const Icon(Icons.forum_outlined, color: Colors.white, size: 32),
                      title: Text(
                        channel.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
                      ),
                      subtitle: channel.description != null
                          ? Text(channel.description!, style: const TextStyle(color: Colors.white70))
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
        ),
      ),
    );
  }

  Widget _buildMobileLayout(bool canCreate) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      child: StreamBuilder<List<ChannelModel>>(
        stream: _announceService.getChannels(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: _isLoadingRole
                  ? const CircularProgressIndicator()
                  : const Text('No channels found. Contact an admin.',
                  style: TextStyle(color: Colors.white)),
            );
          }
          final channels = snapshot.data!..sort((a, b) => a.name.compareTo(b.name));
          return ListView.builder(
            itemCount: channels.length,
            itemBuilder: (context, index) {
              final channel = channels[index];
              return Card(
                color: Colors.white.withOpacity(0.13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: const Icon(Icons.forum_outlined, color: Colors.white, size: 28),
                  title: Text(channel.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  subtitle: channel.description != null
                      ? Text(channel.description!, style: const TextStyle(color: Colors.white70))
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
    );
  }
}
