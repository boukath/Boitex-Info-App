import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:boitex_info_app/models/channel_model.dart';
import 'package:boitex_info_app/services/announce_service.dart';
import 'channel_chat_page.dart';

class AnnounceHubPage extends StatefulWidget {
  const AnnounceHubPage({super.key});

  @override
  State<AnnounceHubPage> createState() => _AnnounceHubPageState();
}

class _AnnounceHubPageState extends State<AnnounceHubPage>
    with SingleTickerProviderStateMixin {
  final AnnounceService _announceService = AnnounceService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _currentUserRole;
  bool _isLoadingRole = true;

  // Animation controller for the breathing background gradient
  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserRole();

    // 2026 Premium Animated Background Setup
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentUserRole() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => _isLoadingRole = false);
      return;
    }

    try {
      final doc =
      await _firestore.collection('users').doc(currentUser.uid).get();
      if (doc.exists && doc.data() != null) {
        if (mounted) {
          setState(() {
            _currentUserRole = doc.data()!['role'];
            _isLoadingRole = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingRole = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRole = false);
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

  // ==========================================
  // 🌟 VISION OS / iOS 2026 STYLE DIALOGS
  // ==========================================

  void _showCreateOrEditDialog({ChannelModel? existingChannel}) {
    final isEditing = existingChannel != null;
    final TextEditingController nameController =
    TextEditingController(text: existingChannel?.name ?? '');
    final TextEditingController descController =
    TextEditingController(text: existingChannel?.description ?? '');
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width > 600 ? 500 : MediaQuery.of(context).size.width * 0.9,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 30, spreadRadius: 5),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    color: Colors.white.withOpacity(0.05),
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isEditing ? 'Modifier le Salon' : 'Nouveau Salon',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isEditing ? 'Mettez à jour les informations du salon.' : 'Créez un nouvel espace de discussion.',
                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 15),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          _buildPremiumTextField(
                            controller: nameController,
                            label: 'Nom du Salon',
                            icon: Icons.tag,
                            validator: (val) => val == null || val.trim().isEmpty ? 'Requis' : null,
                          ),
                          const SizedBox(height: 16),
                          _buildPremiumTextField(
                            controller: descController,
                            label: 'Description (Optionnel)',
                            icon: Icons.description_outlined,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: Text('Annuler', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16, fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    if (formKey.currentState!.validate()) {
                                      HapticFeedback.mediumImpact();
                                      try {
                                        if (isEditing) {
                                          await _announceService.updateChannel(existingChannel.id, nameController.text, descController.text);
                                        } else {
                                          await _announceService.createChannel(nameController.text, descController.text);
                                        }
                                        if (mounted) {
                                          Navigator.pop(context);
                                          _showPremiumToast(isEditing ? 'Salon mis à jour' : 'Salon créé avec succès');
                                        }
                                      } catch (e) {
                                        if (mounted) _showPremiumToast('Erreur: $e', isError: true);
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: Text(isEditing ? 'Enregistrer' : 'Créer', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutBack)),
            child: child,
          ),
        );
      },
    );
  }

  void _showChannelOptions(ChannelModel channel) {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                color: Colors.black.withOpacity(0.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
                    ),
                    _buildOptionTile(
                      icon: Icons.edit_rounded,
                      title: 'Modifier le salon',
                      color: Colors.white,
                      onTap: () {
                        Navigator.pop(context);
                        _showCreateOrEditDialog(existingChannel: channel);
                      },
                    ),
                    Divider(color: Colors.white.withOpacity(0.1), indent: 24, endIndent: 24),
                    _buildOptionTile(
                      icon: Icons.delete_outline_rounded,
                      title: 'Supprimer',
                      color: Colors.redAccent,
                      onTap: () {
                        Navigator.pop(context);
                        _showDeleteConfirmationDialog(channel);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionTile({required IconData icon, required String title, required Color color, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(title, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.3)),
      onTap: onTap,
    );
  }

  void _showDeleteConfirmationDialog(ChannelModel channel) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 340,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3), width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    color: Colors.black.withOpacity(0.6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 40),
                        ),
                        const SizedBox(height: 24),
                        const Text('Supprimer ce salon ?', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Text(
                          'Tous les messages de "${channel.name}" seront définitivement perdus. Action irréversible.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 15, height: 1.4),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Annuler', style: TextStyle(color: Colors.white, fontSize: 16)),
                              ),
                            ),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  try {
                                    Navigator.pop(context);
                                    await _announceService.deleteChannel(channel.id);
                                    if (mounted) _showPremiumToast('Salon supprimé');
                                  } catch (e) {
                                    if (mounted) _showPremiumToast('Erreur: $e', isError: true);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: const Text('Supprimer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPremiumTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: maxLines == 1 ? Icon(icon, color: Colors.white.withOpacity(0.5)) : null,
        filled: true,
        fillColor: Colors.black.withOpacity(0.2),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.5))),
      ),
    );
  }

  void _showPremiumToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: isError ? Colors.redAccent.withOpacity(0.9) : const Color(0xFF1E1E1E).withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 5))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15))),
            ],
          ),
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 30, left: 20, right: 20),
      ),
    );
  }

  // ==========================================
  // 🌟 BUILD METHOD & LAYOUTS
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final bool canCreate = !_isLoadingRole && _isSuperManager(_currentUserRole);

    return Scaffold(
      backgroundColor: Colors.black, // Deep black base
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Annonces',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: -0.5),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Stack(
        children: [
          // 1. Ambient Animated Background
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(const Color(0xFF1A0B2E), const Color(0xFF0F2027), _bgController.value)!,
                      Color.lerp(const Color(0xFF0F2027), const Color(0xFF203A43), _bgController.value)!,
                      Color.lerp(const Color(0xFF2C5364), const Color(0xFF1A0B2E), _bgController.value)!,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              );
            },
          ),

          // 2. Main Content
          SafeArea(
            bottom: false,
            child: StreamBuilder<List<ChannelModel>>(
              stream: _announceService.getChannels(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: _isLoadingRole
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.forum_outlined, size: 64, color: Colors.white.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun salon disponible',
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 18, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                }

                final channels = List<ChannelModel>.from(snapshot.data!)
                  ..sort((a, b) => a.name.compareTo(b.name));

                return LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 900) {
                      return _buildWebGrid(channels, canCreate);
                    }
                    return _buildMobileList(channels, canCreate);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Visibility(
        visible: canCreate,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16, right: 8),
          child: FloatingActionButton.extended(
            onPressed: () {
              HapticFeedback.lightImpact();
              _showCreateOrEditDialog();
            },
            backgroundColor: Colors.white.withOpacity(0.15),
            elevation: 0,
            hoverElevation: 0,
            highlightElevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
              side: BorderSide(color: Colors.white.withOpacity(0.3), width: 1),
            ),
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text('Nouveau Salon', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          ),
        ),
      ),
    );
  }

  Widget _buildWebGrid(List<ChannelModel> channels, bool canCreate) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: GridView.builder(
          padding: const EdgeInsets.all(32),
          physics: const BouncingScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 400,
            mainAxisExtent: 160,
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
          ),
          itemCount: channels.length,
          itemBuilder: (context, index) {
            return _PremiumGlassCard(
              channel: channels[index],
              canCreate: canCreate,
              onOptionsTap: () => _showChannelOptions(channels[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMobileList(List<ChannelModel> channels, bool canCreate) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: channels.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return _PremiumGlassCard(
          channel: channels[index],
          canCreate: canCreate,
          onOptionsTap: () => _showChannelOptions(channels[index]),
        );
      },
    );
  }
}

