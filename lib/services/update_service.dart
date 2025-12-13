import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:boitex_info_app/widgets/update_dialog.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  /// Checks for update and shows dialog if found
  Future<void> checkForUpdate(BuildContext context, {bool showNoUpdateMessage = false}) async {
    try {
      // 1. Get current App Version
      final packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;

      // 2. Get Remote Settings
      final doc = await FirebaseFirestore.instance.collection('settings').doc('app_version').get();

      if (!doc.exists) {
        if (showNoUpdateMessage) _showSnack(context, "Aucune configuration de mise à jour trouvée.");
        return;
      }

      final data = doc.data()!;
      final String latestVersion = data['currentVersion'] ?? currentVersion;
      final String minVersion = data['minVersion'] ?? '0.0.0';
      final String downloadUrl = data['downloadUrl'] ?? '';
      final String releaseNotes = data['releaseNotes'] ?? '';
      final bool manualForce = data['forceUpdate'] ?? false;

      // 3. Compare Versions
      final bool isUpdateAvailable = _compareVersions(latestVersion, currentVersion) > 0;
      final bool isForced = manualForce || _compareVersions(minVersion, currentVersion) > 0;

      if (isUpdateAvailable) {
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: !isForced,
            builder: (ctx) => UpdateDialog(
              version: latestVersion,
              releaseNotes: releaseNotes,
              downloadUrl: downloadUrl,
              forceUpdate: isForced,
            ),
          );
        }
      } else {
        if (showNoUpdateMessage && context.mounted) {
          _showSnack(context, "Votre application est à jour (v$currentVersion)");
        }
      }
    } catch (e) {
      if (showNoUpdateMessage && context.mounted) {
        _showSnack(context, "Erreur de vérification : $e");
      }
      debugPrint("Update Error: $e");
    }
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Returns 1 if v1 > v2, -1 if v1 < v2, 0 if equal
  int _compareVersions(String v1, String v2) {
    try {
      List<int> v1Parts = v1.split('.').map(int.parse).toList();
      List<int> v2Parts = v2.split('.').map(int.parse).toList();

      for (int i = 0; i < v1Parts.length; i++) {
        if (i >= v2Parts.length) return 1;
        if (v1Parts[i] > v2Parts[i]) return 1;
        if (v1Parts[i] < v2Parts[i]) return -1;
      }
      if (v1Parts.length < v2Parts.length) return -1;
      return 0;
    } catch (e) {
      return 0;
    }
  }
}