import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/loading_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../providers/product_providers.dart';
import '../../../../shared/search/search_delegates.dart';
import '../../domain/product_model.dart';
import '../../../../core/theme/app_colors.dart';

class ProductListScreen extends ConsumerWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsStreamProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      appBar: AppBar(
        title: const Text('Products', style: TextStyle(fontWeight: FontWeight.w600)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              final products = productsAsync.value ?? [];
              showSearch(
                context: context,
                delegate: ProductSearchDelegate(products),
              );
            },
          ),
          // IconButton(
          //   icon: const Icon(Icons.filter_list_rounded),
          //   onPressed: () {},
          // ),
          const SizedBox(width: 8),
        ],
      ),
      body: productsAsync.when(
        loading: () => const LoadingState(message: 'Loading products...'),
        error: (error, stack) => ErrorState(
          message: error.toString(),
          onRetry: () => ref.refresh(productsStreamProvider),
        ),
        data: (products) {
          if (products.isEmpty) {
            return const EmptyState(
              title: 'No Products Found',
              message: 'Add a new product to your inventory.',
              icon: Icons.inventory_2_outlined,
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(productsStreamProvider.future),
            color: Theme.of(context).colorScheme.primary,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final product = products[index];
                return _ProductCard(
                  product: product,
                  onTap: () => context.push('/products/${product.id}'),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/products/add'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Product', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 4,
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLowStock = product.currentStock > 0 && product.currentStock <= product.minimumStock;
    final isOutOfStock = product.currentStock <= 0;
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.inventory_2_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!product.isActive)
                      _buildStatusChip('Inactive', AppColors.error, theme)
                    else if (isOutOfStock)
                      _buildStatusChip('Out of Stock', AppColors.error, theme)
                    else if (isLowStock)
                      _buildStatusChip('Low Stock', AppColors.warning, theme)
                    else
                      _buildStatusChip('${product.currentStock} in stock', AppColors.success, theme),
                    const SizedBox(height: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