// ==========================================
// 🌟 HYPER-REALISTIC GLASSMORPHISM CARD
// ==========================================
class _PremiumGlassCard extends StatefulWidget {
  final ChannelModel channel;
  final bool canCreate;
  final VoidCallback onOptionsTap;

  const _PremiumGlassCard({
    required this.channel,
    required this.canCreate,
    required this.onOptionsTap,
  });

  @override
  State<_PremiumGlassCard> createState() => _PremiumGlassCardState();
}

class _PremiumGlassCardState extends State<_PremiumGlassCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = _isPressed ? 0.96 : (_isHovered ? 1.02 : 1.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ChannelChatPage(channel: widget.channel)),
          );
        },
        onTapCancel: () => setState(() => _isPressed = false),
        onLongPress: widget.canCreate ? widget.onOptionsTap : null,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withOpacity(_isHovered ? 0.4 : 0.15),
                width: 1.5,
              ),
              boxShadow: [
                if (_isHovered)
                  BoxShadow(color: Colors.white.withOpacity(0.05), blurRadius: 30, spreadRadius: 5)
                else
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.15),
                        Colors.white.withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Animated Icon Container
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.white.withOpacity(0.3), Colors.white.withOpacity(0.1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
                          ],
                        ),
                        child: const Icon(Icons.tag_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 20),
                      // Text Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.channel.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                fontSize: 20,
                                letterSpacing: -0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.channel.description != null && widget.channel.description!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  widget.channel.description!,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Options Button for Admins
                      if (widget.canCreate)
                        IconButton(
                          icon: Icon(Icons.more_horiz_rounded, color: Colors.white.withOpacity(0.5)),
                          onPressed: widget.onOptionsTap,
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}