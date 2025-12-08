import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initializationSettings);
  }

  Future<void> showEmergencyAlert({required String title, required String body}) async {
    const androidDetails = AndroidNotificationDetails(
      'theia_emergency_channel',
      'Emergency Alerts',
      importance: Importance.max,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);
    await _plugin.show(0, title, body, notificationDetails, payload: 'emergency');
  }
}
