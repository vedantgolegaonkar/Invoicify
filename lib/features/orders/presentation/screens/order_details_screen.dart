import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/order_providers.dart';
import '../../domain/order_model.dart';
import '../../data/order_repository.dart';
import '../../../customers/providers/customer_providers.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../customers/domain/customer_model.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderDetailsScreen extends ConsumerWidget {
  final String orderId;

  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersStreamProvider);
    final customersAsync = ref.watch(customersStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Order Details'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              context.push('/orders/$orderId/edit');
            },
          ),
          // IconButton(
          //   icon: const Icon(Icons.print_outlined),
          //   onPressed: () {},
          // ),
        ],
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
        data: (orders) {
          final order = orders.firstWhere(
            (o) => o.id == orderId, 
            orElse: () => throw Exception('Order not found'),
          );

          final customer = customersAsync.value?.firstWhere(
            (c) => c.id == order.customerId,
            orElse: () => throw Exception('Customer not found')
          );

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top header section
                Container(
                  color: AppColors.primary,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              'Order #${order.orderNumber}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _buildStatusChip(order.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('dd MMM yyyy, hh:mm a').format(order.orderDate),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Content section overlapping header
                Transform.translate(
                  offset: const Offset(0, -20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
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
                                        if (customer != null && customer.currentOutstanding > 0) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Outstanding: ₹${customer.currentOutstanding.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.error,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.phone_outlined, color: AppColors.success, size: 20),
                                      onPressed: () async {
                                        final mobile = customer?.mobile;
                                        if (mobile != null && mobile.isNotEmpty) {
                                          final url = Uri.parse('tel:$mobile');
                                          if (await canLaunchUrl(url)) {
                                            await launchUrl(url);
                                          } else {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Could not launch dialer')),
                                              );
                                            }
                                          }
                                        } else {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('No mobile number available')),
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
                        const SizedBox(height: 16),
                        
                        // Items Card
                        _buildCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.shopping_bag_outlined, size: 18, color: AppColors.primary.withValues(alpha: 0.8)),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'ORDER ITEMS',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${order.items.length} Items',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: order.items.length,
                                separatorBuilder: (_, __) => const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Divider(height: 1),
                                ),
                                itemBuilder: (context, index) {
                                  final item = order.items[index];
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceVariant,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.inventory_2_outlined, color: AppColors.textSecondary, size: 22),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.productName,
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              '${item.quantity} x ₹${item.unitPrice.toStringAsFixed(2)}',
                                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '₹${item.total.toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Summary Card
                        _buildCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.primary.withValues(alpha: 0.8)),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'PAYMENT SUMMARY',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              _buildSummaryRow('Subtotal', order.subtotal),
                              const SizedBox(height: 12),
                              _buildSummaryRow('GST', order.gst),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Divider(height: 1),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total Amount',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold, 
                                      fontSize: 16,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '₹${order.total.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold, 
                                      fontSize: 22,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (order.notes != null && order.notes!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.notes_outlined, size: 18, color: AppColors.primary.withValues(alpha: 0.8)),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'NOTES',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    order.notes!,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        
                        // Status Action Buttons
                        if (order.status == OrderStatus.draft) ...[
                          _buildActionButton(
                            context: context,
                            ref: ref,
                            orderId: order.id,
                            label: 'Confirm Order',
                            icon: Icons.check_circle_outline,
                            color: AppColors.info,
                            newStatus: OrderStatus.confirmed,
                            customer: customer,
                          ),
                          const SizedBox(height: 12),
                          _buildActionButton(
                            context: context,
                            ref: ref,
                            orderId: order.id,
                            label: 'Cancel Order',
                            icon: Icons.cancel_outlined,
                            color: AppColors.error,
                            newStatus: OrderStatus.cancelled,
                            customer: customer,
                            isOutlined: true,
                          ),
                        ] else if (order.status == OrderStatus.confirmed) ...[
                          _buildActionButton(
                            context: context,
                            ref: ref,
                            orderId: order.id,
                            label: 'Mark as Delivered',
                            icon: Icons.local_shipping_outlined,
                            color: AppColors.success,
                            newStatus: OrderStatus.delivered,
                            customer: customer,
                            isEnabled: customer != null && customer.currentOutstanding <= 0,
                          ),
                          const SizedBox(height: 12),
                          _buildActionButton(
                            context: context,
                            ref: ref,
                            orderId: order.id,
                            label: 'Cancel Order',
                            icon: Icons.cancel_outlined,
                            color: AppColors.error,
                            newStatus: OrderStatus.cancelled,
                            customer: customer,
                            isOutlined: true,
                          ),
                        ],
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required WidgetRef ref,
    required String orderId,
    required String label,
    required IconData icon,
    required Color color,
    required OrderStatus newStatus,
    required CustomerModel? customer,
    bool isOutlined = false,
    bool isEnabled = true,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: isOutlined
          ? OutlinedButton.icon(
              onPressed: isEnabled ? () => _updateOrderStatus(context, ref, orderId, newStatus, customer) : null,
              icon: Icon(icon, color: color),
              label: Text(label, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: color),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )
          : ElevatedButton.icon(
              onPressed: isEnabled ? () => _updateOrderStatus(context, ref, orderId, newStatus, customer) : null,
              icon: Icon(icon),
              label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
    );
  }

  Future<void> _updateOrderStatus(BuildContext context, WidgetRef ref, String orderId, OrderStatus newStatus, CustomerModel? customer) async {
    if (newStatus == OrderStatus.delivered && (customer == null || customer.currentOutstanding > 0)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot mark as delivered. Customer has an outstanding balance of ₹${customer?.currentOutstanding.toStringAsFixed(2) ?? 'Unknown'}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    try {
      await ref.read(orderRepositoryProvider).update(orderId, {'status': newStatus.name});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order status updated to ${newStatus.name}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.textSecondary.withValues(alpha: 0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSummaryRow(String label, double value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary, 
            fontSize: 15,
          ),
        ),
        Text(
          '₹${value.toStringAsFixed(2)}',
          style: const TextStyle(
            fontWeight: FontWeight.w600, 
            fontSize: 15,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(OrderStatus status) {
    // Determine the color based on status
    Color color;
    switch (status) {
      case OrderStatus.draft:
        color = Colors.grey.shade700;
        break;
      case OrderStatus.confirmed:
        color = AppColors.info;
        break;
      case OrderStatus.delivered:
        color = AppColors.success;
        break;
      case OrderStatus.cancelled:
        color = AppColors.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status.name,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
