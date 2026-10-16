import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../products/providers/product_providers.dart';
import '../../../inventory/providers/inventory_providers.dart';
import '../../../products/domain/product_model.dart';
import '../../../inventory/domain/inventory_transaction_model.dart';

class InventoryReportScreen extends ConsumerStatefulWidget {
  const InventoryReportScreen({super.key});

  @override
  ConsumerState<InventoryReportScreen> createState() => _InventoryReportScreenState();
}

class _InventoryReportScreenState extends ConsumerState<InventoryReportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);
    final transactionsAsync = ref.watch(inventoryTransactionsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Inventory Report'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppColors.secondary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Current Stock'),
            Tab(text: 'Stock Log'),
          ],
        ),
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
        data: (products) {
          final transactions = (transactionsAsync.value ?? [])
              .where((t) => !t.isDeleted)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          final activeProducts = products.where((p) => !p.isDeleted).toList();

          // Calculate metrics
          final totalProducts = activeProducts.length;
          final totalStockItems = activeProducts.fold<double>(0.0, (sum, p) => sum + p.currentStock);
          final lowStockCount = activeProducts.where((p) => p.currentStock <= p.minimumStock).length;

          return TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Current Stock List
              _buildCurrentStockTab(activeProducts, lowStockCount, totalStockItems, totalProducts),

              // Tab 2: Transaction History Log
              _buildTransactionHistoryTab(transactions, activeProducts),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCurrentStockTab(List<ProductModel> products, int lowStockCount, double totalStockItems, int totalProducts) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // KPI Summary Row
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  'Total Stock Count',
                  totalStockItems.toStringAsFixed(0),
                  Icons.warehouse,
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKpiCard(
                  'Low Stock Alerts',
                  lowStockCount.toString(),
                  Icons.notification_important,
                  lowStockCount > 0 ? AppColors.error : AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Inventory Table Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Stock Levels by Product',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Checking $totalProducts active products',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                products.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32.0),
                        child: Center(child: Text('No products in inventory')),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: products.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final prod = products[index];
                          final isLow = prod.currentStock <= prod.minimumStock;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        prod.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Min Required Stock: ${prod.minimumStock}',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${prod.currentStock} Units',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: isLow ? AppColors.error : AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isLow ? AppColors.error.withValues(alpha: 0.1) : AppColors.success.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isLow ? 'Low Stock' : 'Good Stock',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: isLow ? AppColors.error : AppColors.success,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          );
                        },
                      ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTransactionHistoryTab(List<InventoryTransactionModel> transactions, List<ProductModel> products) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: transactions.isEmpty ? 1 : transactions.length,
      itemBuilder: (context, index) {
        if (transactions.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 64.0),
            child: Center(
              child: Text('No inventory transactions recorded yet'),
            ),
          );
        }

        final tx = transactions[index];
        final prod = products.firstWhere(
          (p) => p.id == tx.productId,
          orElse: () => ProductModel(
            id: '',
            name: 'Unknown Product',
            cgst: 0,
            sgst: 0,
            igst: 0,
            currentStock: 0,
            minimumStock: 0,
            isActive: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        final isIn = tx.type == TransactionType.stockIn;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: isIn ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
                  child: Icon(
                    isIn ? Icons.add_circle_outline : Icons.remove_circle_outline,
                    color: isIn ? AppColors.success : AppColors.error,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prod.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reason: ${tx.remarks ?? "Not specified"}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('dd MMM yyyy, hh:mm a').format(tx.createdAt),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isIn ? "+" : "-"}${tx.quantity}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isIn ? AppColors.success : AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'New: ${tx.newStock}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
              ),
              Icon(icon, size: 20, color: color),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
