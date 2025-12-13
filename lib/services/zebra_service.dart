// lib/services/zebra_service.dart

import 'dart:async';
import 'package:flutter/services.dart';

class ZebraService {
  // Singleton pattern
  static final ZebraService _instance = ZebraService._internal();
  factory ZebraService() => _instance;
  ZebraService._internal();

  // The Native Channel
  // This name must match exactly what we put in MainActivity.kt
  static const EventChannel _eventChannel =
  EventChannel('com.boitexinfo.app/zebra_scanner');

  // Stream controller to broadcast scans to the app
  final StreamController<String> _scanController =
  StreamController<String>.broadcast();

  StreamSubscription? _subscription;

  // ✅ AUTO-INIT: Starts listening automatically when accessed
  Stream<String> get onScan {
    if (_subscription == null) {
      _init();
    }
    return _scanController.stream;
  }

  void _init() {
    print("ZEBRA: Initializing Zebra Service (Auto-Start)...");
    try {
      _subscription = _eventChannel.receiveBroadcastStream().listen(
            (dynamic event) {
          // Event is the barcode string sent from Kotlin
          final String scanData = event.toString();
          print("ZEBRA SCAN RECEIVED: $scanData");
          _scanController.add(scanData);
        },
        onError: (dynamic error) {
          print("ZEBRA ERROR: ${error.message}");
        },
      );
    } catch (e) {
      print("ZEBRA INIT FAILED: $e");
    }
  }

  void dispose() {
    _subscription?.cancel();
    _scanController.close();
  }
}