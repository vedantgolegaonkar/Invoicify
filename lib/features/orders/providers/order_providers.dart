import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/order_model.dart';
import '../data/order_repository.dart';

import '../../authentication/presentation/providers/auth_provider.dart';

final ordersStreamProvider = StreamProvider<List<OrderModel>>((ref) {
  final userId = ref.watch(authUserIdProvider);
  if (userId == null || userId == 'unauthenticated') {
    return const Stream.empty();
  }
  final repository = ref.watch(orderRepositoryProvider);
  return repository.streamAll();
});
