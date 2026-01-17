// lib/main.dart

import 'dart:async';
import 'package:flutter/gestures.dart'; // ✅ Required for PointerDeviceKind
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ✅ Required for kIsWeb check
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:app_links/app_links.dart';

import 'package:boitex_info_app/api/firebase_api.dart';
import 'package:boitex_info_app/utils/nav_key.dart';

import 'package:boitex_info_app/screens/auth_gate.dart';
import 'package:boitex_info_app/screens/administration/livraison_details_page.dart';

// ✅ NEW: Import the Portal Page
import 'package:boitex_info_app/screens/portal/store_request_page.dart';

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

// ✅ CUSTOM SCROLL BEHAVIOR: Allows dragging with Mouse on Web
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}

class BoitexInfoApp extends StatefulWidget {
  const BoitexInfoApp({super.key});

  @override
  State<BoitexInfoApp> createState() => _BoitexInfoAppState();
}

class _BoitexInfoAppState extends State<BoitexInfoApp> {
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

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    try {
      final Uri? initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint("Error handling initial deep link: $e");
    }

    _linkSubscription = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    }, onError: (err) {
      debugPrint("Deep Link Stream Error: $err");
    });
  }

  // ✅ UPDATED PARSING LOGIC: Supports boitex:// AND https://app.boitexinfo.com
  void _handleDeepLink(Uri uri) {
    debugPrint("Received Deep Link: $uri");

    // 1. Handle Delivery Links (boitex://livraison/ID)
    if (uri.scheme == 'boitex' && uri.host == 'livraison') {
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
      return; // Stop here
    }

    // 2. Handle QR Portal Links
    // Supports both schemes:
    // - boitex://portal?sid=... (Custom Scheme)
    // - https://app.boitexinfo.com/?sid=... (Web Link)

    bool isPortalLink = false;

    // Check custom scheme
    if (uri.scheme == 'boitex' && uri.host == 'portal') {
      isPortalLink = true;
    }

    // Check web scheme
    if ((uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host == 'app.boitexinfo.com' &&
        uri.queryParameters.containsKey('sid')) {
      isPortalLink = true;
    }

    if (isPortalLink) {
      final sid = uri.queryParameters['sid'];
      final token = uri.queryParameters['token'];

      if (sid != null && token != null && navigatorKey.currentState != null) {
        // Push the Portal Page
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (context) => StoreRequestPage(storeId: sid, token: token),
          ),
        );
      }
    }
  }

  // ✅ THE CORE LOGIC: Decide where the app starts
  Widget _getInitialScreen() {
    // 1. Web Portal Check (Implicit URL)
    // URL Format: https://app.boitexinfo.com/?sid=STORE_123&token=XYZ_TOKEN
    if (kIsWeb) {
      final uri = Uri.base; // Gets the current browser URL
      if (uri.queryParameters.containsKey('sid') && uri.queryParameters.containsKey('token')) {
        return StoreRequestPage(
          storeId: uri.queryParameters['sid']!,
          token: uri.queryParameters['token']!,
        );
      }
    }

    // 2. Default: Go to Login Page
    return const AuthGate();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      // ✅ APPLY CUSTOM SCROLL BEHAVIOR HERE
      scrollBehavior: AppScrollBehavior(),
      debugShowCheckedModeBanner: false,
      title: 'Boitex Info',
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
      // ✅ CHANGED: Use our new logic function instead of hardcoded AuthGate
      home: _getInitialScreen(),
    );
  }
}