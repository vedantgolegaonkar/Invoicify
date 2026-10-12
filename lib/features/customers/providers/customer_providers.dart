import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/customer_model.dart';
import '../data/customer_repository.dart';
import '../../invoices/providers/invoice_providers.dart';
import '../../payments/providers/payment_providers.dart';

final customersStreamProvider = StreamProvider.autoDispose<List<CustomerModel>>((ref) {
  final repository = ref.watch(customerRepositoryProvider);
  return repository.streamAll();
});

/// A provider that dynamically calculates the exact current outstanding
/// balance for all customers based on their invoices and payments.
final enrichedCustomersProvider = Provider.autoDispose<AsyncValue<List<CustomerModel>>>((ref) {
  final customersAsync = ref.watch(customersStreamProvider);
  final invoicesAsync = ref.watch(invoicesStreamProvider);
  final paymentsAsync = ref.watch(paymentsStreamProvider);

  if (customersAsync.isLoading || invoicesAsync.isLoading || paymentsAsync.isLoading) {
    return const AsyncValue.loading();
  }

  if (customersAsync.hasError) {
    return AsyncValue.error(customersAsync.error!, customersAsync.stackTrace!);
  }

  final customers = customersAsync.value ?? [];
  final invoices = invoicesAsync.value ?? [];
  final payments = paymentsAsync.value ?? [];

  // Map each customer to a new model with computed outstanding
  final enrichedCustomers = customers.map((customer) {
    final customerInvoices = invoices.where((i) => i.customerId == customer.id);
    final customerPayments = payments.where((p) => p.customerId == customer.id);

    final totalInvoiced = customerInvoices.fold<double>(0.0, (sum, inv) => sum + inv.total);
    final totalPaid = customerPayments.fold<double>(0.0, (sum, pay) => sum + pay.amount);
    
    final computedOutstanding = totalInvoiced - totalPaid;

    return customer.copyWith(currentOutstanding: computedOutstanding);
  }).toList();

  return AsyncValue.data(enrichedCustomers);
});
