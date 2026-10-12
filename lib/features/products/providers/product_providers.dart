import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/product_model.dart';
import '../data/product_repository.dart';

final productsStreamProvider = StreamProvider.autoDispose<List<ProductModel>>((ref) {
  final repository = ref.watch(productRepositoryProvider);
  return repository.streamAll();
});
