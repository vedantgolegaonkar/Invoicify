import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/repositories/base_repository.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../domain/customer_model.dart';
import '../../../../services/firestore_service.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../authentication/presentation/providers/auth_provider.dart';

class CustomerRepository extends BaseRepository<CustomerModel> {
  CustomerRepository(FirestoreService firestoreService, String userId, {Future<void> Function(String, String)? onLogNotification})
      : super(firestoreService, 'users/$userId/customers', onLogNotification: onLogNotification);

  @override
  CustomerModel fromMap(Map<String, dynamic> map, String id) {
    return CustomerModel.fromMap(map, id);
  }

  @override
  Map<String, dynamic> toMap(CustomerModel item) {
    return item.toMap();
  }
}

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final logger = ref.watch(notificationLoggerProvider);
  final userId = ref.watch(authUserIdProvider) ?? 'unauthenticated';
  return CustomerRepository(firestoreService, userId, onLogNotification: logger);
});
