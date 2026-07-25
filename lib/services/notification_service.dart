import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/api_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize(ApiService apiService) async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
        const InitializationSettings initSettings = InitializationSettings(android: androidInit);

        await _localNotifications.initialize(initSettings);

        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'trade_alerts',
          'Trade Alerts',
          description: 'Instant notification alerts for trade executions',
          importance: Importance.high,
        );

        await _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);

        String? token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await _sendTokenToBackend(apiService, token);
        }

        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
          _sendTokenToBackend(apiService, newToken);
        });

        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          RemoteNotification? notification = message.notification;
          AndroidNotification? android = message.notification?.android;

          if (notification != null && android != null) {
            _localNotifications.show(
              notification.hashCode,
              notification.title,
              notification.body,
              NotificationDetails(
                android: AndroidNotificationDetails(
                  channel.id,
                  channel.name,
                  channelDescription: channel.description,
                  icon: '@mipmap/ic_launcher',
                  importance: Importance.max,
                  priority: Priority.high,
                ),
              ),
            );
          }
        });
      }
    } catch (e) {
      // Handle initialization gracefully if Firebase fails
    }
  }

  static Future<void> _sendTokenToBackend(ApiService apiService, String token) async {
    try {
      await apiService.postEndpoint('wallet.php?action=set_fcm_token', {
        'fcm_token': token,
      });
    } catch (e) {
      // Silence network errors on token sync
    }
  }
}
