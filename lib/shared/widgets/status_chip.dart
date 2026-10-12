import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  final String status;
  final Color? color;
  final Color? textColor;

  const StatusChip({
    super.key,
    required this.status,
    this.color,
    this.textColor,
  });

  factory StatusChip.paid() => const StatusChip(
        status: 'Paid',
        color: Colors.green,
        textColor: Colors.white,
      );

  factory StatusChip.unpaid() => const StatusChip(
        status: 'Unpaid',
        color: Colors.red,
        textColor: Colors.white,
      );

  factory StatusChip.partiallyPaid() => const StatusChip(
        status: 'Partially Paid',
        color: Colors.orange,
        textColor: Colors.white,
      );

  factory StatusChip.draft() => const StatusChip(
        status: 'Draft',
        color: Colors.grey,
        textColor: Colors.white,
      );

  factory StatusChip.confirmed() => const StatusChip(
        status: 'Confirmed',
        color: Colors.blue,
        textColor: Colors.white,
      );

  factory StatusChip.delivered() => const StatusChip(
        status: 'Delivered',
        color: Colors.green,
        textColor: Colors.white,
      );

  factory StatusChip.cancelled() => const StatusChip(
        status: 'Cancelled',
        color: Colors.redAccent,
        textColor: Colors.white,
      );

  factory StatusChip.lowStock() => const StatusChip(
        status: 'Low Stock',
        color: Colors.deepOrange,
        textColor: Colors.white,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor ?? Colors.white,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
