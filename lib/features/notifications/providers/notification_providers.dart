import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/notification_repository.dart';
import '../domain/notification_model.dart';

final notificationsStreamProvider = StreamProvider.autoDispose<List<NotificationModel>>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.streamAll();
});

final unreadNotificationsCountProvider = Provider.autoDispose<int>((ref) {
  final notificationsAsync = ref.watch(notificationsStreamProvider);
  return notificationsAsync.maybeWhen(
    data: (notifications) => notifications.where((n) => !n.isRead && !n.isDeleted).length,
    orElse: () => 0,
  );
});

final notificationLoggerProvider = Provider<Future<void> Function(String, String)>((ref) {
  return (String title, String message) async {
    final repository = ref.read(notificationRepositoryProvider);
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();
    final notification = NotificationModel(
      id: id,
      title: title,
      message: message,
      isRead: false,
      createdAt: now,
      updatedAt: now,
    );
    try {
      await repository.create(notification, id);
    } catch (e) {
      // Ignore logging failures so it doesn't break app flow
    }
  };
});
