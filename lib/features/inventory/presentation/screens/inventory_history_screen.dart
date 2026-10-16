import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/loading_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../providers/inventory_providers.dart';
import '../../../products/providers/product_providers.dart';
import '../../domain/inventory_transaction_model.dart';

class InventoryHistoryScreen extends ConsumerWidget {
  const InventoryHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(inventoryTransactionsStreamProvider);
    final productsAsync = ref.watch(productsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.medium(
            title: Text('Stock History', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          transactionsAsync.when(
            loading: () => const SliverFillRemaining(
              child: LoadingState(message: 'Loading history...'),
            ),
            error: (e, _) => SliverFillRemaining(
              child: ErrorState(
                message: e.toString(),
                onRetry: () => ref.refresh(inventoryTransactionsStreamProvider),
              ),
            ),
            data: (transactions) {
              if (transactions.isEmpty) {
                return const SliverFillRemaining(
                  child: EmptyState(
                    title: 'No History Yet',
                    message: 'Stock movements will appear here after you record a Stock In or Stock Out.',
                    icon: Icons.history,
                  ),
                );
              }

              final sorted = transactions.toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

              final products = productsAsync.value ?? [];

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final txn = sorted[index];
                      final product = products
                          .where((p) => p.id == txn.productId)
                          .firstOrNull;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TransactionTile(transaction: txn, productName: product?.name ?? 'Unknown Product'),
                      );
                    },
                    childCount: sorted.length,
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

class _TransactionTile extends StatelessWidget {
  final InventoryTransactionModel transaction;
  final String productName;

  const _TransactionTile({
    required this.transaction,
    required this.productName,
  });

  @override
  Widget build(BuildContext context) {
    final isIn = transaction.type == TransactionType.stockIn;
    final color = isIn ? AppColors.success : AppColors.error;
    final label = isIn ? 'Stock In' : 'Stock Out';
    final sign = isIn ? '+' : '-';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isIn ? Icons.add_circle_outline : Icons.remove_circle_outline,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(transaction.createdAt),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                if (transaction.remarks != null && transaction.remarks!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    transaction.remarks!,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$sign${transaction.quantity}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
