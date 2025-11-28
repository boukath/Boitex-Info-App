// lib/api/firebase_api.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // ✅ IMPORTANT IMPORT

class FirebaseApi {
  final _firebaseMessaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  // Topic names
  static const String _managersTopic = 'manager_notifications';
  static const String _techStTopic = 'technician_st_alerts';
  static const String _techItTopic = 'technician_it_alerts';

  // ✅ NEWLY ADDED TOPIC
  static const String _globalAnnouncementsTopic = 'GLOBAL_ANNOUNCEMENTS';

  // Helper function to convert role names to valid FCM topic names
  String _roleToTopic(String role) {
    return role.replaceAll(' ', '_');
  }

  Future<void> initNotifications() async {
    // Request permission
    await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    // Initialize local notifications
    await _initLocalNotifications();

    // Set up foreground notification handler
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from a notification
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    print('✅ Firebase Messaging initialized successfully');
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // ✅ ADDED: Web specific initialization (optional but good practice)
    // Note: Local notifications on web often require extra setup,
    // but this prevents crashes if parameters are missing.
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        print('Notification tapped: ${details.payload}');
      },
    );

    if (!kIsWeb) {
      // Create Android notification channel (Only for Android)
      const channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    print('✅ Local notifications initialized');
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('📬 Foreground message received:');
    print('Title: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');
    print('Data: ${message.data}');

    _showLocalNotification(message);
  }

  void _handleNotificationTap(RemoteMessage message) {
    print('🔔 Notification tapped:');
    print('Title: ${message.notification?.title}');
    print('Data: ${message.data}');
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    // Local Notifications on Web usually don't work with this plugin easily.
    // We skip this on web to prevent errors, as the Service Worker handles background,
    // and we can use standard browser alerts or custom UI for foreground if needed.
    if (kIsWeb) return;

    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'New Notification',
      message.notification?.body ?? '',
      details,
      payload: message.data.toString(),
    );
  }

  Future<void> subscribeToTopics(String userRole) async {
    // ⚠️ STOP: Do not run topic logic on Web
    if (kIsWeb) {
      print('ℹ️ Web does not support client-side topic subscription. Skipping.');
      return;
    }

    await unsubscribeFromAllTopics();
    print('🔄 Subscribing to topics for role: $userRole');

    await _firebaseMessaging.subscribeToTopic(_globalAnnouncementsTopic);
    print('✅ Subscribed to: $_globalAnnouncementsTopic');

    if (isManagerRole(userRole)) {
      await _firebaseMessaging.subscribeToTopic(_managersTopic);
      print('✅ Subscribed to: $_managersTopic');
    }

    if (userRole == UserRoles.technicienST) {
      await _firebaseMessaging.subscribeToTopic(_techStTopic);
      print('✅ Subscribed to: $_techStTopic');
    }

    if (userRole == UserRoles.technicienIT) {
      await _firebaseMessaging.subscribeToTopic(_techItTopic);
      print('✅ Subscribed to: $_techItTopic');
    }

    final managementRoles = [
      UserRoles.pdg,
      UserRoles.admin,
      UserRoles.responsableAdministratif,
      UserRoles.responsableCommercial,
      UserRoles.responsableTechnique,
      UserRoles.responsableIT,
      UserRoles.chefDeProjet,
      UserRoles.technicienST,
      UserRoles.technicienIT,
    ];

    if (managementRoles.contains(userRole)) {
      final topic = _roleToTopic(userRole);
      await _firebaseMessaging.subscribeToTopic(topic);
      print('✅ Subscribed to management topic: $topic');
    }

    if (userRole == UserRoles.admin) {
      final topic = _roleToTopic(UserRoles.admin);
      await _firebaseMessaging.subscribeToTopic(topic);
    }

    if (userRole == UserRoles.responsableAdministratif) {
      final topic = _roleToTopic(UserRoles.responsableAdministratif);
      await _firebaseMessaging.subscribeToTopic(topic);
    }

    if (userRole == UserRoles.responsableCommercial) {
      final topic = _roleToTopic(UserRoles.responsableCommercial);
      await _firebaseMessaging.subscribeToTopic(topic);
    }
  }

  bool isManagerRole(String userRole) {
    return [
      UserRoles.admin,
      UserRoles.pdg,
      UserRoles.responsableAdministratif,
      UserRoles.responsableCommercial,
      UserRoles.responsableTechnique,
      UserRoles.responsableIT,
      UserRoles.chefDeProjet,
    ].contains(userRole);
  }

  Future<void> unsubscribeFromAllTopics() async {
    // ⚠️ STOP: Do not run topic logic on Web
    if (kIsWeb) return;

    print('🔄 Unsubscribing from all topics...');

    await _firebaseMessaging.unsubscribeFromTopic(_globalAnnouncementsTopic);
    await _firebaseMessaging.unsubscribeFromTopic(_managersTopic);
    await _firebaseMessaging.unsubscribeFromTopic(_techStTopic);
    await _firebaseMessaging.unsubscribeFromTopic(_techItTopic);

    final managementRoles = [
      UserRoles.pdg,
      UserRoles.admin,
      UserRoles.responsableAdministratif,
      UserRoles.responsableCommercial,
      UserRoles.responsableTechnique,
      UserRoles.responsableIT,
      UserRoles.chefDeProjet,
      UserRoles.technicienST,
      UserRoles.technicienIT,
    ];

    for (final role in managementRoles) {
      await _firebaseMessaging.unsubscribeFromTopic(_roleToTopic(role));
    }

    await _firebaseMessaging.unsubscribeFromTopic(_roleToTopic(UserRoles.admin));
    await _firebaseMessaging.unsubscribeFromTopic(_roleToTopic(UserRoles.responsableAdministratif));
    await _firebaseMessaging.unsubscribeFromTopic(_roleToTopic(UserRoles.responsableCommercial));

    print('✅ Unsubscribed from all topics');
  }

  Future<void> saveTokenForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('⚠️ No user logged in, cannot save token');
      return;
    }

    String? token;

    // 1. Get the token based on the platform
    if (kIsWeb) {
      // Use your VAPID key here
      token = await _firebaseMessaging.getToken(
        vapidKey: "BHexKZZ060QNgZVUSRoBXyIcTP-jyxDUo1-M6o0mPbeYFFaQo9OIyRfw15hGBNtHSo9jbQldoiauFjE1FlI5iXo",
      );
    } else {
      // Mobile (Android/iOS)
      token = await _firebaseMessaging.getToken();
    }

    if (token == null) {
      print('⚠️ Could not get FCM token');
      return;
    }

    // 2. Decide which field to update
    // We update ONE specific field and leave the other one alone.
    final tokenField = kIsWeb ? 'fcmTokenWeb' : 'fcmTokenMobile';

    print('💾 Saving $tokenField: $token');

    // 3. Save to Firestore
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      tokenField: token, // <--- Saves to either 'fcmTokenWeb' or 'fcmTokenMobile'
      'lastTokenUpdate': FieldValue.serverTimestamp(),
      'platform': kIsWeb ? 'web' : 'mobile', // Optional: Helps you debug later
    }, SetOptions(merge: true));

    print('✅ Token saved successfully to $tokenField');
  }
}