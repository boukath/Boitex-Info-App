// lib/main.dart

import 'dart:async'; // ✅ Added for StreamSubscription
import 'package:boitex_info_app/screens/auth_gate.dart';
import 'package:boitex_info_app/screens/administration/livraison_details_page.dart'; // ✅ Import Details Page
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:app_links/app_links.dart'; // ✅ ADDED: App Links Package

import 'package:boitex_info_app/api/firebase_api.dart';
import 'package:boitex_info_app/utils/nav_key.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print("Handling a background message: ${message.messageId}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  timeago.setLocaleMessages('fr', timeago.FrMessages());
  timeago.setDefaultLocale('fr');

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const BoitexInfoApp());
}

class BoitexInfoApp extends StatefulWidget {
  const BoitexInfoApp({super.key});

  @override
  State<BoitexInfoApp> createState() => _BoitexInfoAppState();
}

class _BoitexInfoAppState extends State<BoitexInfoApp> {
  // ✅ DEEP LINK VARIABLES
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  // ✅ LOGIC: Listen for "boitex://" links
  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // 1. Check Initial Link (App was closed and opened via link)
    try {
      final Uri? initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint("Error handling initial deep link: $e");
    }

    // 2. Listen for Stream (App is in background and brought to foreground)
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    }, onError: (err) {
      debugPrint("Deep Link Stream Error: $err");
    });
  }

  // ✅ PARSING LOGIC
  void _handleDeepLink(Uri uri) {
    debugPrint("Received Deep Link: $uri");

    // Expected format: boitex://livraison/<LIVRAISON_ID>
    if (uri.scheme == 'boitex' && uri.host == 'livraison') {
      // The ID is the first path segment (e.g., /LIV-123 -> LIV-123)
      // Note: uri.pathSegments might return empty if format is strictly host-only without path
      // Adjust based on how you construct the URL.
      // Example 1: boitex://livraison/123 -> host=livraison, pathSegments=['123']

      String? livraisonId;
      if (uri.pathSegments.isNotEmpty) {
        livraisonId = uri.pathSegments.first;
      }

      if (livraisonId != null && navigatorKey.currentState != null) {
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (context) => LivraisonDetailsPage(livraisonId: livraisonId!),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Connexion Boitex Info',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', ''),
        Locale('en', ''),
      ],
      home: const AuthGate(),
    );
  }
}