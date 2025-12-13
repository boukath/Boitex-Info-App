import 'dart:ui';
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

  void _showCreateChannelDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogBackgroundColor: Colors.black.withOpacity(0.8),
            textTheme: const TextTheme(
              titleLarge:
              TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              bodyLarge: TextStyle(color: Colors.white),
              bodyMedium: TextStyle(color: Colors.white70),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white, width: 2),
              ),
            ),
          ),
          child: AlertDialog(
            backgroundColor: Colors.transparent,
            contentPadding: EdgeInsets.zero,
            content: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Créer un Salon',
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: nameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Nom du Salon',
                              hintText: '#projet-alpha',
                              labelStyle: TextStyle(color: Colors.white70),
                              hintStyle: TextStyle(color: Colors.white54),
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
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Description (Optionnel)',
                              labelStyle: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child:
                const Text('Annuler', style: TextStyle(color: Colors.white)),
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
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: Colors.green.withOpacity(0.8),
                            content: Text(
                                'Salon "${nameController.text}" créé avec succès!',
                                style: const TextStyle(color: Colors.white)),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: Colors.red.withOpacity(0.8),
                            content: Text('Erreur: $e',
                                style: const TextStyle(color: Colors.white)),
                          ),
                        );
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Créer',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  // ✅ --- START: NEW DIALOG METHODS ---

  /// Shows Edit/Delete options when long-pressing a channel
  void _showChannelOptions(ChannelModel channel) {
    // Show a simple dialog with two options
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text('Options pour "${channel.name}"',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF1E1E2A),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
          children: [
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context); // Close this dialog
                _showEditChannelDialog(channel); // Open edit dialog
              },
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              child: const Row(
                children: [
                  Icon(Icons.edit, color: Colors.blue),
                  SizedBox(width: 16),
                  Text('Modifier',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context); // Close this dialog
                _showDeleteConfirmationDialog(channel); // Open delete confirmation
              },
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              child: const Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 16),
                  Text('Supprimer',
                      style: TextStyle(color: Colors.red, fontSize: 16)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Shows the dialog to edit a channel (pre-fills existing data)
  void _showEditChannelDialog(ChannelModel channel) {
    // Pre-fill controllers with the channel's current data
    final TextEditingController nameController =
    TextEditingController(text: channel.name);
    final TextEditingController descController =
    TextEditingController(text: channel.description ?? '');
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        // We re-use the same theme as your create dialog
        return Theme(
          data: Theme.of(context).copyWith(
            dialogBackgroundColor: Colors.black.withOpacity(0.8),
            textTheme: const TextTheme(
              titleLarge:
              TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              bodyLarge: TextStyle(color: Colors.white),
              bodyMedium: TextStyle(color: Colors.white70),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white, width: 2),
              ),
            ),
          ),
          child: AlertDialog(
            backgroundColor: Colors.transparent,
            contentPadding: EdgeInsets.zero,
            content: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Modifier le Salon', // Title changed
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: nameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Nom du Salon',
                              hintText: '#projet-alpha',
                              labelStyle: TextStyle(color: Colors.white70),
                              hintStyle: TextStyle(color: Colors.white54),
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
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Description (Optionnel)',
                              labelStyle: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child:
                const Text('Annuler', style: TextStyle(color: Colors.white)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    try {
                      // Call the new updateChannel service method
                      await _announceService.updateChannel(
                        channel.id, // Pass the channel ID
                        nameController.text,
                        descController.text,
                      );
                      Navigator.pop(context);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: Colors.green.withOpacity(0.8),
                            content: Text(
                                'Salon "${nameController.text}" mis à jour!',
                                style: const TextStyle(color: Colors.white)),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: Colors.red.withOpacity(0.8),
                            content: Text('Erreur: $e',
                                style: const TextStyle(color: Colors.white)),
                          ),
                        );
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Sauvegarder', // Button text changed
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Shows a final confirmation before deleting a channel
  void _showDeleteConfirmationDialog(ChannelModel channel) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: Text(
              'Voulez-vous vraiment supprimer le salon "${channel.name}" ?\n\nTOUS les messages de ce salon seront supprimés définitivement. Cette action est irréversible.'),
          backgroundColor: const Color(0xFF1E1E2A),
          titleTextStyle: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          contentTextStyle:
          const TextStyle(color: Colors.white70, fontSize: 16),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  Navigator.pop(context); // Close the dialog
                  await _announceService.deleteChannel(channel.id); // Call delete

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.green.withOpacity(0.8),
                        content: Text('Salon "${channel.name}" supprimé.',
                            style: const TextStyle(color: Colors.white)),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.red.withOpacity(0.8),
                        content: Text('Erreur: $e',
                            style: const TextStyle(color: Colors.white)),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );
  }

  // ✅ --- END: NEW DIALOG METHODS ---

  @override
  Widget build(BuildContext context) {
    final bool canCreate = !_isLoadingRole && _isSuperManager(_currentUserRole);
    final width = MediaQuery.of(context).size.width;
    final bool isWeb = width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text(
          'Announcements',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        shadowColor: Colors.black.withOpacity(0.3),
        scrolledUnderElevation: 4,
        surfaceTintColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
              Color(0xFF0F3460),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child:
          isWeb ? _buildWebLayout(canCreate) : _buildMobileLayout(canCreate),
        ),
      ),
      floatingActionButton: Visibility(
        visible: canCreate,
        child: FloatingActionButton(
          onPressed: _showCreateChannelDialog,
          tooltip: 'Créer un Salon',
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 4,
          // Removed unsupported `shadowColor` on FAB
          child: const Icon(Icons.add, size: 28),
        ),
      ),
    );
  }

  // ✅ UPDATED SIGNATURE TO ACCEPT `canCreate`
  Widget _buildGlassCard(ChannelModel channel, bool canCreate,
      {bool isWeb = false}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isWeb ? 24 : 20),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isWeb ? 24 : 20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(isWeb ? 24 : 20),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChannelChatPage(channel: channel),
                  ),
                );
              },
              // ✅ START: ADDED LONG PRESS FOR ADMINS
              onLongPress: canCreate
                  ? () {
                _showChannelOptions(channel);
              }
                  : null,
              // ✅ END: ADDED LONG PRESS
              hoverColor: isWeb ? Colors.white.withOpacity(0.1) : null,
              child: Padding(
                padding: EdgeInsets.all(isWeb ? 20 : 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.forum_outlined,
                        color: Colors.white,
                        size: isWeb ? 32 : 28, // non-const Icon for runtime size
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            channel.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: isWeb ? 18 : 16,
                            ),
                          ),
                          if (channel.description != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                channel.description!,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: isWeb ? 14 : 13,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebLayout(bool canCreate) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Text(
                'Salons d\'Annonces',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: StreamBuilder<List<ChannelModel>>(
                  stream: _announceService.getChannels(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(color: Colors.white));
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: _isLoadingRole
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                          'Aucun salon trouvé. Contactez un administrateur.',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 18),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    final channels = List<ChannelModel>.from(snapshot.data!)
                      ..sort((a, b) => a.name.compareTo(b.name));

                    return GridView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisExtent: 140,
                        crossAxisSpacing: 24,
                        mainAxisSpacing: 24,
                        childAspectRatio: 3,
                      ),
                      itemCount: channels.length,
                      itemBuilder: (context, index) {
                        final channel = channels[index];
                        // ✅ UPDATED: Pass `canCreate`
                        return _buildGlassCard(channel, canCreate, isWeb: true);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(bool canCreate) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
      child: Column(
        children: [
          const Text(
            'Salons d\'Annonces',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<List<ChannelModel>>(
              stream: _announceService.getChannels(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: Colors.white));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: _isLoadingRole
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      'Aucun salon trouvé. Contactez un administrateur.',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                final channels = List<ChannelModel>.from(snapshot.data!)
                  ..sort((a, b) => a.name.compareTo(b.name));

                return ListView.separated(
                  itemCount: channels.length,
                  separatorBuilder: (context, index) =>
                  const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final channel = channels[index];
                    // ✅ UPDATED: Pass `canCreate`
                    return _buildGlassCard(channel, canCreate, isWeb: false);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}