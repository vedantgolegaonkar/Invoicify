import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/product_model.dart';
import '../data/product_repository.dart';

import '../../authentication/presentation/providers/auth_provider.dart';

final productsStreamProvider = StreamProvider<List<ProductModel>>((ref) {
  final userId = ref.watch(authUserIdProvider);
  if (userId == null || userId == 'unauthenticated') {
    return const Stream.empty();
  }
  final repository = ref.watch(productRepositoryProvider);
  return repository.streamAll();
});
