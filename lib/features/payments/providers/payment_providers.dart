import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/payment_model.dart';
import '../data/payment_repository.dart';

import '../../authentication/presentation/providers/auth_provider.dart';

final paymentsStreamProvider = StreamProvider<List<PaymentModel>>((ref) {
  final userId = ref.watch(authUserIdProvider);
  if (userId == null || userId == 'unauthenticated') {
    return const Stream.empty();
  }
  final repository = ref.watch(paymentRepositoryProvider);
  return repository.streamAll();
});
