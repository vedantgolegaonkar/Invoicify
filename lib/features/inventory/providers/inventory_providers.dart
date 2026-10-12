import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/inventory_repository.dart';
import '../domain/inventory_transaction_model.dart';

final inventoryTransactionsStreamProvider =
    StreamProvider.autoDispose<List<InventoryTransactionModel>>((ref) {
  final repository = ref.watch(inventoryRepositoryProvider);
  return repository.streamAll();
});
