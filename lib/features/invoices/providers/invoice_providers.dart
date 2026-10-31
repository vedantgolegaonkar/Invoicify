import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/invoice_model.dart';
import '../data/invoice_repository.dart';

import '../../authentication/presentation/providers/auth_provider.dart';

final invoicesStreamProvider = StreamProvider<List<InvoiceModel>>((ref) {
  final userId = ref.watch(authUserIdProvider);
  if (userId == null || userId == 'unauthenticated') {
    return const Stream.empty();
  }
  final repository = ref.watch(invoiceRepositoryProvider);
  return repository.streamAll();
});
