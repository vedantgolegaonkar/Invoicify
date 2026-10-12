import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../../shared/widgets/loading_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../providers/invoice_providers.dart';
import '../../domain/invoice_model.dart';
import 'package:intl/intl.dart';
import '../../../customers/providers/customer_providers.dart';
import '../../../orders/providers/order_providers.dart';

class InvoiceSearchQuery extends Notifier<String> {
  @override
  String build() => '';
  void setQuery(String query) => state = query;
}
final invoiceSearchQueryProvider = NotifierProvider<InvoiceSearchQuery, String>(InvoiceSearchQuery.new);

class InvoiceStatusFilter extends Notifier<String> {
  @override
  String build() => 'All';
  void setFilter(String filter) => state = filter;
}
final invoiceStatusFilterProvider = NotifierProvider<InvoiceStatusFilter, String>(InvoiceStatusFilter.new);

class InvoiceListScreen extends ConsumerWidget {
  const InvoiceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(invoiceSearchQueryProvider);
    final statusFilter = ref.watch(invoiceStatusFilterProvider);

    final invoicesAsync = ref.watch(invoicesStreamProvider);
    final customersAsync = ref.watch(customersStreamProvider);
    final ordersAsync = ref.watch(ordersStreamProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(
            pinned: true,
            expandedHeight: 120.0,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text('Invoices', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  // Search Bar
                  SearchBar(
                    hintText: 'Search by invoice # or customer',
                    leading: const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(Icons.search, color: Colors.grey),
                    ),
                    onChanged: (value) => ref.read(invoiceSearchQueryProvider.notifier).setQuery(value),
                    elevation: WidgetStateProperty.all(0),
                    backgroundColor: WidgetStateProperty.all(
                      Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    ),
                    padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 8)),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Filters
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildFilterChip(context, ref, 'All', 'All', statusFilter),
                        const SizedBox(width: 8),
                        _buildFilterChip(context, ref, 'Paid', 'Paid', statusFilter),
                        const SizedBox(width: 8),
                        _buildFilterChip(context, ref, 'Unpaid', 'Unpaid', statusFilter),
                        const SizedBox(width: 8),
                        _buildFilterChip(context, ref, 'Partially Paid', 'PartiallyPaid', statusFilter),
                        const SizedBox(width: 8),
                        _buildFilterChip(context, ref, 'Cancelled', 'Cancelled', statusFilter),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          invoicesAsync.when(
            loading: () => const SliverFillRemaining(
              child: LoadingState(message: 'Loading invoices...'),
            ),
            error: (error, stack) => SliverFillRemaining(
              child: ErrorState(
                message: error.toString(),
                onRetry: () => ref.refresh(invoicesStreamProvider),
              ),
            ),
            data: (invoices) {
              final orders = ordersAsync.value ?? [];
              final cancelledOrderIds = orders
                  .where((o) => o.status.name == 'cancelled')
                  .map((o) => o.id)
                  .toSet();

              final filteredInvoices = invoices.where((inv) {
                final isCancelled = cancelledOrderIds.contains(inv.orderId);

                final matchesSearch = inv.invoiceNumber.toLowerCase().contains(searchQuery.toLowerCase()) || 
                                      inv.customerId.toLowerCase().contains(searchQuery.toLowerCase());
                
                bool matchesStatus = false;
                if (statusFilter == 'Cancelled') {
                  matchesStatus = isCancelled;
                } else {
                  if (isCancelled) return false; // Do not show cancelled in other tabs
                  if (statusFilter == 'All') {
                    matchesStatus = true;
                  } else {
                    matchesStatus = inv.status.name == statusFilter;
                  }
                }

                return matchesSearch && matchesStatus;
              }).toList();

              filteredInvoices.sort((a, b) => b.createdAt.compareTo(a.createdAt));

              if (filteredInvoices.isEmpty) {
                return SliverFillRemaining(
                  child: EmptyState(
                    title: 'No Invoices Found',
                    message: searchQuery.isEmpty && statusFilter == 'All' 
                        ? 'Generate a new invoice.' 
                        : 'Try adjusting your search or filters.',
                    icon: Icons.receipt_long,
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final invoice = filteredInvoices[index];
                      final customers = customersAsync.value ?? [];
                      final customerMatches = customers.where((c) => c.id == invoice.customerId).toList();
                      final customerName = customerMatches.isNotEmpty ? customerMatches.first.name : 'Unknown Customer';
                      final isCancelled = cancelledOrderIds.contains(invoice.orderId);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _InvoiceCard(
                          invoice: invoice, 
                          customerName: customerName,
                          isCancelled: isCancelled,
                        ),
                      );
                    },
                    childCount: filteredInvoices.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: statusFilter == 'Cancelled' ? null : FloatingActionButton.extended(
        onPressed: () => context.push('/invoices/create'),
        icon: const Icon(Icons.add),
        label: const Text('New Invoice'),
        elevation: 4,
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, WidgetRef ref, String label, String status, String currentFilter) {
    final isSelected = currentFilter == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => ref.read(invoiceStatusFilterProvider.notifier).setFilter(status),
      showCheckmark: false,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: isSelected 
            ? Theme.of(context).colorScheme.onPrimaryContainer 
            : Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
        ),
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final InvoiceModel invoice;
  final String customerName;
  final bool isCancelled;

  const _InvoiceCard({
    required this.invoice, 
    required this.customerName,
    required this.isCancelled,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    Color getStatusColor(bool isCancelled) {
      if (isCancelled) return Colors.redAccent;
      switch (invoice.status) {
        case InvoiceStatus.paid:
          return Colors.green;
        case InvoiceStatus.unpaid:
          return Colors.red;
        case InvoiceStatus.partiallyPaid:
          return Colors.orange;
      }
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/invoices/${invoice.id}'),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Colored left border indicating status
              Container(
                width: 6,
                color: getStatusColor(isCancelled),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Invoice #${invoice.invoiceNumber}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  customerName,
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          isCancelled ? StatusChip.cancelled() : _buildStatusChip(invoice.status),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${invoice.items.length} item${invoice.items.length == 1 ? '' : 's'}',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('MMM dd, yyyy').format(invoice.createdAt),
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '₹${invoice.total.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return StatusChip.paid();
      case InvoiceStatus.partiallyPaid:
        return StatusChip.partiallyPaid();
      case InvoiceStatus.unpaid:
        return StatusChip.unpaid();
    }
  }
}
