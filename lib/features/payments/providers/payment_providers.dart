import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/payment_model.dart';
import '../data/payment_repository.dart';

final paymentsStreamProvider = StreamProvider<List<PaymentModel>>((ref) {
  final repository = ref.watch(paymentRepositoryProvider);
  return repository.streamAll();
});
