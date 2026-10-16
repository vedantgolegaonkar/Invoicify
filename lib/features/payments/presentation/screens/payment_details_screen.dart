import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/payment_providers.dart';
import '../../../customers/providers/customer_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/loading_state.dart';
import '../../../../shared/widgets/error_state.dart';

class PaymentDetailsScreen extends ConsumerWidget {
  final String paymentId;

  const PaymentDetailsScreen({super.key, required this.paymentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(paymentsStreamProvider);
    final customersAsync = ref.watch(customersStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Payment Details'),
        backgroundColor: Colors.transparent,
      ),
      body: paymentsAsync.when(
        loading: () => const LoadingState(message: 'Loading payment details...'),
        error: (error, stack) => ErrorState(
          message: error.toString(),
          onRetry: () => ref.refresh(paymentsStreamProvider),
        ),
        data: (payments) {
          final payment = payments.where((p) => p.id == paymentId).firstOrNull;
          if (payment == null) {
            return const Center(child: Text('Payment not found'));
          }

          final customer = customersAsync.value?.where((c) => c.id == payment.customerId).firstOrNull;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Amount Card
                _buildCard(
                  child: Column(
                    children: [
                      const Text('AMOUNT PAID', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      const SizedBox(height: 8),
                      Text(
                        '₹${payment.amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.success),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          payment.paymentMethod,
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Details Card
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: AppColors.primary.withValues(alpha: 0.8)),
                          const SizedBox(width: 8),
                          const Text(
                            'PAYMENT INFO',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow('Payment ID', 'REC-${payment.id.substring(0, 8)}'),
                      const Divider(height: 24),
                      _buildDetailRow('Date', DateFormat('dd MMM yyyy, hh:mm a').format(payment.paymentDate)),
                      if (payment.invoiceId.isNotEmpty) ...[
                        const Divider(height: 24),
                        _buildDetailRow('Linked Invoice', 'INV-${payment.invoiceId.substring(0, 8)}'),
                      ],
                      if (payment.notes != null && payment.notes!.isNotEmpty) ...[
                        const Divider(height: 24),
                        _buildDetailRow('Notes', payment.notes!),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Customer Card
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_pin_circle_outlined, size: 18, color: AppColors.primary.withValues(alpha: 0.8)),
                          const SizedBox(width: 8),
                          const Text(
                            'CUSTOMER DETAILS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person_outline, color: AppColors.primary, size: 26),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  customer?.name ?? 'Unknown Customer',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  customer?.mobile ?? 'N/A',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (customer?.mobile != null && customer!.mobile.isNotEmpty)
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.phone_outlined, color: AppColors.success, size: 20),
                                onPressed: () async {
                                  final url = Uri.parse('tel:${customer.mobile}');
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(url);
                                  } else {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Could not launch dialer')),
                                      );
                                    }
                                  }
                                },
                              ),
                            ),
                        ],
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

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
