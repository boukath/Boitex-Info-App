// lib/utils/user_roles.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// This class holds the exact string for each role to prevent typos.
class UserRoles {
  static const String admin = 'Admin';
  static const String pdg = 'PDG';
  static const String responsableAdministratif = 'Responsable_Administratif';
  static const String responsableCommercial = 'Responsable_Commercial';
  static const String responsableTechnique = 'Responsable_Technique';
  static const String responsableIT = 'Responsable_IT';
  static const String chefDeProjet = 'Chef_de_Projet';
  static const String technicienST = 'Technicien_ST';
  static const String technicienIT = 'Technicien_IT';

  /// Fetches the role of the currently authenticated user from Firestore.
  /// Returns null if the user is not logged in or has no role.
  static Future<String?> getCurrentUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (docSnapshot.exists) {
        return docSnapshot.data()?['role'] as String?;
      }
    } catch (e) {
      print("Error fetching user role: $e");
    }
    return null;
  }
}

/// This class contains all the logic for checking user permissions based on roles.
class RolePermissions {
  // Roles with full access to see all main sections on the home page.
  static const List<String> _fullAccessRoles = [
    UserRoles.pdg,
    UserRoles.responsableAdministratif,
    UserRoles.responsableCommercial,
    UserRoles.responsableTechnique,
    UserRoles.responsableIT,
    UserRoles.chefDeProjet,
  ];

  // Roles that can perform a technical evaluation.
  static const List<String> _technicalEvaluationRoles = [
    UserRoles.pdg,
    UserRoles.responsableTechnique,
    UserRoles.chefDeProjet,
  ];

  // Roles that can upload a quote ("devis").
  static const List<String> _salesRoles = [
    UserRoles.responsableCommercial,
    UserRoles.pdg,
  ];

  // Roles that can edit a "livraison" (delivery).
  static const List<String> _livraisonEditorRoles = [
    UserRoles.admin,
    UserRoles.pdg,
    UserRoles.responsableAdministratif,
    UserRoles.responsableCommercial,
    UserRoles.responsableTechnique,
    UserRoles.responsableIT,
    UserRoles.chefDeProjet,
  ];

  // ✅ NEW: Roles that can schedule an installation.
  static const List<String> _installationSchedulerRoles = [
    UserRoles.admin,
    UserRoles.pdg,
    UserRoles.responsableTechnique,
    UserRoles.chefDeProjet,
  ];


  /// Generic helper that checks if a user's role is in a list of allowed roles.
  /// The 'Admin' role is always granted permission.
  static bool _checkRole(String? userRole, List<String> allowedRoles) {
    if (userRole == null) return false;

    // "God mode" for Admin. If the user is an Admin, always grant permission.
    if (userRole == UserRoles.admin) {
      return true;
    }

    return allowedRoles.contains(userRole);
  }

  // --- Asynchronous Public Permission Checks ---

  /// Asynchronous check if the current user can edit a livraison.
  static Future<bool> canCurrentUserEditLivraison() async {
    final userRole = await UserRoles.getCurrentUserRole();
    return _checkRole(userRole, _livraisonEditorRoles);
  }

  // --- Synchronous Public Permission Checks (for when role is already known) ---

  // ✅ NEW: Synchronous check for scheduling installations.
  static bool canScheduleInstallation(String userRole) {
    return _checkRole(userRole, _installationSchedulerRoles);
  }

  // ✅ RENAMED: This was canUploadQuote, now it matches your code.
  static bool canUploadDevis(String userRole) {
    return _checkRole(userRole, _salesRoles);
  }

  static bool canSeeAdminCard(String userRole) {
    return _checkRole(userRole, _fullAccessRoles);
  }

  static bool canSeeTechServiceCard(String userRole) {
    if (userRole == UserRoles.technicienST) {
      return true;
    }
    return _checkRole(userRole, _fullAccessRoles);
  }

  static bool canSeeITServiceCard(String userRole) {
    if (userRole == UserRoles.technicienIT) {
      return true;
    }
    return _checkRole(userRole, _fullAccessRoles);
  }

  static bool canAddIntervention(String userRole) {
    return _checkRole(userRole, _fullAccessRoles);
  }

  static bool canPerformTechnicalEvaluation(String userRole) {
    return _checkRole(userRole, _technicalEvaluationRoles);
  }
}