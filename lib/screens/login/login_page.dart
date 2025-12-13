// lib/screens/login/login_page.dart

import 'package:boitex_info_app/models/saved_user.dart';
import 'package:boitex_info_app/services/session_service.dart';
import 'package:boitex_info_app/utils/nav_key.dart';
import 'package:boitex_info_app/widgets/pin_setup_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Services
  final _sessionService = SessionService();

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // State
  bool _passwordVisible = false;
  bool _isLoading = false;
  List<SavedUser> _savedUsers = [];
  bool _showQuickLogin = false; // Toggle between Quick Grid and Standard Form

  @override
  void initState() {
    super.initState();
    _loadSavedUsers();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 🔄 1. Load Saved Users on Startup
  Future<void> _loadSavedUsers() async {
    final users = await _sessionService.getSavedUsers();
    if (mounted) {
      setState(() {
        _savedUsers = users;
        // If we have saved users, show the Quick Login Grid by default
        _showQuickLogin = users.isNotEmpty;
      });
    }
  }

  // 🔐 2. Standard Login Logic (Email/Pass)
  Future<void> _signIn() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // A. Authenticate with Firebase
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      ).timeout(const Duration(seconds: 15));

      // B. PRO LOGIC: Check if this user needs to set up a PIN
      // We use navigatorKey because AuthGate might dispose this widget immediately!
      final user = userCredential.user;
      if (user != null) {
        // ⚡️ CRITICAL FIX: Capture data BEFORE the page closes
        final password = _passwordController.text.trim();
        final isAlreadySaved = _savedUsers.any((u) => u.uid == user.uid);

        if (!isAlreadySaved) {
          // ✅ Wait 1 second for Home Page & Notification Popup to settle
          // We do NOT check 'if (mounted)' here because LoginPage will be closed by AuthGate!
          Future.delayed(const Duration(milliseconds: 1000), () {
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (context) => PinSetupDialog(
                  firebaseUser: user,
                  password: password,
                ),
              ),
            );
          });
        }
      }

    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🔑 NEW: Password Reset Logic
  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez entrer votre email pour réinitialiser le mot de passe.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Email de réinitialisation envoyé. Vérifiez votre boîte mail.'),
              backgroundColor: Colors.green),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: ${e.message}"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 🛠️ Helper: Offer PIN Setup if not already saved
  Future<void> _checkAndOfferPinSetup(User user, String password) async {
    // Check if user is already in our local list
    final isAlreadySaved = _savedUsers.any((u) => u.uid == user.uid);

    if (!isAlreadySaved) {
      // Show the setup dialog ON TOP of everything (using global key)
      // This ensures it persists even if AuthGate swaps the page to Home
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => PinSetupDialog(
            firebaseUser: user,
            password: password,
          ),
        ),
      );
    }
  }

  // ⚡️ 3. Quick Login Logic (PIN)
  Future<void> _onQuickUserTap(SavedUser user) async {
    // Show a simple PIN entry dialog
    final pin = await showDialog<String>(
      context: context,
      builder: (context) => _PinEntryDialog(userName: user.displayName),
    );

    if (pin != null && pin.length == 4) {
      setState(() => _isLoading = true);

      // Verify PIN securely
      final storedPassword = await _sessionService.verifyPinAndGetPassword(user.uid, pin);

      if (storedPassword != null) {
        // PIN Correct -> Auto-Login with stored password
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: user.email,
            password: storedPassword,
          );
          // Success! AuthGate takes over.
        } catch (e) {
          if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Erreur de connexion (Mot de passe expiré ?)")),
            );
          }
        }
      } else {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Code PIN incorrect"), backgroundColor: Colors.red),
          );
        }
      }

      if(mounted) setState(() => _isLoading = false);
    }
  }

  // 🗑️ Helper: Logic to confirm deletion
  Future<void> _confirmRemoveUser(SavedUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Oublier ce compte ?"),
        content: Text(
            "Voulez-vous retirer ${user.displayName} de cet appareil ?\n(Le code PIN sera supprimé)"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Retirer", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _sessionService.removeUser(user.uid);
      await _loadSavedUsers(); // Refresh the list to remove the bubble

      // If no users left, switch back to standard form
      if (_savedUsers.isEmpty) {
        setState(() => _showQuickLogin = false);
      }
    }
  }

  void _handleAuthError(FirebaseAuthException e) {
    String message = 'Erreur inconnue';
    if (e.code == 'user-not-found' || e.code == 'wrong-password') {
      message = 'Identifiants incorrects.';
    } else if (e.code == 'network-request-failed') {
      message = 'Problème de connexion internet.';
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWebWide = kIsWeb && MediaQuery.of(context).size.width >= 900;
    if (isWebWide) {
      return _buildWebLayout();
    } else {
      return _buildMobileLayout();
    }
  }

  // -------------------------------------------------------------------------
  // 🎨 WEB LAYOUT
  // -------------------------------------------------------------------------
  Widget _buildWebLayout() {
    return Scaffold(
      body: Row(
        children: [
          // Left Branding
          Expanded(
            flex: 5,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6366f1), Color(0xFF8b5cf6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/boitex_logo.png', height: 280, fit: BoxFit.contain),
                    const SizedBox(height: 40),
                    const Text("BOITEX INFO", style: TextStyle(fontSize: 56, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
          // Right Form
          Expanded(
            flex: 4,
            child: Container(
              color: Colors.white,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 80),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: _showQuickLogin ? _buildQuickLoginView() : _buildStandardLoginForm(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // 🎨 MOBILE LAYOUT
  // -------------------------------------------------------------------------
  Widget _buildMobileLayout() {
    return Scaffold(
      body: Stack(
        children: [
          ClipPath(
            clipper: WaveClipper(),
            child: Container(height: 280, color: const Color(0xFF8A77F0)),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Image.asset('assets/boitex_logo.png', height: 120),
                  const SizedBox(height: 40),

                  Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      // Toggle Content based on Mode
                      child: _showQuickLogin ? _buildQuickLoginView() : _buildStandardLoginForm(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // 🧩 WIDGETS: FORM vs QUICK LOGIN
  // -------------------------------------------------------------------------

  Widget _buildQuickLoginView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          "Qui se connecte ?",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),

        // Grid of Avatars
        Wrap(
          spacing: 20,
          runSpacing: 20,
          alignment: WrapAlignment.center,
          children: _savedUsers.map((user) {
            return Stack(
              clipBehavior: Clip.none, // Allows the X button to overlap the edge
              children: [
                // 1. The Avatar Card
                GestureDetector(
                  onTap: () => _onQuickUserTap(user),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.blue.shade100,
                        backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                        child: user.photoUrl == null
                            ? Text(
                          user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        )
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        user.userRole,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),

                // 2. The Delete "X" Button (Top Right)
                Positioned(
                  top: -5,
                  right: -5,
                  child: InkWell(
                    onTap: () => _confirmRemoveUser(user),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),

        const SizedBox(height: 40),

        // "Use another account" button
        TextButton.icon(
          onPressed: () => setState(() => _showQuickLogin = false),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text("Utiliser un autre compte"),
        ),
      ],
    );
  }

  Widget _buildStandardLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Center(child: Text('Connexion', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold))),
        if (_savedUsers.isNotEmpty)
          Center(
            child: TextButton(
                onPressed: () => setState(() => _showQuickLogin = true),
                child: const Text("Retour aux comptes enregistrés")
            ),
          ),
        const SizedBox(height: 24),

        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _passwordController,
          obscureText: !_passwordVisible,
          decoration: InputDecoration(
            labelText: 'Mot de passe',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_passwordVisible ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),

        // 🔑 NEW: Forgot Password Button
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _resetPassword,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(50, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              "Mot de passe oublié ?",
              style: TextStyle(
                color: Color(0xFF6366f1),
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ),

        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _signIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366f1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('CONNEXION', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------------------
// 🔢 MINI DIALOG FOR PIN ENTRY
// -------------------------------------------------------------------------
class _PinEntryDialog extends StatefulWidget {
  final String userName;
  const _PinEntryDialog({required this.userName});
  @override
  State<_PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends State<_PinEntryDialog> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Bonjour ${widget.userName}"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Entrez votre code PIN pour accéder"),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            obscureText: true,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 8),
            maxLength: 4,
            decoration: const InputDecoration(counterText: "", hintText: "••••"),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (val) {
              if (val.length == 4) Navigator.pop(context, val);
            },
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
      ],
    );
  }
}

// Keep WaveClipper at the bottom
class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 50);
    var firstControlPoint = Offset(size.width / 4, size.height);
    var firstEndPoint = Offset(size.width / 2, size.height - 30.0);
    path.quadraticBezierTo(firstControlPoint.dx, firstControlPoint.dy, firstEndPoint.dx, firstEndPoint.dy);
    var secondControlPoint = Offset(size.width - (size.width / 4), size.height - 65);
    var secondEndPoint = Offset(size.width, size.height - 40);
    path.quadraticBezierTo(secondControlPoint.dx, secondControlPoint.dy, secondEndPoint.dx, secondEndPoint.dy);
    path.lineTo(size.width, size.height - 40);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}