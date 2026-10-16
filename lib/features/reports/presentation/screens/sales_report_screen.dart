import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../invoices/providers/invoice_providers.dart';
import '../../../customers/providers/customer_providers.dart';
import '../../../invoices/domain/invoice_model.dart';
import '../../../customers/domain/customer_model.dart';

class SalesReportScreen extends ConsumerStatefulWidget {
  const SalesReportScreen({super.key});

  @override
  ConsumerState<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends ConsumerState<SalesReportScreen> {
  String _dateRangeLabel = 'Last 7 Days';
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  void _setDateRange(String label, {DateTime? start, DateTime? end}) {
    setState(() {
      _dateRangeLabel = label;
      if (start != null) _customStartDate = start;
      if (end != null) _customEndDate = end;
    });
  }

  Future<void> _selectCustomRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(
        start: _customStartDate ?? DateTime.now().subtract(const Duration(days: 7)), 
        end: _customEndDate ?? DateTime.now()
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _setDateRange(
        '${DateFormat('dd MMM').format(picked.start)} - ${DateFormat('dd MMM').format(picked.end)}',
        start: picked.start,
        end: picked.end.add(const Duration(hours: 23, minutes: 59, seconds: 59)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoicesStreamProvider);
    final customersAsync = ref.watch(customersStreamProvider);

    DateTime currentStartDate;
    DateTime currentEndDate;

    if (_dateRangeLabel == 'Today') {
      currentStartDate = DateTime.now().subtract(const Duration(hours: 23, minutes: 59));
      currentEndDate = DateTime.now();
    } else if (_dateRangeLabel == 'Yesterday') {
      currentStartDate = DateTime.now().subtract(const Duration(days: 1, hours: 23, minutes: 59));
      currentEndDate = DateTime.now().subtract(const Duration(days: 1));
    } else if (_dateRangeLabel == 'Last 7 Days') {
      currentStartDate = DateTime.now().subtract(const Duration(days: 7));
      currentEndDate = DateTime.now();
    } else if (_dateRangeLabel == 'Last 30 Days') {
      currentStartDate = DateTime.now().subtract(const Duration(days: 30));
      currentEndDate = DateTime.now();
    } else if (_dateRangeLabel == 'This Month') {
      currentStartDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
      currentEndDate = DateTime.now();
    } else {
      currentStartDate = _customStartDate ?? DateTime.now().subtract(const Duration(days: 7));
      currentEndDate = _customEndDate ?? DateTime.now();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Sales Report'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: invoicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error loading data: $err')),
        data: (invoices) {
          final customers = customersAsync.value ?? [];

          // Filter invoices: within date range and not deleted
          final filteredInvoices = invoices.where((inv) {
            if (inv.isDeleted) return false;
            // Normalize dates to check range
            return inv.invoiceDate.isAfter(currentStartDate.subtract(const Duration(seconds: 1))) &&
                inv.invoiceDate.isBefore(currentEndDate.add(const Duration(seconds: 1)));
          }).toList();

          // Calculate Key Metrics
          final totalSales = filteredInvoices.fold<double>(0.0, (sum, inv) => sum + inv.total);
          final totalTaxable = filteredInvoices.fold<double>(0.0, (sum, inv) => sum + inv.subtotal);
          final totalGst = filteredInvoices.fold<double>(0.0, (sum, inv) => sum + inv.gst);
          final avgOrderValue = filteredInvoices.isEmpty ? 0.0 : totalSales / filteredInvoices.length;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Date Selector Chip Row
                Container(
                  color: AppColors.primary,
                  padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _dateRangeLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.calendar_month, color: Colors.white),
                            onPressed: _selectCustomRange,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildDateChip('Today'),
                            const SizedBox(width: 8),
                            _buildDateChip('Yesterday'),
                            const SizedBox(width: 8),
                            _buildDateChip('Last 7 Days'),
                            const SizedBox(width: 8),
                            _buildDateChip('Last 30 Days'),
                            const SizedBox(width: 8),
                            _buildDateChip('This Month'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // KPI Metrics Grid
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        childAspectRatio: 1.5,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        children: [
                          _buildKpiCard('Total Revenue', '₹${totalSales.toStringAsFixed(2)}', Icons.payments, Colors.green),
                          _buildKpiCard('Avg. Order', '₹${avgOrderValue.toStringAsFixed(2)}', Icons.analytics, Colors.blue),
                          _buildKpiCard('Taxable Value', '₹${totalTaxable.toStringAsFixed(2)}', Icons.money, Colors.orange),
                          _buildKpiCard('Total GST', '₹${totalGst.toStringAsFixed(2)}', Icons.receipt_long, Colors.purple),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Sales Chart Card
                      // _buildSectionCard(
                      //   title: 'Sales Trend',
                      //   subtitle: 'Tap bars to view values',
                      //   child: chartData.isEmpty
                      //       ? Container(
                      //           height: 160,
                      //           alignment: Alignment.center,
                      //           child: Text('No data for this period', style: TextStyle(color: Colors.grey.shade500)),
                      //         )
                      //       : Column(
                      //           children: [
                      //             _buildSalesChart(chartData),
                      //             if (_selectedBarIndex != null && _selectedBarIndex! < chartData.length) ...[
                      //               const SizedBox(height: 12),
                      //               Container(
                      //                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      //                 decoration: BoxDecoration(
                      //                   color: AppColors.primary.withValues(alpha: 0.05),
                      //                   borderRadius: BorderRadius.circular(8),
                      //                   border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                      //                 ),
                      //                 child: Row(
                      //                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      //                   children: [
                      //                     Text(
                      //                       chartData[_selectedBarIndex!].dateLabel,
                      //                       style: const TextStyle(fontWeight: FontWeight.bold),
                      //                     ),
                      //                     Text(
                      //                       '₹${chartData[_selectedBarIndex!].amount.toStringAsFixed(2)}',
                      //                       style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                      //                     ),
                      //                   ],
                      //                 ),
                      //               )
                      //             ]
                      //           ],
                      //         ),
                      // ),
                      // const SizedBox(height: 20),

                      // Invoices List Card
                      _buildSectionCard(
                        title: 'Invoices in Period (${filteredInvoices.length})',
                        subtitle: 'Detailed list of sales',
                        child: filteredInvoices.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: 32.0),
                                child: Center(
                                  child: Text(
                                    'No invoices found in this range',
                                    style: TextStyle(color: Colors.grey.shade500),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: filteredInvoices.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final inv = filteredInvoices[index];
                                  final cust = customers.firstWhere(
                                    (c) => c.id == inv.customerId,
                                    orElse: () => CustomerModel(
                                      id: '',
                                      name: 'Unknown Customer',
                                      mobile: '',
                                      address: '',
                                      currentOutstanding: 0.0,
                                      createdAt: DateTime.now(),
                                      updatedAt: DateTime.now(),
                                    ),
                                  );

                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      cust.name,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(
                                      '#${inv.invoiceNumber} • ${DateFormat('dd MMM yyyy').format(inv.invoiceDate)}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '₹${inv.total.toStringAsFixed(2)}',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          inv.status.name,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: inv.status == InvoiceStatus.paid
                                                ? AppColors.success
                                                : inv.status == InvoiceStatus.partiallyPaid
                                                    ? AppColors.warning
                                                    : AppColors.error,
                                          ),
                                        )
                                      ],
                                    ),
                                    onTap: () => context.push('/invoices/${inv.id}'),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateChip(String label) {
    // Check if the current range matches
    final isSelected = _dateRangeLabel == label;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          _setDateRange(label);
        }
      },
      selectedColor: AppColors.secondary,
      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : Colors.white,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
              ),
              Icon(icon, size: 20, color: color),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required String subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
