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

  // ✅ ADDED: New Commercial Role
  static const String commercial = 'Commercial';

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

  // ✅ FIXED: This is now the ONLY list for all managers, matching Firestore rules.
  // Full administrative access
  static const List<String> _fullAccessRoles = [
    UserRoles.admin,
    UserRoles.pdg,
    UserRoles.responsableAdministratif,
    UserRoles.responsableCommercial,
    UserRoles.responsableTechnique,
    UserRoles.responsableIT,
    UserRoles.chefDeProjet,
  ];

  // --- Private Helper ---
  static bool _checkRole(String userRole, List<String> allowedRoles) {
    return allowedRoles.contains(userRole);
  }

  // --- Asynchronous Public Permission Checks (for use in UI) ---

  /// Asynchronously checks if the *currently logged-in user* can edit livraisons.
  static Future<bool> canCurrentUserEditLivraison() async {
    final role = await UserRoles.getCurrentUserRole();
    if (role == null) return false;
    return canManageLivraisons(role);
  }

  /// Asynchronously checks if the *currently logged-in user* can delete livraisons.
  static Future<bool> canCurrentUserDeleteLivraison() async {
    final role = await UserRoles.getCurrentUserRole();
    if (role == null) return false;
    // Deletion requires the same full access role as editing/managing.
    return canManageLivraisons(role);
  }

  // ✅ NOUVEAU: Check if user can delete interventions
  /// Asynchronously checks if the *currently logged-in user* can delete interventions.
  static Future<bool> canCurrentUserDeleteIntervention() async {
    final role = await UserRoles.getCurrentUserRole();
    if (role == null) return false;
    // La suppression des interventions est limitée aux rôles d'accès complet (full access roles).
    return _checkRole(role, _fullAccessRoles);
  }


  // --- Synchronous Public Permission Checks (for when role is already known) ---

  /// ✅ NEWLY ADDED: Check if user can edit missions (as requested previously)
  /// Check if the user has permission to edit missions.
  /// This permission is granted to all administrative/management roles.
  static bool canEditMission(String userRole) {
    return _checkRole(userRole, _fullAccessRoles);
  }

  /// ✅ NEWLY ADDED: Check if user can delete missions.
  /// This permission is granted to all administrative/management roles.
  static bool canDeleteMission(String userRole) {
    return _checkRole(userRole, _fullAccessRoles);
  }

  /// ✅ FIXED: Check if user can schedule installations.
  static bool canScheduleInstallation(String userRole) {
    return _checkRole(userRole, _fullAccessRoles);
  }

  /// ✅ FIXED: Check if user can upload devis (quotes).
  static bool canUploadDevis(String userRole) {
    return _checkRole(userRole, _fullAccessRoles);
  }

  /// ALL MANAGEMENT ROLES CAN SEE ADMIN CARD
  static bool canSeeAdminCard(String userRole) {
    return _checkRole(userRole, _fullAccessRoles);
  }

  /// ✅ ADDED: Check if user can see the Commercial Card
  /// Allows the specific 'Commercial' role OR any manager/admin.
  static bool canSeeCommercialCard(String userRole) {
    if (userRole == UserRoles.commercial) {
      return true;
    }
    return _checkRole(userRole, _fullAccessRoles);
  }

  /// ALL MANAGEMENT ROLES + TECHNICIANS CAN SEE TECH SERVICE CARD
  static bool canSeeTechServiceCard(String userRole) {
    if (userRole == UserRoles.technicienST) {
      return true;
    }
    return _checkRole(userRole, _fullAccessRoles);
  }

  /// ALL MANAGEMENT ROLES + IT TECHNICIANS CAN SEE IT SERVICE CARD
  static bool canSeeITServiceCard(String userRole) {
    if (userRole == UserRoles.technicienIT) {
      return true;
    }
    return _checkRole(userRole, _fullAccessRoles);
  }

  /// ✅ FIXED: Check if user can add interventions.
  /// (Allows Technicien ST *or* any Super Manager)
  static bool canAddIntervention(String userRole) {
    return userRole == UserRoles.technicienST ||
        _checkRole(userRole, _fullAccessRoles);
  }

  /// ✅ FIXED: Check if user can perform technical evaluations.
  /// (Allows Technicien ST *or* any Super Manager)
  static bool canPerformTechnicalEvaluation(String userRole) {
    return userRole == UserRoles.technicienST ||
        _checkRole(userRole, _fullAccessRoles);
  }

  /// ✅ FIXED: Check if user can perform IT evaluations.
  /// (Allows Technicien IT *or* any Super Manager)
  static bool canPerformItEvaluation(String userRole) {
    return userRole == UserRoles.technicienIT ||
        _checkRole(userRole, _fullAccessRoles);
  }

  /// ✅ FIXED: Check if user can manage requisitions.
  static bool canManageRequisitions(String userRole) {
    return _checkRole(userRole, _fullAccessRoles);
  }

  /// ✅ FIXED: Check if user can manage livraisons.
  static bool canManageLivraisons(String userRole) {
    return _checkRole(userRole, _fullAccessRoles);
  }
}