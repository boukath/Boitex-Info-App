// lib/models/saved_user.dart

class SavedUser {
  final String uid;
  final String email;
  final String displayName;
  final String userRole; // 'Technicien', 'Admin', etc.
  final String? photoUrl; // Optional: for the avatar

  SavedUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.userRole,
    this.photoUrl,
  });

  // Convert to Map for saving to storage
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'userRole': userRole,
      'photoUrl': photoUrl,
    };
  }

  // Create from Map when loading from storage
  factory SavedUser.fromMap(Map<String, dynamic> map) {
    return SavedUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? 'Utilisateur',
      userRole: map['userRole'] ?? 'Technicien',
      photoUrl: map['photoUrl'],
    );
  }
}