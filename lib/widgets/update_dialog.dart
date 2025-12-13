import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
// ✅ CHANGED: Using the maintained package that supports modern Android
import 'package:open_filex/open_filex.dart';
import 'dart:io';

class UpdateDialog extends StatefulWidget {
  final String version;
  final String releaseNotes;
  final String downloadUrl;
  final bool forceUpdate;

  const UpdateDialog({
    super.key,
    required this.version,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.forceUpdate,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  double _progress = 0.0;
  bool _isDownloading = false;
  String _statusMessage = "";

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _statusMessage = "Démarrage du téléchargement...";
    });

    try {
      // 1. Get external storage path (Required for Android install)
      final dir = await getExternalStorageDirectory();
      if (dir == null) throw Exception("Stockage inaccessible");

      final String savePath = "${dir.path}/update.apk";

      // 2. Download with progress
      final dio = Dio();
      await dio.download(
        widget.downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _progress = received / total;
              _statusMessage = "${(_progress * 100).toStringAsFixed(0)}%";
            });
          }
        },
      );

      setState(() => _statusMessage = "Installation...");

      // 3. Open the APK to trigger install
      // ✅ CHANGED: Using OpenFilex
      final result = await OpenFilex.open(savePath);

      if (result.type != ResultType.done) {
        // Note: result.message might be generic, check Logcat if issues persist
        debugPrint("Install Error: ${result.message}");
        if (mounted) {
          setState(() {
            _statusMessage = "Erreur d'installation : ${result.message}";
            _isDownloading = false; // Allow retry
          });
        }
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusMessage = "Erreur: $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.forceUpdate && !_isDownloading,
      child: AlertDialog(
        title: Text(_isDownloading ? "Téléchargement..." : "Mise à jour disponible"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isDownloading) ...[
              Text("Version : ${widget.version}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              const Text("Nouveautés :", style: TextStyle(fontWeight: FontWeight.w600)),
              Text(widget.releaseNotes),
              const SizedBox(height: 20),
              if (widget.forceUpdate)
                const Text(
                  "⚠️ Mise à jour obligatoire.",
                  style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                ),
            ] else ...[
              LinearProgressIndicator(value: _progress, backgroundColor: Colors.grey[200], color: Colors.blue),
              const SizedBox(height: 10),
              Center(child: Text(_statusMessage)),
            ],
          ],
        ),
        actions: [
          if (!widget.forceUpdate && !_isDownloading)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Plus tard"),
            ),
          if (!_isDownloading)
            ElevatedButton(
              onPressed: _startDownload,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              child: const Text("TÉLÉCHARGER"),
            ),
        ],
      ),
    );
  }
}