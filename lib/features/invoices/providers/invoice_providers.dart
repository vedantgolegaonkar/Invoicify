import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/invoice_model.dart';
import '../data/invoice_repository.dart';

final invoicesStreamProvider = StreamProvider.autoDispose<List<InvoiceModel>>((ref) {
  final repository = ref.watch(invoiceRepositoryProvider);
  return repository.streamAll();
});
