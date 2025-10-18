// lib/utils/user_roles.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// This class holds the exact string for each role to prevent typos.
class UserRoles {
  static const String admin = 'Admin';
  static const String pdg = 'PDG';
  static const String responsableAdministratif = 'Responsable Administratif';  // WITH SPACES
  static const String responsableCommercial = 'Responsable Commercial';        // WITH SPACES
  static const String responsableTechnique = 'Responsable Technique';          // WITH SPACES
  static const String responsableIT = 'Responsable IT';                        // WITH SPACES
  static const String chefDeProjet = 'Chef de Projet';                         // WITH SPACES
  static const String technicienST = 'Technicien ST';                          // WITH SPACES
  static const String technicienIT = 'Technicien IT';                          // WITH SPACES

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
  // ✅ ALL MANAGEMENT ROLES - These roles can see EVERYTHING
  static const List<String> _fullAccessRoles = [
    UserRoles.admin,
    UserRoles.pdg,
    UserRoles.responsableAdministratif,
    UserRoles.responsableCommercial,
    UserRoles.responsableTechnique,
    UserRoles.responsableIT,
    UserRoles.chefDeProjet,
  ];

  // Roles that can perform a technical evaluation.
  static const List<String> _technicalEvaluationRoles = [
    UserRoles.admin,
    UserRoles.pdg,
    UserRoles.responsableTechnique,
    UserRoles.chefDeProjet,
  ];

  // Roles that can upload a quote ("devis").
  static const List<String> _salesRoles = [
    UserRoles.admin,
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

  // Roles that can schedule an installation.
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

  /// Check if user can schedule installations.
  static bool canScheduleInstallation(String userRole) {
    return _checkRole(userRole, _installationSchedulerRoles);
  }

  /// Check if user can upload devis (quotes).
  static bool canUploadDevis(String userRole) {
    return _checkRole(userRole, _salesRoles);
  }

  /// ✅ ALL MANAGEMENT ROLES CAN SEE ADMIN CARD
  static bool canSeeAdminCard(String userRole) {
    return _checkRole(userRole, _fullAccessRoles);
  }

  /// ✅ ALL MANAGEMENT ROLES + TECHNICIANS CAN SEE TECH SERVICE CARD
  static bool canSeeTechServiceCard(String userRole) {
    if (userRole == UserRoles.technicienST) {
      return true;
    }
    return _checkRole(userRole, _fullAccessRoles);
  }

  /// ✅ ALL MANAGEMENT ROLES + IT TECHNICIANS CAN SEE IT SERVICE CARD
  static bool canSeeITServiceCard(String userRole) {
    if (userRole == UserRoles.technicienIT) {
      return true;
    }
    return _checkRole(userRole, _fullAccessRoles);
  }

  /// Check if user can add interventions.
  static bool canAddIntervention(String userRole) {
    return _checkRole(userRole, _fullAccessRoles);
  }

  /// Check if user can perform technical evaluations.
  static bool canPerformTechnicalEvaluation(String userRole) {
    return _checkRole(userRole, _technicalEvaluationRoles);
  }
}
