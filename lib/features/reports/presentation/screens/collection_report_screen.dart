import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../invoices/providers/invoice_providers.dart';
import '../../../payments/providers/payment_providers.dart';
import '../../../invoices/domain/invoice_model.dart';
import '../../../payments/domain/payment_model.dart';

class CollectionReportScreen extends ConsumerStatefulWidget {
  const CollectionReportScreen({super.key});

  @override
  ConsumerState<CollectionReportScreen> createState() => _CollectionReportScreenState();
}

class _CollectionReportScreenState extends ConsumerState<CollectionReportScreen> {
  int? _selectedBarIndex;

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoicesStreamProvider);
    final paymentsAsync = ref.watch(paymentsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Monthly Collection'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: invoicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
        data: (invoices) {
          final payments = paymentsAsync.value ?? [];

          // Compute monthly stats for the last 12 months
          final List<_MonthlyCollectionItem> monthlyStats = _calculateMonthlyStats(invoices, payments);

          // Calculate summary metrics
          final totalBilledOverall = monthlyStats.fold<double>(0.0, (sum, item) => sum + item.totalBilled);
          final totalCollectedOverall = monthlyStats.fold<double>(0.0, (sum, item) => sum + item.totalCollected);
          final totalPendingOverall = totalBilledOverall - totalCollectedOverall;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // KPI Overall Overview Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '12-MONTH OVERVIEW',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Billed', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                              const SizedBox(height: 2),
                              Text('₹${totalBilledOverall.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Collected', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                              const SizedBox(height: 2),
                              Text(
                                '₹${totalCollectedOverall.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.success),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Pending Collection', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                              const SizedBox(height: 2),
                              Text(
                                '₹${totalPendingOverall.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.error),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Trend Chart Card
                // Container(
                //   padding: const EdgeInsets.all(16),
                //   decoration: BoxDecoration(
                //     color: Colors.white,
                //     borderRadius: BorderRadius.circular(20),
                //     border: Border.all(color: Colors.grey.shade200),
                //   ),
                //   child: Column(
                //     crossAxisAlignment: CrossAxisAlignment.start,
                //     children: [
                //       const Text(
                //         'Collection Trend',
                //         style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                //       ),
                //       const SizedBox(height: 4),
                //       const Text(
                //         'Monthly collection performance (Cash flow)',
                //         style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                //       ),
                //       const SizedBox(height: 20),
                //       _buildCollectionChart(monthlyStats),
                //       if (_selectedBarIndex != null && _selectedBarIndex! < monthlyStats.length) ...[
                //         const SizedBox(height: 12),
                //         Container(
                //           padding: const EdgeInsets.all(12),
                //           decoration: BoxDecoration(
                //             color: AppColors.primary.withOpacity(0.05),
                //             borderRadius: BorderRadius.circular(10),
                //             border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                //           ),
                //           child: Column(
                //             children: [
                //               Row(
                //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //                 children: [
                //                   Text(
                //                     monthlyStats[_selectedBarIndex!].monthName,
                //                     style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                //                   ),
                //                   Text(
                //                     'Collected: ₹${monthlyStats[_selectedBarIndex!].totalCollected.toStringAsFixed(2)}',
                //                     style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success),
                //                   ),
                //                 ],
                //               ),
                //               const SizedBox(height: 6),
                //               Row(
                //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //                 children: [
                //                   Text(
                //                     'Billed: ₹${monthlyStats[_selectedBarIndex!].totalBilled.toStringAsFixed(2)}',
                //                     style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                //                   ),
                //                   Text(
                //                     'Pending: ₹${(monthlyStats[_selectedBarIndex!].totalBilled - monthlyStats[_selectedBarIndex!].totalCollected).toStringAsFixed(2)}',
                //                     style: const TextStyle(fontSize: 12, color: AppColors.error),
                //                   ),
                //                 ],
                //               ),
                //             ],
                //           ),
                //         )
                //       ],
                //     ],
                //   ),
                // ),
                // const SizedBox(height: 20),

                // Monthly Table List
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
                        'Monthly Details Ledger',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 16),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: monthlyStats.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = monthlyStats[index];
                          final pending = item.totalBilled - item.totalCollected;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.monthName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${item.invoicesCount} Invoices • Billed: ₹${item.totalBilled.toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Coll: ₹${item.totalCollected.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: AppColors.success,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      pending > 0 
                                          ? 'Pend: ₹${pending.toStringAsFixed(2)}'
                                          : 'Collected',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: pending > 0 ? AppColors.error : AppColors.success,
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
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCollectionChart(List<_MonthlyCollectionItem> data) {
    // Reverse data to display chronologically left-to-right (past to present)
    final chronologicalData = data.reversed.toList();
    final maxVal = chronologicalData.map((d) => d.totalCollected).fold<double>(0.0, (m, c) => c > m ? c : m);
    final displayMax = maxVal == 0.0 ? 100.0 : maxVal * 1.1;

    return SizedBox(
      height: 160,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(chronologicalData.length, (index) {
          final item = chronologicalData[index];
          final percent = displayMax == 0 ? 0.0 : item.totalCollected / displayMax;
          
          // Map reversed index back to selected index in list
          final actualIndex = data.indexOf(item);
          final isSelected = _selectedBarIndex == actualIndex;

          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _selectedBarIndex = isSelected ? null : actualIndex;
                });
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isSelected
                                ? [AppColors.success, AppColors.success.withOpacity(0.8)]
                                : [AppColors.success.withOpacity(0.5), AppColors.success.withOpacity(0.2)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.success.withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, -2),
                                  )
                                ]
                              : null,
                        ),
                        child: FractionallySizedBox(
                          heightFactor: percent == 0.0 ? 0.02 : percent,
                          alignment: Alignment.bottomCenter,
                          child: Container(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.monthCode,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppColors.success : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  List<_MonthlyCollectionItem> _calculateMonthlyStats(List<InvoiceModel> invoices, List<PaymentModel> payments) {
    final List<_MonthlyCollectionItem> stats = [];

    // Filter active items
    final activeInvoices = invoices.where((i) => !i.isDeleted).toList();
    final activePayments = payments.where((p) => !p.isDeleted).toList();

    // Past 12 months lists
    for (int i = 0; i < 12; i++) {
      final date = DateTime(DateTime.now().year, DateTime.now().month - i, 1);
      final monthName = DateFormat('MMMM yyyy').format(date);
      final monthCode = DateFormat('MMM').format(date);

      // Invoices in month
      final monthInvoices = activeInvoices.where((inv) =>
          inv.invoiceDate.year == date.year && inv.invoiceDate.month == date.month).toList();

      // Payments in month
      final monthPayments = activePayments.where((pay) =>
          pay.paymentDate.year == date.year && pay.paymentDate.month == date.month).toList();

      final double billed = monthInvoices.fold<double>(0.0, (sum, inv) => sum + inv.total);
      final double collected = monthPayments.fold<double>(0.0, (sum, pay) => sum + pay.amount);

      stats.add(_MonthlyCollectionItem(
        monthName: monthName,
        monthCode: monthCode,
        invoicesCount: monthInvoices.length,
        totalBilled: billed,
        totalCollected: collected,
      ));
    }

    return stats;
  }
}

class _MonthlyCollectionItem {
  final String monthName;
  final String monthCode;
  final int invoicesCount;
  final double totalBilled;
  final double totalCollected;

  _MonthlyCollectionItem({
    required this.monthName,
    required this.monthCode,
    required this.invoicesCount,
    required this.totalBilled,
    required this.totalCollected,
  });
}
