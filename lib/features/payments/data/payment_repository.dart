import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/repositories/base_repository.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../domain/payment_model.dart';
import '../../../../services/firestore_service.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../authentication/presentation/providers/auth_provider.dart';

class PaymentRepository extends BaseRepository<PaymentModel> {
  PaymentRepository(FirestoreService firestoreService, String userId, {Future<void> Function(String, String)? onLogNotification})
      : super(firestoreService, 'users/$userId/payments', onLogNotification: onLogNotification);

  @override
  PaymentModel fromMap(Map<String, dynamic> map, String id) {
    return PaymentModel.fromMap(map, id);
  }

  @override
  Map<String, dynamic> toMap(PaymentModel item) {
    return item.toMap();
  }
}

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final logger = ref.watch(notificationLoggerProvider);
  final userId = ref.watch(authUserIdProvider) ?? 'unauthenticated';
  return PaymentRepository(firestoreService, userId, onLogNotification: logger);
});
