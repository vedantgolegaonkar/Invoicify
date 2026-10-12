import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/order_model.dart';
import '../data/order_repository.dart';

final ordersStreamProvider = StreamProvider.autoDispose<List<OrderModel>>((ref) {
  final repository = ref.watch(orderRepositoryProvider);
  return repository.streamAll();
});
