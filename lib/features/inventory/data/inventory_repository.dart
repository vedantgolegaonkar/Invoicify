import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/repositories/base_repository.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../domain/inventory_transaction_model.dart';
import '../../../../services/firestore_service.dart';
import '../../authentication/presentation/providers/auth_provider.dart';

class InventoryRepository extends BaseRepository<InventoryTransactionModel> {
  InventoryRepository(FirestoreService firestoreService, String userId)
      : super(firestoreService, 'users/$userId/inventory_transactions');

  @override
  InventoryTransactionModel fromMap(Map<String, dynamic> map, String id) {
    return InventoryTransactionModel.fromMap(map, id);
  }

  @override
  Map<String, dynamic> toMap(InventoryTransactionModel item) {
    return item.toMap();
  }
}

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final userId = ref.watch(authUserIdProvider) ?? 'unauthenticated';
  return InventoryRepository(firestoreService, userId);
});
