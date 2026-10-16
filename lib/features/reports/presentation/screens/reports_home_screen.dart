import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../invoices/providers/invoice_providers.dart';
import '../../../payments/providers/payment_providers.dart';
import '../../../products/providers/product_providers.dart';
import '../../../invoices/domain/invoice_model.dart';

class ReportsHomeScreen extends ConsumerWidget {
  const ReportsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch streams for real-time calculations
    final invoicesAsync = ref.watch(invoicesStreamProvider);
    final paymentsAsync = ref.watch(paymentsStreamProvider);
    final productsAsync = ref.watch(productsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reports Dashboard'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: invoicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
        data: (invoices) {
          final payments = paymentsAsync.value ?? [];
          final products = productsAsync.value ?? [];

          // Clean active items
          final activeInvoices = invoices.where((i) => !i.isDeleted).toList();
          final activePayments = payments.where((p) => !p.isDeleted).toList();
          final activeProducts = products.where((p) => !p.isDeleted).toList();

          // Calculate global outstanding
          final double globalSales = activeInvoices.fold(0.0, (sum, i) => sum + i.total);
          final double globalCollected = activePayments.fold(0.0, (sum, p) => sum + p.amount);
          double outstanding = globalSales - globalCollected;
          if (outstanding < 0) outstanding = 0;

          // Calculate This Month's Sales & Collection
          final now = DateTime.now();
          final thisMonthInvoices = activeInvoices.where((i) => i.invoiceDate.year == now.year && i.invoiceDate.month == now.month);
          final thisMonthPayments = activePayments.where((p) => p.paymentDate.year == now.year && p.paymentDate.month == now.month);
          
          final double thisMonthSales = thisMonthInvoices.fold(0.0, (sum, i) => sum + i.total);
          final double thisMonthCollected = thisMonthPayments.fold(0.0, (sum, p) => sum + p.amount);

          final int lowStockCount = activeProducts.where((p) => p.currentStock <= p.minimumStock).length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Horizontal KPI Scroll View
                SizedBox(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildHeaderKpiCard(
                        'This Month\'s Sales',
                        '₹${thisMonthSales.toStringAsFixed(0)}',
                        Icons.trending_up,
                        Colors.green,
                      ),
                      const SizedBox(width: 12),
                      _buildHeaderKpiCard(
                        'This Month\'s Col.',
                        '₹${thisMonthCollected.toStringAsFixed(0)}',
                        Icons.payments,
                        Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      _buildHeaderKpiCard(
                        'Outstanding',
                        '₹${outstanding.toStringAsFixed(0)}',
                        Icons.account_balance_wallet,
                        Colors.red,
                      ),
                      const SizedBox(width: 12),
                      _buildHeaderKpiCard(
                        'Low Stock Items',
                        '$lowStockCount',
                        Icons.warning_amber_rounded,
                        lowStockCount > 0 ? Colors.orange : Colors.green,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Weekly Sales Trend Visual Card
                // Container(
                //   padding: const EdgeInsets.all(16),
                //   decoration: BoxDecoration(
                //     color: Colors.white,
                //     borderRadius: BorderRadius.circular(20),
                //     border: Border.all(color: Colors.grey.shade200),
                //     boxShadow: [
                //       BoxShadow(
                //         color: Colors.black.withValues(alpha: 0.02),
                //         blurRadius: 12,
                //         offset: const Offset(0, 6),
                //       )
                //     ],
                //   ),
                //   child: Column(
                //     crossAxisAlignment: CrossAxisAlignment.start,
                //     children: [
                //       const Text(
                //         '7-Day Sales Trend',
                //         style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                //       ),
                //       const SizedBox(height: 16),
                //       _buildTrendChart(salesTrend),
                //     ],
                //   ),
                // ),
                // const SizedBox(height: 24),

                // Grid of Report Options
                const Text(
                  'All Reports Categories',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 1.15,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  children: [
                    _buildReportGridCard(
                      context,
                      'Sales Report',
                      'Daily & Datewise sales',
                      Icons.bar_chart,
                      Colors.green.shade700,
                      '/reports/sales',
                    ),
                    _buildReportGridCard(
                      context,
                      'Customer Report',
                      'Customer purchase metrics',
                      Icons.people_outline,
                      Colors.indigo.shade700,
                      '/reports/customers',
                    ),
                    _buildReportGridCard(
                      context,
                      'Outstanding Report',
                      'Pending dues tracking',
                      Icons.money_off,
                      Colors.red.shade700,
                      '/reports/outstanding',
                      badgeCount: activeInvoices.where((i) => i.status != InvoiceStatus.paid).length,
                    ),
                    _buildReportGridCard(
                      context,
                      'Product Report',
                      'Item sales performance',
                      Icons.inventory_2_outlined,
                      Colors.orange.shade800,
                      '/reports/products',
                    ),
                    _buildReportGridCard(
                      context,
                      'Inventory Report',
                      'Stock values & warnings',
                      Icons.warehouse_outlined,
                      Colors.teal.shade700,
                      '/reports/inventory',
                      badgeCount: lowStockCount > 0 ? lowStockCount : null,
                    ),
                    _buildReportGridCard(
                      context,
                      'Payment Report',
                      'Collections transactions',
                      Icons.account_balance,
                      Colors.cyan.shade700,
                      '/reports/payments',
                    ),
                    _buildReportGridCard(
                      context,
                      'GST Report',
                      'GST tax compliance data',
                      Icons.receipt_long_outlined,
                      Colors.purple.shade700,
                      '/reports/gst',
                    ),
                    _buildReportGridCard(
                      context,
                      'Monthly Collection',
                      'Collection summaries',
                      Icons.calendar_month_outlined,
                      Colors.blueGrey.shade700,
                      '/reports/collection',
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderKpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
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
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildReportGridCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
    String route, {
    int? badgeCount,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () => context.push(route),
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.1),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  )
                ],
              ),
            ),
            if (badgeCount != null && badgeCount > 0)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }

}
