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
      } else {
        return null; // User document doesn't exist
      }
    } catch (e) {
      print('Error fetching user role: $e');
      return null;
    }
  }
}

/// Manages permissions based on user roles.
class RolePermissions {
  // --- Role Groups (Private) ---

  // Full administrative access
  static const List<String> _fullAccessRoles = [
    UserRoles.admin,
    UserRoles.pdg,
    UserRoles.responsableAdministratif,
  ];

  // Can manage sales, quotes, and projects
  static const List<String> _salesRoles = [
    UserRoles.admin,
    UserRoles.pdg,
    UserRoles.responsableAdministratif,
    UserRoles.responsableCommercial,
    UserRoles.chefDeProjet,
  ];

  // Can manage technical services and installations
  static const List<String> _technicalManagementRoles = [
    UserRoles.admin,
    UserRoles.pdg,
    UserRoles.responsableAdministratif,
    UserRoles.responsableTechnique,
    UserRoles.chefDeProjet,
  ];

  // Can schedule and manage installations (Admin + Tech)
  static const List<String> _installationSchedulerRoles = [
    UserRoles.admin,
    UserRoles.pdg,
    UserRoles.responsableAdministratif,
    UserRoles.responsableTechnique,
  ];

  // Can manage requisitions
  static const List<String> _requisitionRoles = [
    UserRoles.admin,
    UserRoles.pdg,
    UserRoles.responsableAdministratif,
    UserRoles.responsableCommercial,
    UserRoles.responsableTechnique,
    UserRoles.responsableIT,
    UserRoles.chefDeProjet,
  ];

  // Can edit or create livraison
  static const List<String> _livraisonEditorRoles = [
    UserRoles.admin,
    UserRoles.pdg,
    UserRoles.responsableAdministratif,
    UserRoles.responsableCommercial,
    UserRoles.chefDeProjet,
  ];

  // --- Private Helper ---
  static bool _checkRole(String userRole, List<String> allowedRoles) {
    return allowedRoles.contains(userRole);
  }

  // --- Asynchronous Public Permission Checks (for use in UI) ---

  // ✅ --- ADD THIS NEW METHOD ---
  /// Asynchronously checks if the *currently logged-in user* can edit livraisons.
  static Future<bool> canCurrentUserEditLivraison() async {
    final role = await UserRoles.getCurrentUserRole();
    if (role == null) return false;
    return canManageLivraisons(role);
  }
  // ✅ --- END OF NEW METHOD ---


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
    return userRole == UserRoles.technicienST ||
        _checkRole(userRole, _technicalManagementRoles);
  }

  /// Check if user can perform technical evaluations.
  static bool canPerformTechnicalEvaluation(String userRole) {
    return userRole == UserRoles.technicienST ||
        _checkRole(userRole, _technicalManagementRoles);
  }

  /// Check if user can perform IT evaluations.
  static bool canPerformItEvaluation(String userRole) {
    return userRole == UserRoles.admin ||
        userRole == UserRoles.responsableIT ||
        userRole == UserRoles.technicienIT;
  }

  /// Check if user can manage requisitions.
  static bool canManageRequisitions(String userRole) {
    return _checkRole(userRole, _requisitionRoles);
  }

  /// Check if user can manage livraisons.
  static bool canManageLivraisons(String userRole) {
    return _checkRole(userRole, _livraisonEditorRoles);
  }
}