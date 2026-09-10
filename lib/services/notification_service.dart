import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Optionnel : gérer la réception en arrière-plan (sans affichage, juste traitement de données)
  debugPrint("Handling a background message: ${message.messageId}");
}

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static String? pendingRoute;

  GlobalKey<NavigatorState>? _navigatorKey;

  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  Future<void> init(String userId) async {
    // Demander la permission
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission for notifications');
      
      // Configuration Android pour les notifications locales (premier plan)
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);
      
      await _localNotifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null) {
            _handleNotificationTap(response.payload!);
          }
        },
      );

      // Création du channel Android
      if (Platform.isAndroid) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'commandes_channel', // id
          'Statut des commandes', // name
          description: 'Notifications pour le suivi des commandes.',
          importance: Importance.max,
          playSound: true,
        );

        await _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
      }

      // Enregistrer le token
      await _saveToken(userId);

      // Écouter le rafraîchissement du token
      _messaging.onTokenRefresh.listen((token) {
        _saveTokenToFirestore(token, userId);
      });

      // Gestion des messages en premier plan
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');

        if (message.notification != null) {
          debugPrint('Message also contained a notification: ${message.notification}');
          _showLocalNotification(message);
        }
      });

      // Gestion du clic quand l'app est en arrière plan
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('A new onMessageOpenedApp event was published!');
        _handleMessageAction(message);
      });

      // Gestion du clic (Cold Start)
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      _checkInitialMessage();
    }
  }

  Future<void> _checkInitialMessage() async {
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('App opened from cold start via notification');
      if (initialMessage.data.containsKey('order_id')) {
        pendingRoute = '/order/${initialMessage.data['order_id']}';
      }
    }
  }

  void _handleMessageAction(RemoteMessage message) {
    if (message.data.containsKey('order_id')) {
      final orderId = message.data['order_id'];
      _navigateToOrder(orderId);
    }
  }

  void _handleNotificationTap(String payload) {
    try {
      final data = jsonDecode(payload);
      if (data['order_id'] != null) {
        _navigateToOrder(data['order_id']);
      }
    } catch (e) {
      debugPrint("Erreur décodage payload: $e");
    }
  }

  void _navigateToOrder(String orderId) {
    if (_navigatorKey != null && _navigatorKey!.currentContext != null) {
      _navigatorKey!.currentContext!.go('/order/$orderId');
    } else {
      debugPrint("NavigatorKey is null or context is null, retrying in 1s...");
      Future.delayed(const Duration(seconds: 1), () {
        if (_navigatorKey != null && _navigatorKey!.currentContext != null) {
          _navigatorKey!.currentContext!.go('/order/$orderId');
        }
      });
    }
  }

  Future<void> _saveToken(String userId) async {
    String? token = await _messaging.getToken();
    if (token != null) {
      await _saveTokenToFirestore(token, userId);
    }
  }

  Future<void> _saveTokenToFirestore(String token, String userId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set(
        {'fcm_token': token},
        SetOptions(merge: true),
      );
      debugPrint("Token enregistré pour l'utilisateur $userId");
    } catch (e) {
      debugPrint("Erreur lors de l'enregistrement du token : $e");
    }
  }

  void showNotificationTest() {
    _localNotifications.show(
      id: 0,
      title: 'Test',
      body: 'Ceci est un test',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'commandes_channel',
          'Statut des commandes',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }

  void _showLocalNotification(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'commandes_channel',
            'Statut des commandes',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }
}
