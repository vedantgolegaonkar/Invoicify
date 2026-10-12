import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/repositories/base_repository.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../domain/order_model.dart';
import '../../../../services/firestore_service.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../authentication/presentation/providers/auth_provider.dart';

class OrderRepository extends BaseRepository<OrderModel> {
  OrderRepository(FirestoreService firestoreService, String userId, {Future<void> Function(String, String)? onLogNotification})
      : super(firestoreService, 'users/$userId/orders', onLogNotification: onLogNotification);

  @override
  OrderModel fromMap(Map<String, dynamic> map, String id) {
    return OrderModel.fromMap(map, id);
  }

  @override
  Map<String, dynamic> toMap(OrderModel item) {
    return item.toMap();
  }
}

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final logger = ref.watch(notificationLoggerProvider);
  final userId = ref.watch(authUserIdProvider) ?? 'unauthenticated';
  return OrderRepository(firestoreService, userId, onLogNotification: logger);
});
