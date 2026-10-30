import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      // Currently this app is Android only, but you could add iOS here
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Handle notification tap if needed
        },
      );
    } catch (_) {
      // Avoid crashing the entire app if notification channels or icons fail
    }
  }

  Future<bool> requestPermissions() async {
    try {
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<void> showLowStockNotification({
    required String productId,
    required String productName,
    required double currentStock,
  }) async {
    // Check if permission is granted before showing
    final status = await Permission.notification.status;
    if (!status.isGranted) return;

    // We use a deterministic ID based on the product so it updates an existing notification 
    // rather than spamming multiple for the same product.
    final notificationId = productId.hashCode;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'inventory_alerts', // id
      'Inventory Alerts', // title
      channelDescription: 'Notifications for low stock items',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Low Stock Alert',
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      id: notificationId,
      title: 'Low Stock Alert: $productName',
      body: 'Stock has dropped to $currentStock units.',
      notificationDetails: platformChannelSpecifics,
      payload: productId,
    );
  }
}
