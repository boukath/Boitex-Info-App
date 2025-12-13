// lib/widgets/pin_setup_dialog.dart

import 'package:boitex_info_app/models/saved_user.dart';
import 'package:boitex_info_app/services/session_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PinSetupDialog extends StatefulWidget {
  final User firebaseUser;
  final String password;

  const PinSetupDialog({
    super.key,
    required this.firebaseUser,
    required this.password,
  });

  @override
  State<PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<PinSetupDialog> with WidgetsBindingObserver {
  final _pinController = TextEditingController();
  final _sessionService = SessionService();
  final FocusNode _focusNode = FocusNode(); // ✅ 1. Focus Node to control keyboard

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // ✅ 2. Listen to app states

    // ✅ 3. FORCE KEYBOARD ON OPEN
    // We wait for the widget to build, then force the focus and keyboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _forceKeyboard();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.dispose();
    _pinController.dispose();
    super.dispose();
  }

  // ✅ 4. FORCE KEYBOARD WHEN APP RESUMES (After Notification Popup Closes)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Add a small delay to ensure the System Dialog is fully gone
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _forceKeyboard();
        }
      });
    }
  }

  // 🛠️ HELPER: The Aggressive Keyboard Opener
  void _forceKeyboard() {
    // 1. Reset focus (wakes up the system)
    FocusScope.of(context).unfocus();

    // 2. Wait a tiny bit, then Request Focus again
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        FocusScope.of(context).requestFocus(_focusNode);

        // 3. LOW LEVEL COMMAND: Force the OS to show the keyboard
        SystemChannels.textInput.invokeMethod('TextInput.show');
      }
    });
  }

  Widget _buildPinBoxes() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        bool isFilled = _pinController.text.length > index;
        return Container(
          // Reduced margin to prevent overflow on small screens
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 50,
          height: 60,
          decoration: BoxDecoration(
            color: isFilled ? Colors.blue.shade50 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isFilled ? Colors.blue : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: Center(
            child: isFilled
                ? const Icon(Icons.circle, size: 16, color: Colors.blue)
                : const SizedBox(),
          ),
        );
      }),
    );
  }

  Future<void> _handleSave() async {
    final pin = _pinController.text;
    if (pin.length != 4) {
      setState(() => _errorMessage = "Le code PIN doit contenir 4 chiffres.");
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.firebaseUser.uid)
          .get();

      String role = 'Technicien';
      String name = widget.firebaseUser.displayName ?? 'Utilisateur';

      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        role = data['role'] ?? role;
        name = data['displayName'] ?? data['name'] ?? name;
      }

      final savedUser = SavedUser(
        uid: widget.firebaseUser.uid,
        email: widget.firebaseUser.email ?? '',
        displayName: name,
        userRole: role,
        photoUrl: widget.firebaseUser.photoURL,
      );

      await _sessionService.saveUserSession(
        user: savedUser,
        password: widget.password,
        pin: pin,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Connexion rapide activée pour cet appareil !"),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      setState(() {
        _errorMessage = "Erreur de sauvegarde: $e";
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline_rounded, size: 32, color: Colors.blue),
            ),
            const SizedBox(height: 20),

            const Text(
              "Créer un code PIN",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Gagnez du temps ! Connectez-vous rapidement avec un code à 4 chiffres.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // PIN Display + Backspace Button
            // Wrapped in FittedBox to prevent overflow on small screens
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // The Input Boxes (Tapping them also forces keyboard)
                  GestureDetector(
                    onTap: _forceKeyboard, // ✅ Tap triggers the aggressive force
                    child: _buildPinBoxes(),
                  ),

                  const SizedBox(width: 8),

                  // Visible Backspace Button
                  IconButton(
                    icon: const Icon(Icons.backspace_rounded, color: Colors.grey),
                    onPressed: () {
                      final text = _pinController.text;
                      if (text.isNotEmpty) {
                        _pinController.text = text.substring(0, text.length - 1);
                        // Move cursor to end
                        _pinController.selection = TextSelection.fromPosition(
                            TextPosition(offset: _pinController.text.length)
                        );
                        setState((){});
                      }
                    },
                  ),
                ],
              ),
            ),

            // Hidden Text Field for Logic
            // Using 1x1 size to ensure Android renders it and allows focus
            Opacity(
              opacity: 0.0,
              child: SizedBox(
                height: 1,
                width: 1,
                child: TextField(
                  controller: _pinController,
                  focusNode: _focusNode, // ✅ Attached FocusNode
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Plus tard", style: TextStyle(color: Colors.grey)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                        : const Text("Enregistrer", style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}