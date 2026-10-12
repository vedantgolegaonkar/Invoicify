import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../notifications/providers/notification_providers.dart';
import '../../../customers/providers/customer_providers.dart';
import '../../../orders/providers/order_providers.dart';
import '../../../invoices/providers/invoice_providers.dart';
import '../../../products/providers/product_providers.dart';
import '../../../orders/domain/order_model.dart';
import '../../../customers/domain/customer_model.dart';
import '../../../invoices/domain/invoice_model.dart';
import '../../../products/domain/product_model.dart';
import '../../../payments/providers/payment_providers.dart';
import '../../../payments/domain/payment_model.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersStreamProvider);
    final ordersAsync = ref.watch(ordersStreamProvider);
    final invoicesAsync = ref.watch(invoicesStreamProvider);
    final productsAsync = ref.watch(productsStreamProvider);
    final paymentsAsync = ref.watch(paymentsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          Consumer(
            builder: (context, ref, child) {
              final unreadCount = ref.watch(unreadNotificationsCountProvider);
              return IconButton(
                icon: Badge(
                  isLabelVisible: unreadCount > 0,
                  label: Text(unreadCount.toString()),
                  child: const Icon(Icons.notifications_none),
                ),
                onPressed: () {
                  context.push('/dashboard/notifications');
                },
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCards(context, customersAsync, ordersAsync, invoicesAsync, paymentsAsync),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Products Catalog', style: Theme.of(context).textTheme.titleLarge),
                if (productsAsync.value != null && productsAsync.value!.length > 5)
                  TextButton(
                    onPressed: () => context.push('/products'),
                    child: const Text('Show all'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTopProducts(productsAsync),
            const SizedBox(height: 24),
            Text('Recent Orders', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _buildRecentActivities(ordersAsync),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(
    BuildContext context, 
    AsyncValue<List<CustomerModel>> customersAsync, 
    AsyncValue<List<OrderModel>> ordersAsync, 
    AsyncValue<List<InvoiceModel>> invoicesAsync,
    AsyncValue<List<PaymentModel>> paymentsAsync
  ) {
    int totalCustomers = customersAsync.value?.where((c) => !c.isDeleted).length ?? 0;
    
    double todaySales = 0.0;
    double todayCollection = 0.0;
    double outstanding = 0.0;
    final now = DateTime.now();

    if (invoicesAsync.value != null) {
      final activeInvoices = invoicesAsync.value!.where((i) => !i.isDeleted).toList();
      todaySales = activeInvoices
          .where((i) => i.invoiceDate.year == now.year && i.invoiceDate.month == now.month && i.invoiceDate.day == now.day)
          .fold(0.0, (sum, i) => sum + i.total);
          
      final totalSalesAllTime = activeInvoices.fold(0.0, (sum, i) => sum + i.total);
      outstanding += totalSalesAllTime;
    }

    if (paymentsAsync.value != null) {
      final activePayments = paymentsAsync.value!.where((p) => !p.isDeleted).toList();
      todayCollection = activePayments
          .where((p) => p.paymentDate.year == now.year && p.paymentDate.month == now.month && p.paymentDate.day == now.day)
          .fold(0.0, (sum, p) => sum + p.amount);
          
      final totalCollectionAllTime = activePayments.fold(0.0, (sum, p) => sum + p.amount);
      outstanding -= totalCollectionAllTime;
    }

    if (outstanding < 0) outstanding = 0;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(context, 'Today\'s Sales', '₹ ${todaySales.toStringAsFixed(2)}', Icons.currency_rupee, Colors.green),
        _buildStatCard(context, 'Today\'s Collection', '₹ ${todayCollection.toStringAsFixed(2)}', Icons.account_balance_wallet, Colors.blue),
        _buildStatCard(context, 'Outstanding', '₹ ${outstanding.toStringAsFixed(2)}', Icons.warning_amber_rounded, Colors.orange),
        _buildStatCard(context, 'Customers', '$totalCustomers', Icons.people, Colors.purple),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 24, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildTopProducts(AsyncValue<List<ProductModel>> productsAsync) {
    return productsAsync.when(
      loading: () => const CircularProgressIndicator(),
      error: (e, st) => Text('Error loading products: $e'),
      data: (products) {
        if (products.isEmpty) return const Text('No products available.');
        final takeCount = products.length > 5 ? 5 : products.length;
        
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: takeCount,
          itemBuilder: (context, index) {
            final p = products[index];
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.inventory_2)),
              title: Text(p.name),
              subtitle: Text('Stock: ${p.currentStock}'),

            );
          },
        );
      }
    );
  }

  Widget _buildRecentActivities(AsyncValue<List<OrderModel>> ordersAsync) {
    return ordersAsync.when(
      loading: () => const CircularProgressIndicator(),
      error: (e, st) => Text('Error loading orders: $e'),
      data: (orders) {
        if (orders.isEmpty) return const Text('No recent orders.');
        // Sort by date descending
        final sortedOrders = List.from(orders)..sort((a, b) => (b as OrderModel).orderDate.compareTo((a as OrderModel).orderDate));
        final takeCount = sortedOrders.length > 5 ? 5 : sortedOrders.length;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: takeCount,
          itemBuilder: (context, index) {
            final o = sortedOrders[index] as OrderModel;
            return ListTile(
              leading: const Icon(Icons.history),
              title: Text('Order #${o.orderNumber} created'),
              subtitle: Text(o.status.name),
            );
          },
        );
      }
    );
  }
}
