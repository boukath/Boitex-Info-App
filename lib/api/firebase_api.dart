// lib/api/firebase_api.dart

import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

// ✅ NEW IMPORT FOR CLOUD FUNCTIONS
import 'package:cloud_functions/cloud_functions.dart';

// 👇 IMPORT NAV KEY
import 'package:boitex_info_app/utils/nav_key.dart';

// 👇 IMPORT MODELS
import 'package:boitex_info_app/models/sav_ticket.dart';
import 'package:boitex_info_app/models/mission.dart';
import 'package:boitex_info_app/models/channel_model.dart';

// 👇 IMPORT DETAIL PAGES FOR ROUTING
import 'package:boitex_info_app/screens/service_technique/intervention_details_page.dart';
import 'package:boitex_info_app/screens/service_technique/sav_ticket_details_page.dart';
import 'package:boitex_info_app/screens/service_technique/installation_details_page.dart';
import 'package:boitex_info_app/screens/administration/mission_details_page.dart';
import 'package:boitex_info_app/screens/administration/livraison_details_page.dart';
import 'package:boitex_info_app/screens/administration/requisition_details_page.dart';
import 'package:boitex_info_app/screens/administration/project_details_page.dart';
import 'package:boitex_info_app/screens/administration/replacement_request_details_page.dart';
import 'package:boitex_info_app/screens/announce/channel_chat_page.dart';

