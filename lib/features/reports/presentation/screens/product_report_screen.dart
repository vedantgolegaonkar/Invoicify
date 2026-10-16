import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../invoices/providers/invoice_providers.dart';
import '../../../products/providers/product_providers.dart';
import '../../../products/domain/product_model.dart';

class ProductReportScreen extends ConsumerStatefulWidget {
  const ProductReportScreen({super.key});

  @override
  ConsumerState<ProductReportScreen> createState() => _ProductReportScreenState();
}

class _ProductReportScreenState extends ConsumerState<ProductReportScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);
    final invoicesAsync = ref.watch(invoicesStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Product Report'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
        data: (products) {
          final invoices = (invoicesAsync.value ?? []).where((i) => !i.isDeleted).toList();

          // Calculate quantities sold and revenue per product dynamically from invoices
          final Map<String, double> productQtySold = {};
          final Map<String, double> productRevenue = {};

          for (var inv in invoices) {
            for (var item in inv.items) {
              productQtySold[item.productId] = (productQtySold[item.productId] ?? 0.0) + item.quantity;
              productRevenue[item.productId] = (productRevenue[item.productId] ?? 0.0) + item.total;
            }
          }

          // Build Product Stats
          final List<_ProductStatItem> stats = products
              .where((p) => !p.isDeleted)
              .map((prod) {
                final qty = productQtySold[prod.id] ?? 0.0;
                final rev = productRevenue[prod.id] ?? 0.0;
                final isLowStock = prod.currentStock <= prod.minimumStock;

                return _ProductStatItem(
                  product: prod,
                  quantitySold: qty,
                  revenue: rev,
                  isLowStock: isLowStock,
                );
              })
              .toList();

          // Filter by search query
          final filteredStats = stats.where((item) {
            return item.product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (item.product.hsnCode ?? '').contains(_searchQuery);
          }).toList();

          // Sort by quantity sold descending as default
          filteredStats.sort((a, b) => b.quantitySold.compareTo(a.quantitySold));

          // Metrics
          final totalProducts = stats.length;
          final lowStockCount = stats.where((s) => s.isLowStock).length;

          // Best Seller calculation
          _ProductStatItem? bestSeller;
          if (stats.isNotEmpty) {
            bestSeller = stats.reduce((curr, next) => curr.quantitySold > next.quantitySold ? curr : next);
            if (bestSeller.quantitySold == 0) {
              bestSeller = null;
            }
          }

          return Column(
            children: [
              // Search Header
              Container(
                color: AppColors.primary,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search products by name or HSN...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // KPI Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              'Total Products',
                              totalProducts.toString(),
                              Icons.inventory_2_outlined,
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              'Low Stock Alerts',
                              lowStockCount.toString(),
                              Icons.warning_amber_rounded,
                              lowStockCount > 0 ? Colors.red : Colors.green,
                            ),
                          ),
                        ],
                      ),
                      if (bestSeller != null) ...[
                        const SizedBox(height: 12),
                        _buildBestSellerCard(bestSeller),
                      ],
                      const SizedBox(height: 20),

                      // Sales Ledger Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Product Sales & Stock Summary',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Sorted by volume sold (highest first)',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 16),
                            filteredStats.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 32.0),
                                    child: Center(
                                      child: Text('No products match your search'),
                                    ),
                                  )
                                : ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: filteredStats.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final item = filteredStats[index];
                                      return _buildProductRow(context, item);
                                    },
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value, 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBestSellerCard(_ProductStatItem stat) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withValues(alpha: 0.08), AppColors.secondary.withValues(alpha: 0.15)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.primary,
            child: Icon(Icons.star, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Best-Selling Product',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                const SizedBox(height: 4),
                Text(
                  stat.product.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                Text(
                  'Current Stock: ${stat.product.currentStock} units',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${stat.quantitySold} units sold',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const SizedBox(height: 2),
              Text(
                '₹${stat.revenue.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildProductRow(BuildContext context, _ProductStatItem item) {
    return InkWell(
      onTap: () => context.push('/products/${item.product.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Stock: ${item.product.currentStock}',
                        style: TextStyle(
                          fontSize: 12, 
                          color: item.isLowStock ? AppColors.error : AppColors.textSecondary,
                          fontWeight: item.isLowStock ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(
                        'HSN: ${item.product.hsnCode ?? "None"}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.quantitySold} Sold',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${item.revenue.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _ProductStatItem {
  final ProductModel product;
  final double quantitySold;
  final double revenue;
  final bool isLowStock;

  _ProductStatItem({
    required this.product,
    required this.quantitySold,
    required this.revenue,
    required this.isLowStock,
  });
}
