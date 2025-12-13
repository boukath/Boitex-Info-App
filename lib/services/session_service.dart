// lib/services/session_service.dart

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:boitex_info_app/models/saved_user.dart';

class SessionService {
  // The secure storage instance
  final _storage = const FlutterSecureStorage();

  // Key to store the list of public profiles (JSON)
  static const _kUsersListKey = 'saved_users_list';

  // ------------------------------------------------------------------------
  // 1. PUBLIC METHODS (Used by the UI)
  // ------------------------------------------------------------------------

  /// Returns the list of users to show on the Login Screen
  Future<List<SavedUser>> getSavedUsers() async {
    final String? jsonString = await _storage.read(key: _kUsersListKey);
    if (jsonString == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((e) => SavedUser.fromMap(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Registers a new user session with a PIN
  Future<void> saveUserSession({
    required SavedUser user,
    required String password, // We need this to re-auth later
    required String pin,
  }) async {
    // 1. Save the Public Profile to the main list
    await _addToPublicList(user);

    // 2. Save the Secrets (PIN and Password) securely
    // We create unique keys for each user based on their UID
    await _storage.write(key: 'pin_${user.uid}', value: pin);
    await _storage.write(key: 'pass_${user.uid}', value: password);
  }

  /// Verifies the PIN. Returns the Password if correct, null if wrong.
  Future<String?> verifyPinAndGetPassword(String uid, String inputPin) async {
    final storedPin = await _storage.read(key: 'pin_$uid');

    if (storedPin == inputPin) {
      // PIN matches! Return the password to auto-login
      return await _storage.read(key: 'pass_$uid');
    }

    // PIN incorrect
    return null;
  }

  /// Remove a user (e.g., if they leave the company)
  Future<void> removeUser(String uid) async {
    // 1. Remove from public list
    List<SavedUser> currentList = await getSavedUsers();
    currentList.removeWhere((u) => u.uid == uid);
    final String jsonString = jsonEncode(currentList.map((u) => u.toMap()).toList());
    await _storage.write(key: _kUsersListKey, value: jsonString);

    // 2. Delete secrets
    await _storage.delete(key: 'pin_$uid');
    await _storage.delete(key: 'pass_$uid');
  }

  // ------------------------------------------------------------------------
  // 2. PRIVATE HELPERS
  // ------------------------------------------------------------------------

  Future<void> _addToPublicList(SavedUser newUser) async {
    List<SavedUser> currentList = await getSavedUsers();

    // Remove if already exists to update info
    currentList.removeWhere((u) => u.uid == newUser.uid);

    // Add to top of list
    currentList.insert(0, newUser);

    // Save back to storage
    final String jsonString = jsonEncode(currentList.map((u) => u.toMap()).toList());
    await _storage.write(key: _kUsersListKey, value: jsonString);
  }
}