class FirebaseApi {
  final _firebaseMessaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  // Topic names
  static const String _managersTopic = 'manager_notifications';
  static const String _techStTopic = 'technician_st_alerts';
  static const String _techItTopic = 'technician_it_alerts';
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
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🔄 App opened from Background Notification');
      _handleNavigation(message.data);
    });

    // Check if app was opened from a notification (Terminated State)
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      print('🚀 App launched from Terminated state via Notification');
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleNavigation(initialMessage.data);
      });
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
        print('Notification tapped payload: ${details.payload}');
        if (details.payload != null) {
          try {
            final data = json.decode(details.payload!);
            _handleNavigation(data);
          } catch (e) {
            print('Error parsing notification payload: $e');
          }
        }
      },
    );

    if (!kIsWeb) {
      const channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    print('✅ Local notifications initialized');
  }

  Future<void> _handleNavigation(Map<String, dynamic> data) async {
    final context = navigatorKey.currentState?.context;
    if (context == null) {
      print('⚠️ Navigator Context is null, cannot navigate.');
      return;
    }

    final String? collection = data['relatedCollection'];
    final String? docId = data['relatedDocId'];

    if (docId == null || collection == null) return;

    print('📍 Routing to: $collection -> $docId (Fetching data...)');

    String userRole = 'Utilisateur';
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        userRole = userDoc.data()?['role'] ?? 'Utilisateur';
      } catch (e) {
        print('Error fetching user role: $e');
      }
    }

    Widget? page;

    try {
      switch (collection) {
        case 'interventions':
          final doc = await FirebaseFirestore.instance
              .collection('interventions')
              .doc(docId)
              .get();
          if (doc.exists) {
            page = InterventionDetailsPage(interventionDoc: doc);
          }
          break;

        case 'sav_tickets':
          final doc = await FirebaseFirestore.instance
              .collection('sav_tickets')
              .doc(docId)
              .get();
          if (doc.exists) {
            final ticket =
            SavTicket.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
            page = SavTicketDetailsPage(ticket: ticket);
          }
          break;

        case 'missions':
          final doc = await FirebaseFirestore.instance
              .collection('missions')
              .doc(docId)
              .get();
          if (doc.exists) {
            final mission = Mission.fromFirestore(doc);
            page = MissionDetailsPage(mission: mission);
          }
          break;

        case 'installations':
          final doc = await FirebaseFirestore.instance
              .collection('installations')
              .doc(docId)
              .get();
          if (doc.exists) {
            page = InstallationDetailsPage(
                installationDoc: doc, userRole: userRole);
          }
          break;

        case 'livraisons':
          page = LivraisonDetailsPage(livraisonId: docId);
          break;

        case 'requisitions':
          page = RequisitionDetailsPage(
              requisitionId: docId, userRole: userRole);
          break;

        case 'projects':
          page = ProjectDetailsPage(projectId: docId, userRole: userRole);
          break;

        case 'replacement_requests':
          page = ReplacementRequestDetailsPage(requestId: docId);
          break;

        case 'channels':
          final doc = await FirebaseFirestore.instance
              .collection('channels')
              .doc(docId)
              .get();
          if (doc.exists) {
            final channel = ChannelModel.fromFirestore(doc);
            page = ChannelChatPage(channel: channel);
          }
          break;

        default:
          print('⚠️ Unknown collection type for navigation: $collection');
      }

      if (page != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (context) => page!),
        );
      } else {
        print('⚠️ Document not found or Page creation failed for $docId');
      }
    } catch (e) {
      print('❌ Error during navigation fetch: $e');
    }
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
    // 🌍 WEB FIX: Show an in-app SnackBar because browsers block system notifications when focused
    if (kIsWeb) {
      final context = navigatorKey.currentState?.context;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.notification?.title != null)
                  Text(
                    message.notification!.title!,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                if (message.notification?.body != null)
                  Text(message.notification!.body!),
              ],
            ),
            backgroundColor: Colors.blueGrey.shade900,
            behavior: SnackBarBehavior.floating,
            width: 400, // Fixed width for web looks better
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'VOIR',
              textColor: Colors.orangeAccent,
              onPressed: () {
                // Trigger the same navigation logic as tapping a notification
                _handleNavigation(message.data);
              },
            ),
          ),
        );
      }
      return;
    }

    // 📱 MOBILE LOGIC (Remains unchanged)
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
      payload: json.encode(message.data),
    );
  }

  // ⭐️⭐️ THIS IS THE FIXED METHOD ⭐️⭐️
  Future<void> subscribeToTopics(String userRole) async {
    // 1. Build the list of topics this user *should* have
    List<String> topicsToSubscribe = [];

    // Always subscribe to global
    topicsToSubscribe.add(_globalAnnouncementsTopic);

    if (isManagerRole(userRole)) {
      topicsToSubscribe.add(_managersTopic);
    }

    if (userRole == UserRoles.technicienST) {
      topicsToSubscribe.add(_techStTopic);
    }

    if (userRole == UserRoles.technicienIT) {
      topicsToSubscribe.add(_techItTopic);
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
      topicsToSubscribe.add(topic);
    }

    if (userRole == UserRoles.admin) {
      topicsToSubscribe.add(_roleToTopic(UserRoles.admin));
    }
    if (userRole == UserRoles.responsableAdministratif) {
      topicsToSubscribe.add(_roleToTopic(UserRoles.responsableAdministratif));
    }
    if (userRole == UserRoles.responsableCommercial) {
      topicsToSubscribe.add(_roleToTopic(UserRoles.responsableCommercial));
    }

    // 2. Unsubscribe logic (Optional but good for role changes)
    await unsubscribeFromAllTopics();
    print('🔄 Subscribing to topics for role: $userRole');

    // 3. 🛑 EXECUTE SUBSCRIPTION BASED ON PLATFORM 🛑
    if (kIsWeb) {
      // ✅ WEB PATH: Use Cloud Function with RETRY Logic
      print('🌍 Web detected: Delegating subscription to Server...');

      String? token;
      // 🔄 RETRY LOGIC: Try 3 times to wait for Service Worker
      for (int i = 0; i < 3; i++) {
        try {
          token = await _firebaseMessaging.getToken(
              vapidKey: "BHexKZZ060QNgZVUSRoBXyIcTP-jyxDUo1-M6o0mPbeYFFaQo9OIyRfw15hGBNtHSo9jbQldoiauFjE1FlI5iXo"
          );
          if (token != null) break; // Success! Exit loop.
        } catch (e) {
          print('⏳ Waiting for Service Worker (Attempt ${i + 1}/3)...');
          await Future.delayed(const Duration(milliseconds: 1000)); // Wait 1s
        }
      }

      try {
        if (token != null) {
          // Call the Cloud Function we just created
          final result = await FirebaseFunctions.instanceFor(region: 'europe-west1')
              .httpsCallable('subscribeToTopicsWeb')
              .call({
            'token': token,
            'topics': topicsToSubscribe,
          });
          print('✅ Web Topics Subscribed via Server: ${result.data}');
        } else {
          print('⚠️ Web Token was null, could not subscribe.');
        }
      } catch (e) {
        print('❌ Failed to subscribe web topics via server: $e');
      }
    } else {
      // 📱 MOBILE PATH: Direct Subscription
      print('📱 Mobile detected: Subscribing directly...');
      for (final topic in topicsToSubscribe) {
        await _firebaseMessaging.subscribeToTopic(topic);
        print('✅ Subscribed to: $topic');
      }
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
    // Note: We don't have an easy "Unsubscribe All" for Web via Server yet,
    // so we skip it for Web to avoid errors. The Cloud Function only *adds* topics.
    // Over time, tokens expire anyway.
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

    await _firebaseMessaging
        .unsubscribeFromTopic(_roleToTopic(UserRoles.admin));
    await _firebaseMessaging
        .unsubscribeFromTopic(_roleToTopic(UserRoles.responsableAdministratif));
    await _firebaseMessaging
        .unsubscribeFromTopic(_roleToTopic(UserRoles.responsableCommercial));

    print('✅ Unsubscribed from all topics');
  }

  Future<void> saveTokenForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('⚠️ No user logged in, cannot save token');
      return;
    }

    String? token;

    if (kIsWeb) {
      token = await _firebaseMessaging.getToken(
        vapidKey:
        "BHexKZZ060QNgZVUSRoBXyIcTP-jyxDUo1-M6o0mPbeYFFaQo9OIyRfw15hGBNtHSo9jbQldoiauFjE1FlI5iXo",
      );
    } else {
      token = await _firebaseMessaging.getToken();
    }

    if (token == null) {
      print('⚠️ Could not get FCM token');
      return;
    }

    final tokenField = kIsWeb ? 'fcmTokenWeb' : 'fcmTokenMobile';

    print('💾 Saving $tokenField: $token');

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      tokenField: token,
      'lastTokenUpdate': FieldValue.serverTimestamp(),
      'platform': kIsWeb ? 'web' : 'mobile',
    }, SetOptions(merge: true));

    print('✅ Token saved successfully to $tokenField');
  }
}