import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../../shared/widgets/loading_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../providers/order_providers.dart';
import '../../domain/order_model.dart';
import 'package:intl/intl.dart';
import '../../../customers/providers/customer_providers.dart';

class OrderSearchQuery extends Notifier<String> {
  @override
  String build() => '';
  void setQuery(String query) => state = query;
}
final orderSearchQueryProvider = NotifierProvider<OrderSearchQuery, String>(OrderSearchQuery.new);

class OrderStatusFilter extends Notifier<OrderStatus?> {
  @override
  OrderStatus? build() => null;
  void setFilter(OrderStatus? filter) => state = filter;
}
final orderStatusFilterProvider = NotifierProvider<OrderStatusFilter, OrderStatus?>(OrderStatusFilter.new);

class OrderListScreen extends ConsumerWidget {
  const OrderListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(orderSearchQueryProvider);
    final statusFilter = ref.watch(orderStatusFilterProvider);

    final ordersAsync = ref.watch(ordersStreamProvider);
    final customersAsync = ref.watch(customersStreamProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(
            pinned: true,
            expandedHeight: 120.0,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text('Orders', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  // Search Bar
                  SearchBar(
                    hintText: 'Search by order # or customer',
                    leading: const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(Icons.search, color: Colors.grey),
                    ),
                    onChanged: (value) => ref.read(orderSearchQueryProvider.notifier).setQuery(value),
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
                        _buildFilterChip(context, ref, 'All', null, statusFilter),
                        const SizedBox(width: 8),
                        _buildFilterChip(context, ref, 'Draft', OrderStatus.draft, statusFilter),
                        const SizedBox(width: 8),
                        _buildFilterChip(context, ref, 'Confirmed', OrderStatus.confirmed, statusFilter),
                        const SizedBox(width: 8),
                        _buildFilterChip(context, ref, 'Delivered', OrderStatus.delivered, statusFilter),
                        const SizedBox(width: 8),
                        _buildFilterChip(context, ref, 'Cancelled', OrderStatus.cancelled, statusFilter),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          ordersAsync.when(
            loading: () => const SliverFillRemaining(
              child: LoadingState(message: 'Loading orders...'),
            ),
            error: (error, stack) => SliverFillRemaining(
              child: ErrorState(
                message: error.toString(),
                onRetry: () => ref.refresh(ordersStreamProvider),
              ),
            ),
            data: (orders) {
              final customers = customersAsync.value ?? [];
              
              final filteredOrders = orders.where((order) {
                final customerMatches = customers.where((c) => c.id == order.customerId).toList();
                final customerName = customerMatches.isNotEmpty ? customerMatches.first.name : 'Unknown Customer';
                
                final matchesSearch = order.orderNumber.toLowerCase().contains(searchQuery.toLowerCase()) || 
                                      customerName.toLowerCase().contains(searchQuery.toLowerCase());
                final matchesStatus = statusFilter == null || order.status == statusFilter;
                return matchesSearch && matchesStatus;
              }).toList();

              filteredOrders.sort((a, b) => b.orderDate.compareTo(a.orderDate));

              if (filteredOrders.isEmpty) {
                return SliverFillRemaining(
                  child: EmptyState(
                    title: 'No Orders Found',
                    message: searchQuery.isEmpty && statusFilter == null 
                        ? 'Create a new order for a customer.' 
                        : 'Try adjusting your search or filters.',
                    icon: Icons.shopping_cart_outlined,
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final order = filteredOrders[index];
                      final customerMatches = customers.where((c) => c.id == order.customerId).toList();
                      final customerName = customerMatches.isNotEmpty ? customerMatches.first.name : 'Unknown Customer';
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _OrderCard(order: order, customerName: customerName),
                      );
                    },
                    childCount: filteredOrders.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: (statusFilter == OrderStatus.cancelled || statusFilter == OrderStatus.delivered) ? null : FloatingActionButton.extended(
        onPressed: () => context.push('/orders/create'),
        icon: const Icon(Icons.add),
        label: const Text('New Order'),
        elevation: 4,
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, WidgetRef ref, String label, OrderStatus? status, OrderStatus? currentFilter) {
    final isSelected = currentFilter == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => ref.read(orderStatusFilterProvider.notifier).setFilter(status),
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

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final String customerName;

  const _OrderCard({required this.order, required this.customerName});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    Color getStatusColor() {
      switch (order.status) {
        case OrderStatus.confirmed:
          return Colors.blue;
        case OrderStatus.delivered:
          return Colors.green;
        case OrderStatus.cancelled:
          return Colors.red;
        case OrderStatus.draft:
        default:
          return Colors.grey.shade600;
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
        onTap: () => context.push('/orders/${order.id}'),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Colored left border indicating status
              Container(
                width: 6,
                color: getStatusColor(),
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
                                  'Order #${order.orderNumber}',
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
                          _buildStatusChip(order.status),
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
                                '${order.items.length} item${order.items.length == 1 ? '' : 's'}',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('MMM dd, yyyy').format(order.orderDate),
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '₹${order.total.toStringAsFixed(2)}',
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

  Widget _buildStatusChip(OrderStatus status) {
    switch (status) {
      case OrderStatus.draft:
        return StatusChip.draft();
      case OrderStatus.confirmed:
        return StatusChip.confirmed();
      case OrderStatus.delivered:
        return StatusChip.delivered();
      case OrderStatus.cancelled:
        return StatusChip.cancelled();
    }
  }
}
