// lib/main.dart

import 'dart:async';
import 'package:flutter/gestures.dart'; // Required for PointerDeviceKind
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Required for kIsWeb check
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:app_links/app_links.dart';

// ✅ IMPORT: Home Widget for Android Smart Navigation
import 'package:home_widget/home_widget.dart';

import 'package:boitex_info_app/api/firebase_api.dart';
import 'package:boitex_info_app/utils/nav_key.dart';

import 'package:boitex_info_app/screens/auth_gate.dart';
import 'package:boitex_info_app/screens/administration/livraison_details_page.dart';
import 'package:boitex_info_app/screens/portal/store_request_page.dart';

// ✅ IMPORTS: Widget Destination Pages
import 'package:boitex_info_app/screens/service_technique/intervention_list_page.dart';
import 'package:boitex_info_app/screens/service_technique/installation_list_page.dart';
import 'package:boitex_info_app/screens/service_technique/sav_list_page.dart';
import 'package:boitex_info_app/screens/administration/manage_missions_page.dart';

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
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Set timeago language to French
  timeago.setLocaleMessages('fr', timeago.FrMessages());

  runApp(const BoitexInfoApp());
}

// ✅ CROSS-PLATFORM SCROLL BEHAVIOR
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
    _initWidgetNavigation(); // ✅ INITIALIZE WIDGET ROUTING
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  // ========================= DEEP LINKS (WEB & PUSH) =========================
  // ========================= DEEP LINKS (WEB & PUSH) =========================
  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    try {
      // ✅ CHANGED: getInitialAppLink() is now getInitialLink() in app_links v6+
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint("Failed to get initial link: $e");
    }

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      debugPrint("Deep link stream error: $err");
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint("Deep link received: $uri");

    // Delivery logic
    if (uri.scheme == 'boitex' && uri.host == 'livraison') {
      final id = uri.queryParameters['id'];
      if (id != null && navigatorKey.currentState != null) {
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (context) => LivraisonDetailsPage(livraisonId: id),
          ),
        );
      }
    }

    // Web portal logic
    if ((uri.scheme == 'http' || uri.scheme == 'https') && uri.host == 'app.boitexinfo.com') {
      final sid = uri.queryParameters['sid'];
      final token = uri.queryParameters['token'];
      if (sid != null && token != null && navigatorKey.currentState != null) {
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (context) => StoreRequestPage(storeId: sid, token: token),
          ),
        );
      }
    }
  }

  // ========================= ANDROID WIDGET ROUTING =========================
  void _initWidgetNavigation() {
    // 1. When the app is running in the background and is brought forward
    HomeWidget.widgetClicked.listen(_handleWidgetRouting);

    // 2. When the app is completely closed (killed) and launched from the widget
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetRouting);
  }

  void _handleWidgetRouting(Uri? uri) {
    if (uri == null || uri.scheme != 'boitexwidget') return;

    debugPrint("📱 Widget clicked! Routing to: ${uri.host}");

    if (navigatorKey.currentState != null) {
      const String serviceType = 'Service Technique';
      const String userRole = 'Technicien';

      switch (uri.host) {
        case 'interventions':
          navigatorKey.currentState!.push(MaterialPageRoute(
            builder: (_) => const InterventionListPage(userRole: userRole, serviceType: serviceType),
          ));
          break;
        case 'installations':
          navigatorKey.currentState!.push(MaterialPageRoute(
            builder: (_) => const InstallationListPage(userRole: userRole, serviceType: serviceType),
          ));
          break;
        case 'sav':
          navigatorKey.currentState!.push(MaterialPageRoute(
            builder: (_) => const SavListPage(serviceType: serviceType),
          ));
          break;
        case 'missions':
          navigatorKey.currentState!.push(MaterialPageRoute(
            builder: (_) => const ManageMissionsPage(serviceType: serviceType),
          ));
          break;
      }
    }
  }

  // ========================= INITIAL SCREEN ROUTING =========================
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
        Locale('fr', 'FR'),
      ],
      home: _getInitialScreen(),
    );
  }
}