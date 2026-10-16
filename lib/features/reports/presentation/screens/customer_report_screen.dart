import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../invoices/providers/invoice_providers.dart';
import '../../../customers/providers/customer_providers.dart';
import '../../../payments/providers/payment_providers.dart';
import '../../../customers/domain/customer_model.dart';

class CustomerReportScreen extends ConsumerStatefulWidget {
  const CustomerReportScreen({super.key});

  @override
  ConsumerState<CustomerReportScreen> createState() => _CustomerReportScreenState();
}

class _CustomerReportScreenState extends ConsumerState<CustomerReportScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersStreamProvider);
    final invoicesAsync = ref.watch(invoicesStreamProvider);
    final paymentsAsync = ref.watch(paymentsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Customer Report'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: customersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error loading customers: $err')),
        data: (customers) {
          final invoices = (invoicesAsync.value ?? []).where((i) => !i.isDeleted).toList();
          final payments = (paymentsAsync.value ?? []).where((p) => !p.isDeleted).toList();

          // Calculate customer stats
          final List<_CustomerStat> customerStats = customers
              .where((c) => !c.isDeleted)
              .map((cust) {
                final custInvoices = invoices.where((i) => i.customerId == cust.id).toList();
                final custPayments = payments.where((p) => p.customerId == cust.id).toList();

                final totalSales = custInvoices.fold<double>(0.0, (s, i) => s + i.total);
                final totalPaid = custPayments.fold<double>(0.0, (s, p) => s + p.amount);
                final outstanding = totalSales - totalPaid;

                return _CustomerStat(
                  customer: cust,
                  invoicesCount: custInvoices.length,
                  totalSales: totalSales,
                  totalPayments: totalPaid,
                  outstanding: outstanding,
                );
              })
              .toList();

          // Search filtering
          final filteredStats = customerStats.where((stat) {
            final nameMatch = stat.customer.name.toLowerCase().contains(_searchQuery.toLowerCase());
            final businessMatch = (stat.customer.businessName ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
            final mobileMatch = stat.customer.mobile.contains(_searchQuery);
            return nameMatch || businessMatch || mobileMatch;
          }).toList();

          // KPI Calculations
          final totalCustomers = customerStats.length;
          final activeCustomers = customerStats.where((c) => c.invoicesCount > 0).length;
          
          // Find Top Customer by Sales
          _CustomerStat? topCustomer;
          if (customerStats.isNotEmpty) {
            topCustomer = customerStats.reduce((curr, next) => curr.totalSales > next.totalSales ? curr : next);
            if (topCustomer.totalSales == 0) {
              topCustomer = null;
            }
          }

          return Column(
            children: [
              // Header Search Box
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
                    hintText: 'Search by name, business, or mobile...',
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
                      // KPI Metrics Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              'Total Customers',
                              totalCustomers.toString(),
                              Icons.people,
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              'Active (Buying)',
                              activeCustomers.toString(),
                              Icons.assignment_ind,
                              Colors.green,
                            ),
                          ),
                        ],
                      ),
                      if (topCustomer != null) ...[
                        const SizedBox(height: 12),
                        _buildTopCustomerCard(topCustomer),
                      ],
                      const SizedBox(height: 20),

                      // Customer Table/List Card
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
                              'Customer Ledger Summary',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Showing ${filteredStats.length} customers',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 16),
                            filteredStats.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 32.0),
                                    child: Center(
                                      child: Text('No customers match your search'),
                                    ),
                                  )
                                : ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: filteredStats.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final stat = filteredStats[index];
                                      return _buildCustomerItem(context, stat);
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
            child: Icon(icon, color: color),
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

  Widget _buildTopCustomerCard(_CustomerStat stat) {
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
            child: Icon(Icons.emoji_events, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Top Customer (Highest Purchases)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                const SizedBox(height: 4),
                Text(
                  stat.customer.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                if (stat.customer.businessName != null && stat.customer.businessName!.isNotEmpty) ...[
                  Text(
                    stat.customer.businessName!,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${stat.totalSales.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              Text(
                '${stat.invoicesCount} Invoices',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCustomerItem(BuildContext context, _CustomerStat stat) {
    return InkWell(
      onTap: () => context.push('/customers/${stat.customer.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stat.customer.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${stat.invoicesCount} orders',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        stat.customer.mobile,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  )
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Sales: ₹${stat.totalSales.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  stat.outstanding > 0
                      ? 'Out: ₹${stat.outstanding.toStringAsFixed(2)}'
                      : 'Settled',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: stat.outstanding > 0 ? AppColors.error : AppColors.success,
                  ),
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

class _CustomerStat {
  final CustomerModel customer;
  final int invoicesCount;
  final double totalSales;
  final double totalPayments;
  final double outstanding;

  _CustomerStat({
    required this.customer,
    required this.invoicesCount,
    required this.totalSales,
    required this.totalPayments,
    required this.outstanding,
  });
}
