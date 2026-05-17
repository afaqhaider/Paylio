import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    try {
      // Request permissions for iOS
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('NotificationService: User granted permission');
      } else {
        debugPrint('NotificationService: User declined or has not accepted permission');
      }

      // Get the token each time the app starts
      await _saveToken();

      // Listen for token refresh
      _fcm.onTokenRefresh.listen((newToken) {
        _updateTokenInFirestore(newToken);
      });

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('NotificationService: Got a message whilst in the foreground!');
        debugPrint('NotificationService: Message data: ${message.data}');

        if (message.notification != null) {
          debugPrint('NotificationService: Message also contained a notification: ${message.notification?.title}');
        }
      });
    } catch (e) {
      debugPrint("NotificationService Error: $e");
    }
  }

  static Future<void> _saveToken() async {
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        await _updateTokenInFirestore(token);
      }
    } catch (e) {
      debugPrint("NotificationService: Failed to get token: $e");
    }
  }

  static Future<void> _updateTokenInFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('NotificationService: FCM Token updated for user: ${user.uid}');
      } catch (e) {
        debugPrint("NotificationService: Failed to update token in Firestore: $e");
      }
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    debugPrint("NotificationService: Handling a background message: ${message.messageId}");
  }
}
