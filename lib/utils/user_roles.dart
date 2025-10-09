// lib/utils/user_roles.dart

// This class holds the exact string for each role to prevent typos.
class UserRoles {
  static const String admin = 'Admin';
  static const String pdg = 'PDG';
  static const String responsableAdministratif = 'Responsable Administratif';
  static const String responsableCommercial = 'Responsable Commercial';
  static const String responsableTechnique = 'Responsable Technique';
  static const String responsableIT = 'Responsable IT';
  static const String chefDeProjet = 'Chef de Projet';
  static const String technicienST = 'Technicien ST';
  static const String technicienIT = 'Technicien IT';
}

// This class contains all the logic for checking permissions.
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
    UserRoles.pdg,
    UserRoles.responsableAdministratif,
    UserRoles.responsableCommercial,
  ];

  // Roles that can schedule an installation
  static const List<String> _schedulingRoles = [
    UserRoles.pdg,
    UserRoles.responsableCommercial,
    UserRoles.responsableTechnique,
    UserRoles.chefDeProjet,
  ];

  // A helper function to check roles. It's case-insensitive and handles Admin god mode.
  static bool _checkRole(String userRole, List<String> allowedRoles) {
    final formattedUserRole = userRole.trim().toLowerCase();

    // "God mode" for Admin. If the user is an Admin, always grant permission.
    if (formattedUserRole == UserRoles.admin.toLowerCase()) {
      return true;
    }

    return allowedRoles.any((allowedRole) => allowedRole.toLowerCase() == formattedUserRole);
  }

  // --- Public Permission Checks ---

  static bool canSeeAdminCard(String userRole) {
    return _checkRole(userRole, _fullAccessRoles);
  }

  static bool canSeeTechServiceCard(String userRole) {
    if (userRole.trim().toLowerCase() == UserRoles.technicienST.toLowerCase()) {
      return true;
    }
    return _checkRole(userRole, _fullAccessRoles);
  }

  static bool canSeeITServiceCard(String userRole) {
    if (userRole.trim().toLowerCase() == UserRoles.technicienIT.toLowerCase()) {
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

  static bool canUploadDevis(String userRole) {
    return _checkRole(userRole, _salesRoles);
  }

  static bool canScheduleInstallation(String userRole) {
    return _checkRole(userRole, _schedulingRoles);
  }
}