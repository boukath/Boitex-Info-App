// lib/screens/auth_gate.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/screens/home/home_page.dart';
import 'package:boitex_info_app/screens/login/login_page.dart';
// Import API to init notifications AFTER auth check
import 'package:boitex_info_app/api/firebase_api.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<DocumentSnapshot> _getUserData(User user) async {
    // Add a 5 second timeout to prevent infinite loading
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get()
        .timeout(const Duration(seconds: 5));
  }

  // Helper to initialize notifications in the background
  void _initNotificationsBackground(String role) {
    // Fire and forget - don't await this
    final api = FirebaseApi();
    api.initNotifications().then((_) {
      api.subscribeToTopics(role);
      api.saveTokenForCurrentUser();
    }).catchError((e) {
      print("Notification init failed (non-fatal): $e");
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData) {
          return FutureBuilder<DocumentSnapshot>(
            future: _getUserData(snapshot.data!),
            builder: (context, firestoreSnapshot) {
              if (firestoreSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }

              // Defaults if fetch fails or user has no doc
              String role = 'utilisateur';
              String displayName = 'Utilisateur';

              if (firestoreSnapshot.hasData && firestoreSnapshot.data != null && firestoreSnapshot.data!.exists) {
                final data = firestoreSnapshot.data!.data() as Map<String, dynamic>;
                role = data['role'] ?? 'utilisateur';
                displayName = data['displayName'] ?? 'Utilisateur';
              }

              // Trigger notification setup in background once we have the role
              _initNotificationsBackground(role);

              return HomePage(userRole: role, displayName: displayName);
            },
          );
        }

        return const LoginPage();
      },
    );
  }
}