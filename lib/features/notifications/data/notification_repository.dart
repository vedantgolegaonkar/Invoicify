import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/repositories/base_repository.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../domain/notification_model.dart';
import '../../../../services/firestore_service.dart';
import '../../authentication/presentation/providers/auth_provider.dart';

class NotificationRepository extends BaseRepository<NotificationModel> {
  NotificationRepository(FirestoreService firestoreService, String userId)
      : super(firestoreService, 'users/$userId/notifications');

  @override
  NotificationModel fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel.fromMap(map, id);
  }

  @override
  Map<String, dynamic> toMap(NotificationModel item) {
    return item.toMap();
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final userId = ref.watch(authUserIdProvider) ?? 'unauthenticated';
  return NotificationRepository(firestoreService, userId);
});
