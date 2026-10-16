import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../payments/providers/payment_providers.dart';
import '../../../customers/providers/customer_providers.dart';
import '../../../customers/domain/customer_model.dart';

class PaymentReportScreen extends ConsumerStatefulWidget {
  const PaymentReportScreen({super.key});

  @override
  ConsumerState<PaymentReportScreen> createState() => _PaymentReportScreenState();
}

class _PaymentReportScreenState extends ConsumerState<PaymentReportScreen> {
  String _dateRangeLabel = 'Last 7 Days';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  void _setDateRange(String label, DateTime start, DateTime end) {
    setState(() {
      _dateRangeLabel = label;
      _startDate = start;
      _endDate = end;
    });
  }

  Future<void> _selectCustomRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
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
        picked.start,
        picked.end.add(const Duration(hours: 23, minutes: 59, seconds: 59)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final paymentsAsync = ref.watch(paymentsStreamProvider);
    final customersAsync = ref.watch(customersStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Payment Report'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: paymentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error loading payments: $err')),
        data: (payments) {
          final customers = customersAsync.value ?? [];

          // Filter payments in range
          final filteredPayments = payments.where((p) {
            if (p.isDeleted) return false;
            return p.paymentDate.isAfter(_startDate.subtract(const Duration(seconds: 1))) &&
                p.paymentDate.isBefore(_endDate.add(const Duration(seconds: 1)));
          }).toList()..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));

          // Metrics calculations
          final totalCollected = filteredPayments.fold<double>(0.0, (sum, p) => sum + p.amount);

          // Payment methods split
          final Map<String, double> methodSplits = {};
          for (var p in filteredPayments) {
            final method = p.paymentMethod.isNotEmpty ? p.paymentMethod : 'Other';
            methodSplits[method] = (methodSplits[method] ?? 0.0) + p.amount;
          }

          final methodColors = [
            Colors.green.shade600,
            Colors.blue.shade600,
            Colors.orange.shade600,
            Colors.purple.shade600,
            Colors.teal.shade600,
            Colors.red.shade600,
          ];

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Date Range Chips Header
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
                            _buildDateChip('Today', DateTime.now().subtract(const Duration(hours: 23, minutes: 59)), DateTime.now()),
                            const SizedBox(width: 8),
                            _buildDateChip('Yesterday', DateTime.now().subtract(const Duration(days: 1)).subtract(const Duration(hours: 23, minutes: 59)), DateTime.now().subtract(const Duration(days: 1))),
                            const SizedBox(width: 8),
                            _buildDateChip('Last 7 Days', DateTime.now().subtract(const Duration(days: 7)), DateTime.now()),
                            const SizedBox(width: 8),
                            _buildDateChip('Last 30 Days', DateTime.now().subtract(const Duration(days: 30)), DateTime.now()),
                            const SizedBox(width: 8),
                            _buildDateChip('This Month', DateTime(DateTime.now().year, DateTime.now().month, 1), DateTime.now()),
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
                      // Total Collections KPI Card
                      Container(
                        padding: const EdgeInsets.all(24),
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PAYMENTS COLLECTED',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '₹${totalCollected.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.success,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Across ${filteredPayments.length} transactions',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.account_balance_wallet, color: AppColors.success, size: 28),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Donut Chart Card (Payment Breakdown)
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
                              'Payment Method Share',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Distribution of collected payments',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 16),
                            methodSplits.isEmpty
                                ? Container(
                                    height: 160,
                                    alignment: Alignment.center,
                                    child: Text('No transactions recorded', style: TextStyle(color: Colors.grey.shade500)),
                                  )
                                : Row(
                                    children: [
                                      // Chart Side
                                      SizedBox(
                                        width: 140,
                                        height: 140,
                                        child: CustomPaint(
                                          painter: _DonutChartPainter(methodSplits, methodColors),
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      // Legend Side
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: List.generate(methodSplits.length, (index) {
                                            final key = methodSplits.keys.elementAt(index);
                                            final val = methodSplits[key]!;
                                            final color = methodColors[index % methodColors.length];
                                            final percent = totalCollected == 0 ? 0.0 : (val / totalCollected) * 100;

                                            return Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 10,
                                                    height: 10,
                                                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      key,
                                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${percent.toStringAsFixed(1)}%',
                                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                        ),
                                      )
                                    ],
                                  ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Transactions List
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
                              'Payment Records',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 16),
                            filteredPayments.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 32.0),
                                    child: Center(
                                      child: Text('No payments in this date range', style: TextStyle(color: Colors.grey.shade500)),
                                    ),
                                  )
                                : ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: filteredPayments.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final pay = filteredPayments[index];
                                      final cust = customers.firstWhere(
                                        (c) => c.id == pay.customerId,
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
                                          'Method: ${pay.paymentMethod} • ${DateFormat('dd MMM yyyy').format(pay.paymentDate)}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        trailing: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '₹${pay.amount.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                color: AppColors.success,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            if (pay.notes != null && pay.notes!.isNotEmpty) ...[
                                              Text(
                                                pay.notes!,
                                                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              )
                                            ]
                                          ],
                                        ),
                                        onTap: () {
                                          if (pay.invoiceId.isNotEmpty) {
                                            context.push('/invoices/${pay.invoiceId}');
                                          }
                                        },
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

  Widget _buildDateChip(String label, DateTime start, DateTime end) {
    final isSelected = _dateRangeLabel == label ||
        (_startDate.day == start.day &&
            _startDate.month == start.month &&
            _startDate.year == start.year &&
            _endDate.day == end.day &&
            _endDate.month == end.month &&
            _endDate.year == end.year);

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          _setDateRange(label, start, end);
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

class _DonutChartPainter extends CustomPainter {
  final Map<String, double> data;
  final List<Color> colors;

  _DonutChartPainter(this.data, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final total = data.values.fold<double>(0.0, (sum, val) => sum + val);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2.5;

    if (total == 0) {
      final paint = Paint()
        ..color = Colors.grey.shade200
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14;
      canvas.drawCircle(center, radius, paint);
      return;
    }

    double startAngle = -3.14159 / 2; // -90 degrees
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    int i = 0;
    data.forEach((key, val) {
      final sweepAngle = (val / total) * 2 * 3.14159;
      paint.color = colors[i % colors.length];

      // Draw arc with a small gap (e.g. 0.08 radians)
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle - 0.08,
        false,
        paint,
      );

      startAngle += sweepAngle;
      i++;
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
