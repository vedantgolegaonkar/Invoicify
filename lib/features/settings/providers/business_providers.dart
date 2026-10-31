import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/business_model.dart';
import '../data/business_repository.dart';

import '../../authentication/presentation/providers/auth_provider.dart';

/// Streams all business profiles (usually just one).
final businessStreamProvider = StreamProvider.autoDispose<List<BusinessModel>>((ref) {
  final userId = ref.watch(authUserIdProvider);
  if (userId == null || userId == 'unauthenticated') {
    return const Stream.empty();
  }
  final repository = ref.watch(businessRepositoryProvider);
  return repository.streamAll();
});

/// Convenience provider that resolves the first (primary) business profile.
final primaryBusinessProvider = Provider.autoDispose<BusinessModel?>((ref) {
  final businesses = ref.watch(businessStreamProvider);
  return businesses.value?.isNotEmpty == true ? businesses.value!.first : null;
});
