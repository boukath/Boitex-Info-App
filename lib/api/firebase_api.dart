// lib/api/firebase_api.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FirebaseApi {
  final _firebaseMessaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  // Topic names
  static const String _managersTopic = 'manager_notifications';
  static const String _techStTopic = 'technician_st_alerts';
  static const String _techItTopic = 'technician_it_alerts';

  // Helper function to convert role names to valid FCM topic names
  String _roleToTopic(String role) {
    // Replace spaces with underscores to make valid FCM topic names
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

    // Create Android notification channel
    const channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    print('✅ Local notifications initialized');
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('📬 Foreground message received:');
    print('Title: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');
    print('Data: ${message.data}');

    // Show notification when app is in foreground
    _showLocalNotification(message);
  }

  void _handleNotificationTap(RemoteMessage message) {
    print('🔔 Notification tapped:');
    print('Title: ${message.notification?.title}');
    print('Data: ${message.data}');
    // TODO: Add navigation logic here based on message.data
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
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
    await unsubscribeFromAllTopics();
    print('🔄 Subscribing to topics for role: $userRole');

    // Check if user is a manager
    if (isManagerRole(userRole)) {
      await _firebaseMessaging.subscribeToTopic(_managersTopic);
      print('✅ Subscribed to: $_managersTopic');
    }

    // Technician subscriptions
    if (userRole == UserRoles.technicienST) {
      await _firebaseMessaging.subscribeToTopic(_techStTopic);
      print('✅ Subscribed to: $_techStTopic');
    }

    if (userRole == UserRoles.technicienIT) {
      await _firebaseMessaging.subscribeToTopic(_techItTopic);
      print('✅ Subscribed to: $_techItTopic');
    }

    // ✅ Subscribe to requisition & project notifications for specific roles
    final managementRoles = [
      UserRoles.pdg,
      UserRoles.admin,
      UserRoles.responsableAdministratif,
      UserRoles.responsableCommercial,
      UserRoles.responsableTechnique,
      UserRoles.responsableIT,
      UserRoles.chefDeProjet,
    ];

    if (managementRoles.contains(userRole)) {
      final topic = _roleToTopic(userRole);
      await _firebaseMessaging.subscribeToTopic(topic);
      print('✅ Subscribed to management topic (projects & requisitions): $topic');
    }

    // REMINDER NOTIFICATIONS - Subscribe to role-specific reminder topics
    if (userRole == UserRoles.admin) {
      final topic = _roleToTopic(UserRoles.admin);
      await _firebaseMessaging.subscribeToTopic(topic);
      print('✅ Subscribed to reminder topic: $topic');
    }

    if (userRole == UserRoles.responsableAdministratif) {
      final topic = _roleToTopic(UserRoles.responsableAdministratif);
      await _firebaseMessaging.subscribeToTopic(topic);
      print('✅ Subscribed to reminder topic: $topic');
    }

    if (userRole == UserRoles.responsableCommercial) {
      final topic = _roleToTopic(UserRoles.responsableCommercial);
      await _firebaseMessaging.subscribeToTopic(topic);
      print('✅ Subscribed to reminder topic: $topic');
    }
  }

  // Helper function to check if a user is part of the manager group
  bool isManagerRole(String userRole) {
    return [
      UserRoles.admin,
      UserRoles.pdg,
      UserRoles.responsableTechnique,
      UserRoles.responsableIT,
      UserRoles.chefDeProjet,
    ].contains(userRole);
  }

  Future<void> unsubscribeFromAllTopics() async {
    print('🔄 Unsubscribing from all topics...');

    // Unsubscribe from existing topics
    await _firebaseMessaging.unsubscribeFromTopic(_managersTopic);
    await _firebaseMessaging.unsubscribeFromTopic(_techStTopic);
    await _firebaseMessaging.unsubscribeFromTopic(_techItTopic);

    // ✅ Unsubscribe from management topics (requisitions & projects)
    final managementRoles = [
      UserRoles.pdg,
      UserRoles.admin,
      UserRoles.responsableAdministratif,
      UserRoles.responsableCommercial,
      UserRoles.responsableTechnique,
      UserRoles.responsableIT,
      UserRoles.chefDeProjet,
    ];

    for (final role in managementRoles) {
      await _firebaseMessaging.unsubscribeFromTopic(_roleToTopic(role));
    }

    // REMINDER NOTIFICATIONS - Unsubscribe from reminder topics
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

    final token = await _firebaseMessaging.getToken();
    if (token == null) {
      print('⚠️ Could not get FCM token');
      return;
    }

    print('💾 Saving FCM token: $token');
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'fcmToken': token,
      'lastTokenUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    print('✅ FCM token saved successfully');
  }
}
