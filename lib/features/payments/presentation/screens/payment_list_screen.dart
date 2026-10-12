import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/loading_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../providers/payment_providers.dart';
import 'package:intl/intl.dart';
import '../../../customers/providers/customer_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/payment_model.dart';
import '../../../customers/domain/customer_model.dart';

class PaymentListScreen extends ConsumerStatefulWidget {
  const PaymentListScreen({super.key});

  @override
  ConsumerState<PaymentListScreen> createState() => _PaymentListScreenState();
}

class _PaymentListScreenState extends ConsumerState<PaymentListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final paymentsAsync = ref.watch(paymentsStreamProvider);
    final customersAsync = ref.watch(customersStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(
            pinned: true,
            expandedHeight: 120.0,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text('Payments', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SearchBar(
                hintText: 'Search by customer name...',
                leading: const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Icon(Icons.search, color: Colors.grey),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
                elevation: WidgetStateProperty.all(0),
                backgroundColor: WidgetStateProperty.all(
                  Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                ),
                padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 8)),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
          paymentsAsync.when(
            loading: () => const SliverFillRemaining(
              child: LoadingState(message: 'Loading payments...'),
            ),
            error: (error, stack) => SliverFillRemaining(
              child: ErrorState(
                message: error.toString(),
                onRetry: () => ref.refresh(paymentsStreamProvider),
              ),
            ),
            data: (payments) {
              if (payments.isEmpty && _searchQuery.isEmpty) {
                return SliverFillRemaining(
                  child: EmptyState(
                    title: 'No Payments Recorded',
                    message: 'Payments recorded against invoices will appear here automatically.',
                    icon: Icons.payments_outlined,
                  ),
                );
              }

              final customers = customersAsync.value ?? [];
              final filteredPayments = payments.where((p) {
                if (_searchQuery.isEmpty) return true;
                final customer = customers.where((c) => c.id == p.customerId).firstOrNull;
                final name = customer?.name.toLowerCase() ?? '';
                return name.contains(_searchQuery.toLowerCase());
              }).toList();

              if (filteredPayments.isEmpty) {
                return SliverFillRemaining(
                  child: EmptyState(
                    title: 'No Payments Found',
                    message: 'Try adjusting your search.',
                    icon: Icons.search_off,
                  ),
                );
              }

              final sortedPayments = filteredPayments
                ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));

              return SliverPadding(
                padding: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final payment = sortedPayments[index];
                      final customer = customers.where((c) => c.id == payment.customerId).firstOrNull;
                      final customerName = customer?.name ?? 'Unknown Customer';
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _PaymentCard(
                          payment: payment,
                          customer: customer,
                          onTap: () => context.push('/payments/${payment.id}'),
                        ),
                      );
                    },
                    childCount: sortedPayments.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final PaymentModel payment;
  final CustomerModel? customer;
  final VoidCallback onTap;

  const _PaymentCard({
    required this.payment,
    required this.customer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final customerName = customer?.name ?? 'Unknown Customer';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              // Icon circle
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.south_west_rounded,
                  color: AppColors.success,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd MMM yyyy, hh:mm a').format(payment.paymentDate),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        payment.paymentMethod,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '+₹${payment.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 16),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
