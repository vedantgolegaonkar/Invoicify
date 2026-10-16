import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../invoices/providers/invoice_providers.dart';
import '../../../customers/providers/customer_providers.dart';
import '../../../customers/domain/customer_model.dart';

class GstReportScreen extends ConsumerStatefulWidget {
  const GstReportScreen({super.key});

  @override
  ConsumerState<GstReportScreen> createState() => _GstReportScreenState();
}

class _GstReportScreenState extends ConsumerState<GstReportScreen> {
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
        title: const Text('GST Report'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: invoicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error loading invoices: $err')),
        data: (invoices) {
          final customers = customersAsync.value ?? [];

          // Filter invoices in selected date range
          final filteredInvoices = invoices.where((inv) {
            if (inv.isDeleted) return false;
            return inv.invoiceDate.isAfter(currentStartDate.subtract(const Duration(seconds: 1))) &&
                inv.invoiceDate.isBefore(currentEndDate.add(const Duration(seconds: 1)));
          }).toList()..sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));

          // Global GST calculations
          double totalTaxableValue = 0.0;
          double totalGstAmount = 0.0;

          // Breakdown by GST rate (e.g. 5%, 12%, 18%, 28%)
          final Map<int, double> rateTaxableValue = {};
          final Map<int, double> rateGstAmount = {};

          for (var inv in filteredInvoices) {
            totalTaxableValue += inv.subtotal;
            totalGstAmount += inv.gst;

            for (var item in inv.items) {
              final subtotal = item.subtotal;
              final gstAmt = item.gstAmount;
              
              // Calculate item GST percentage
              final double calculatedRate = subtotal == 0 ? 0.0 : (gstAmt / subtotal) * 100;
              final int rateKey = calculatedRate.round();

              rateTaxableValue[rateKey] = (rateTaxableValue[rateKey] ?? 0.0) + subtotal;
              rateGstAmount[rateKey] = (rateGstAmount[rateKey] ?? 0.0) + gstAmt;
            }
          }

          final totalCgst = totalGstAmount / 2;
          final totalSgst = totalGstAmount / 2;

          // Unique sorted rates for summary display
          final sortedRates = rateTaxableValue.keys.toList()..sort();

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Date Selector Header
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
                      // GST KPI Card
                      Container(
                        padding: const EdgeInsets.all(20),
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
                              'TOTAL GST LIABILITY',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '₹${totalGstAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('CGST (Central Tax)', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                    const SizedBox(height: 2),
                                    Text('₹${totalCgst.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Container(width: 1, height: 24, color: Colors.grey.shade300),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('SGST (State Tax)', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                    const SizedBox(height: 2),
                                    Text('₹${totalSgst.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Container(width: 1, height: 24, color: Colors.grey.shade300),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Taxable Turnover', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                    const SizedBox(height: 2),
                                    Text('₹${totalTaxableValue.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // GST Rates Breakdown Table Card
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
                              'Breakdown by GST Rate Class',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 16),
                            sortedRates.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24.0),
                                    child: Center(child: Text('No taxable sales in this range')),
                                  )
                                : Table(
                                    columnWidths: const {
                                      0: FlexColumnWidth(1.5),
                                      1: FlexColumnWidth(2),
                                      2: FlexColumnWidth(2),
                                    },
                                    children: [
                                      TableRow(
                                        decoration: BoxDecoration(
                                          border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                                        ),
                                        children: const [
                                          Padding(
                                            padding: EdgeInsets.only(bottom: 8.0),
                                            child: Text('Rate (%)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary)),
                                          ),
                                          Padding(
                                            padding: EdgeInsets.only(bottom: 8.0),
                                            child: Text('Taxable Value', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary)),
                                          ),
                                          Padding(
                                            padding: EdgeInsets.only(bottom: 8.0),
                                            child: Text('GST Collected', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary)),
                                          ),
                                        ],
                                      ),
                                      ...sortedRates.map((rate) {
                                        final taxable = rateTaxableValue[rate] ?? 0.0;
                                        final taxAmt = rateGstAmount[rate] ?? 0.0;

                                        return TableRow(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                                              child: Text('$rate%', style: const TextStyle(fontWeight: FontWeight.bold)),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                                              child: Text('₹${taxable.toStringAsFixed(2)}'),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                                              child: Text('₹${taxAmt.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                                            ),
                                          ],
                                        );
                                      })
                                    ],
                                  ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // GST Invoices Log Card
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
                              'Tax Invoices Log',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 16),
                            filteredInvoices.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 32.0),
                                    child: Center(
                                      child: Text('No invoices found', style: TextStyle(color: Colors.grey.shade500)),
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
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Text(
                                          'Invoice: #${inv.invoiceNumber} • ${DateFormat('dd MMM yyyy').format(inv.invoiceDate)}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        trailing: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              'GST: ₹${inv.gst.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              'Total: ₹${inv.total.toStringAsFixed(2)}',
                                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                        onTap: () => context.push('/invoices/${inv.id}'),
                                      );
                                    },
                                  ),
                          ],
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
}
