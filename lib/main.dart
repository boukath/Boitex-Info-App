// lib/main.dart
import 'package:boitex_info_app/screens/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // IMPORTANT: Add this import
import 'package:flutter_localizations/flutter_localizations.dart';
// ADDED: Import for Firebase Messaging
import 'package:firebase_messaging/firebase_messaging.dart';

// ✅ 1. ADD THIS IMPORT FOR TIMEAGO
import 'package:timeago/timeago.dart' as timeago;

// 👇 IMPORT YOUR API TO ACCESS INITNOTIFICATIONS
import 'package:boitex_info_app/api/firebase_api.dart';

// ADDED: This function MUST be a top-level function (outside of any class)
// It handles notifications that arrive when the app is closed.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // You must initialize Firebase in the background handler as well.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print("Handling a background message: ${message.messageId}");
  // You can add more logic here if needed, like showing a local notification.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // IMPORTANT: Add options parameter for web support
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 👇 ADD THIS LINE: This triggers the permission prompt on Web
  await FirebaseApi().initNotifications();

  // ✅ 2. ADD THESE TWO LINES TO REGISTER FRENCH LOCALE
  timeago.setLocaleMessages('fr', timeago.FrMessages());
  timeago.setDefaultLocale('fr');

  // ADDED: Set the background messaging handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const BoitexInfoApp());
}

class BoitexInfoApp extends StatelessWidget {
  const BoitexInfoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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