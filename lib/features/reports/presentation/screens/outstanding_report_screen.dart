import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../invoices/providers/invoice_providers.dart';
import '../../../customers/providers/customer_providers.dart';
import '../../../payments/providers/payment_providers.dart';
import '../../../settings/providers/business_providers.dart';
import '../../../customers/domain/customer_model.dart';
import '../../../invoices/domain/invoice_model.dart';

class OutstandingReportScreen extends ConsumerStatefulWidget {
  const OutstandingReportScreen({super.key});

  @override
  ConsumerState<OutstandingReportScreen> createState() => _OutstandingReportScreenState();
}

class _OutstandingReportScreenState extends ConsumerState<OutstandingReportScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _sortByHighest = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _shareWhatsAppReminder(CustomerModel customer, double amount, String businessName) async {
    final cleanMobile = customer.mobile.replaceAll(RegExp(r'\D'), '');
    // Standard Indian mobile prefix format helper if length is 10
    final formattedMobile = cleanMobile.length == 10 ? '91$cleanMobile' : cleanMobile;

    final message = 'Dear ${customer.name},\n\nThis is a friendly reminder that an outstanding balance of ₹${amount.toStringAsFixed(2)} is pending on your account with $businessName. Please settle the payment at your earliest convenience.\n\nThank you!';
    
    final whatsappUrl = Uri.parse('https://wa.me/$formattedMobile?text=${Uri.encodeComponent(message)}');
    
    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp. Ensure it is installed.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersStreamProvider);
    final invoicesAsync = ref.watch(invoicesStreamProvider);
    final paymentsAsync = ref.watch(paymentsStreamProvider);
    final businessAsync = ref.watch(primaryBusinessProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Outstanding Report'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: customersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
        data: (customers) {
          final invoices = (invoicesAsync.value ?? []).where((i) => !i.isDeleted).toList();
          final payments = (paymentsAsync.value ?? []).where((p) => !p.isDeleted).toList();
          final businessName = businessAsync?.businessName ?? 'our business';

          // Compute outstanding dynamically for all customers
          final List<_OutstandingItem> items = customers
              .where((c) => !c.isDeleted)
              .map((cust) {
                final custInvoices = invoices.where((i) => i.customerId == cust.id).toList();
                final custPayments = payments.where((p) => p.customerId == cust.id).toList();

                final totalSales = custInvoices.fold<double>(0.0, (s, i) => s + i.total);
                final totalPaid = custPayments.fold<double>(0.0, (s, p) => s + p.amount);
                final outstanding = totalSales - totalPaid;

                // Count unpaid invoices
                final pendingInvoicesCount = custInvoices.where((i) => i.status != InvoiceStatus.paid).length;

                return _OutstandingItem(
                  customer: cust,
                  outstanding: outstanding,
                  pendingInvoicesCount: pendingInvoicesCount,
                );
              })
              .where((item) => item.outstanding > 0.01) // filters non-zero outstanding balances
              .toList();

          // Search query filter
          final filteredItems = items.where((item) {
            final nameMatch = item.customer.name.toLowerCase().contains(_searchQuery.toLowerCase());
            final mobileMatch = item.customer.mobile.contains(_searchQuery);
            return nameMatch || mobileMatch;
          }).toList();

          // Sort items
          filteredItems.sort((a, b) {
            return _sortByHighest 
                ? b.outstanding.compareTo(a.outstanding)
                : a.outstanding.compareTo(b.outstanding);
          });

          // Metrics calculations
          final totalOutstanding = items.fold<double>(0.0, (sum, item) => sum + item.outstanding);
          final customerCount = items.length;
          final totalPendingInvoices = items.fold<int>(0, (sum, item) => sum + item.pendingInvoicesCount);

          return Column(
            children: [
              // Header Search and Filters
              Container(
                color: AppColors.primary,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search customer...',
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
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Sort: ${_sortByHighest ? "Highest Outstanding First" : "Lowest Outstanding First"}',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _sortByHighest = !_sortByHighest;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.sort, color: Colors.white, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'Toggle',
                                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        )
                      ],
                    )
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Overview Metrics Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE57373), Color(0xFFD32F2F)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.error.withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 6),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TOTAL OUTSTANDING DUE',
                              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '₹${totalOutstanding.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Due Customers', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                    const SizedBox(height: 2),
                                    Text('$customerCount', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Container(width: 1, height: 24, color: Colors.white30),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Unpaid Invoices', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                    const SizedBox(height: 2),
                                    Text('$totalPendingInvoices', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // List Card
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
                              'Outstanding Ledger',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Showing ${filteredItems.length} accounts with balances',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 16),
                            filteredItems.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 32.0),
                                    child: Center(
                                      child: Text('No outstanding accounts found'),
                                    ),
                                  )
                                : ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: filteredItems.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final item = filteredItems[index];
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item.customer.name,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${item.pendingInvoicesCount} unpaid invoices • ${item.customer.mobile}',
                                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  '₹${item.outstanding.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    color: AppColors.error,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    // Record Payment Button
                                                    IconButton(
                                                      icon: const Icon(Icons.payment, size: 18, color: AppColors.success),
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                      onPressed: () => context.push(
                                                        '/payments/record?customerId=${item.customer.id}&amount=${item.outstanding}',
                                                      ),
                                                      tooltip: 'Record Payment',
                                                    ),
                                                    const SizedBox(width: 14),
                                                    // WhatsApp Reminder Button
                                                    IconButton(
                                                      icon: const Icon(Icons.share, size: 18, color: Color(0xFF25D366)),
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                      onPressed: () => _shareWhatsAppReminder(
                                                        item.customer,
                                                        item.outstanding,
                                                        businessName,
                                                      ),
                                                      tooltip: 'Send WhatsApp Reminder',
                                                    ),
                                                  ],
                                                )
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
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OutstandingItem {
  final CustomerModel customer;
  final double outstanding;
  final int pendingInvoicesCount;

  _OutstandingItem({
    required this.customer,
    required this.outstanding,
    required this.pendingInvoicesCount,
  });
}
