import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../providers/notification_providers.dart';
import '../../data/notification_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
            onPressed: () {
              final repo = ref.read(notificationRepositoryProvider);
              final currentList = ref.read(notificationsStreamProvider).value;
              if (currentList != null) {
                for (final n in currentList) {
                  if (!n.isRead && !n.isDeleted) {
                    repo.update(n.id, {'isRead': true});
                  }
                }
              }
            },
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error loading notifications: $e')),
        data: (notifications) {
          final activeNotifications = notifications.where((n) => !n.isDeleted).toList();
          
          if (activeNotifications.isEmpty) {
            return const EmptyState(
              title: 'No Notifications',
              message: 'You\'re all caught up.',
              icon: Icons.notifications_none,
            );
          }

          // Sort descending by date
          activeNotifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: activeNotifications.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final notification = activeNotifications[index];
              final isRead = notification.isRead;
              
              // Sanitize legacy auto-generated messages
              String displayTitle = notification.title;
              String displayMessage = notification.message;
              
              if (displayTitle.contains('users/') || displayTitle.contains('A new record')) {
                if (displayTitle.contains('/customers')) displayTitle = 'Customer Added';
                else if (displayTitle.contains('/products')) displayTitle = 'Product Added';
                else if (displayTitle.contains('/invoices')) displayTitle = 'Invoice Created';
                else if (displayTitle.contains('/orders')) displayTitle = 'Order Created';
                else if (displayTitle.contains('/payments')) displayTitle = 'Payment Recorded';
                else displayTitle = 'New Activity';
                
                displayMessage = 'A new $displayTitle was successfully recorded in your account.';
              }

              final timeAgo = _getTimeAgo(notification.createdAt);

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                    color: isRead ? Colors.grey.shade200 : const Color(0xFF4E342E).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      if (!isRead) {
                        ref.read(notificationRepositoryProvider).update(notification.id, {'isRead': true});
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isRead ? Colors.grey.shade100 : const Color(0xFF4E342E),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getIconForTitle(displayTitle),
                              color: isRead ? Colors.grey.shade400 : Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        displayTitle,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                          color: isRead ? Colors.grey.shade800 : Colors.black,
                                        ),
                                      ),
                                    ),
                                    if (!isRead)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        margin: const EdgeInsets.only(left: 8),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFD32F2F), // Error/Red color for high visibility
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  displayMessage,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isRead ? Colors.grey.shade500 : Colors.grey.shade700,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  timeAgo,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade400,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return DateFormat('MMM d, yyyy').format(date);
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'min' : 'mins'} ago';
    } else {
      return 'Just now';
    }
  }

  IconData _getIconForTitle(String title) {
    final t = title.toLowerCase();
    if (t.contains('customer')) return Icons.person_add_alt_1;
    if (t.contains('product')) return Icons.inventory_2_outlined;
    if (t.contains('invoice')) return Icons.receipt_long_outlined;
    if (t.contains('order')) return Icons.shopping_cart_outlined;
    if (t.contains('payment')) return Icons.account_balance_wallet_outlined;
    return Icons.notifications_active_outlined;
  }
}
