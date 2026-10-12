import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/repositories/base_repository.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../domain/product_model.dart';
import '../../../../services/firestore_service.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../authentication/presentation/providers/auth_provider.dart';

class ProductRepository extends BaseRepository<ProductModel> {
  ProductRepository(FirestoreService firestoreService, String userId, {Future<void> Function(String, String)? onLogNotification})
      : super(firestoreService, 'users/$userId/products', onLogNotification: onLogNotification);

  @override
  ProductModel fromMap(Map<String, dynamic> map, String id) {
    return ProductModel.fromMap(map, id);
  }

  @override
  Map<String, dynamic> toMap(ProductModel item) {
    return item.toMap();
  }
}

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final logger = ref.watch(notificationLoggerProvider);
  final userId = ref.watch(authUserIdProvider) ?? 'unauthenticated';
  return ProductRepository(firestoreService, userId, onLogNotification: logger);
});
