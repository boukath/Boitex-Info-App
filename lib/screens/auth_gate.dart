// lib/screens/auth_gate.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/screens/home/home_page.dart';
import 'package:boitex_info_app/screens/login/login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  /// This function is now very lean. Its ONLY job is to get the user's
  /// document from Firestore, which is a very fast operation.
  Future<DocumentSnapshot> _getUserData(User user) async {
    return FirebaseFirestore.instance.collection('users').doc(user.uid).get();
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
          // The FutureBuilder now only waits for the essential user data.
          return FutureBuilder<DocumentSnapshot>(
            future: _getUserData(snapshot.data!),
            builder: (context, firestoreSnapshot) {
              if (firestoreSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              if (firestoreSnapshot.hasError) {
                return const Scaffold(body: Center(child: Text("Une erreur s'est produite")));
              }
              if (firestoreSnapshot.hasData && firestoreSnapshot.data!.exists) {
                final data = firestoreSnapshot.data!.data() as Map<String, dynamic>;
                final role = data['role'] ?? 'utilisateur';
                final displayName = data['displayName'] ?? 'Utilisateur';

                // Go to the HomePage immediately with the essential data.
                return HomePage(userRole: role, displayName: displayName);
              }

              return const LoginPage();
            },
          );
        }

        return const LoginPage();
      },
    );
  }
}