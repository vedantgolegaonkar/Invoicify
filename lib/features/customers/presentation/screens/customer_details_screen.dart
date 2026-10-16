import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../invoices/providers/invoice_providers.dart';
import '../../../payments/providers/payment_providers.dart';
import 'package:intl/intl.dart';
import '../../../orders/providers/order_providers.dart';
import 'package:go_router/go_router.dart';
import '../../providers/customer_providers.dart';
import '../../data/customer_repository.dart';
import '../../../products/providers/product_providers.dart';

class CustomerDetailsScreen extends ConsumerWidget {
  final String customerId;

  const CustomerDetailsScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Customer Details'),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                context.push('/customers/$customerId/edit');
              },
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Info'),
              Tab(text: 'Ledger'),
              Tab(text: 'Timeline'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _CustomerInfo(customerId: customerId, ref: ref),
            _CustomerLedger(customerId: customerId, ref: ref),
            _CustomerTimeline(customerId: customerId, ref: ref),
          ],
        ),
      ),
    );
  }
}

class _CustomerInfo extends ConsumerStatefulWidget {
  final String customerId;
  final WidgetRef ref; // Kept for compatibility with the parent call

  const _CustomerInfo({required this.customerId, required this.ref});

  @override
  ConsumerState<_CustomerInfo> createState() => _CustomerInfoState();
}

class _CustomerInfoState extends ConsumerState<_CustomerInfo> {
  bool _showAllInvoices = false;

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(enrichedCustomersProvider);
    final invoicesAsync = ref.watch(invoicesStreamProvider);
    final paymentsAsync = ref.watch(paymentsStreamProvider);
    if (customersAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final customer = customersAsync.value?.where((c) => c.id == widget.customerId).firstOrNull;
    if (customer == null) {
      return const Center(child: Text('Customer not found.'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: const Text('Customer Name'),
          subtitle: Text(customer.name),
        ),
        if (customer.businessName != null && customer.businessName!.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.business_outlined),
            title: const Text('Business Name'),
            subtitle: Text(customer.businessName!),
          ),
        ListTile(
          leading: const Icon(Icons.phone_outlined),
          title: const Text('Mobile Number'),
          subtitle: Text(customer.mobile),
        ),
        if (customer.whatsappNumber != null && customer.whatsappNumber!.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.chat_outlined),
            title: const Text('WhatsApp Number'),
            subtitle: Text(customer.whatsappNumber!),
          ),
        if (customer.email != null && customer.email!.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Email'),
            subtitle: Text(customer.email!),
          ),
        ListTile(
          leading: const Icon(Icons.location_on_outlined),
          title: const Text('Business Address'),
          subtitle: Text(customer.address),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.account_balance_wallet_outlined, color: Colors.blueGrey),
          title: const Text('Current Outstanding'),
          subtitle: Text(
            '₹${customer.currentOutstanding.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: customer.currentOutstanding > 0 ? Colors.red.shade700 : Colors.green.shade700,
            ),
          ),
          trailing: customer.currentOutstanding > 0 ? ElevatedButton.icon(
            onPressed: () {
              context.push('/payments/record?customerId=${customer.id}&amount=${customer.currentOutstanding}');
            },
            icon: const Icon(Icons.payment, size: 18),
            label: const Text('Pay'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
          ) : null,
        ),
        if (invoicesAsync.hasValue && paymentsAsync.hasValue)
          ...() {
            final invoices = invoicesAsync.value!.where((i) => 
              i.customerId == widget.customerId
            ).toList();
            
            if (invoices.isEmpty) return <Widget>[];
            
            final payments = paymentsAsync.value!;
            invoices.sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));
            
            final List<Widget> widgets = [];
            widgets.add(
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  'Recent Invoices',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade700),
                ),
              ),
            );
            
            final int displayCount = _showAllInvoices ? invoices.length : (invoices.length > 5 ? 5 : invoices.length);
            
            for (int index = 0; index < displayCount; index++) {
              final inv = invoices[index];
              final invPayments = payments.where((p) => p.invoiceId == inv.id).fold(0.0, (sum, p) => sum + p.amount);
              final invOutstanding = inv.total - invPayments;
              
              widgets.add(
                ListTile(
                  visualDensity: VisualDensity.compact,
                  contentPadding: const EdgeInsets.only(left: 48, right: 16),
                  title: Text('Invoice #${inv.invoiceNumber}', style: const TextStyle(fontSize: 14)),
                  subtitle: Text(DateFormat('dd MMM yyyy').format(inv.invoiceDate), style: const TextStyle(fontSize: 12)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Total: ₹${inv.total.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      if (invOutstanding > 0.01)
                        Text(
                          'Due: ₹${invOutstanding.toStringAsFixed(2)}',
                          style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.bold, fontSize: 12),
                        )
                      else
                        Text(
                          'Paid',
                          style: TextStyle(color: Colors.green.shade600, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                    ],
                  ),
                  onTap: () => context.push('/invoices/${inv.id}'),
                ),
              );
            }
            
            if (invoices.length > 5) {
              widgets.add(
                Center(
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _showAllInvoices = !_showAllInvoices;
                      });
                    },
                    child: Text(_showAllInvoices ? 'Show Less' : 'Show All Invoices'),
                  ),
                ),
              );
            }
            
            return widgets;
          }(),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: ElevatedButton.icon(
            onPressed: () => _showManagePricesSheet(context, customer, widget.ref),
            icon: const Icon(Icons.currency_rupee),
            label: const Text('Manage Product Prices'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  void _showManagePricesSheet(BuildContext context, dynamic customer, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return _ManagePricesSheet(customer: customer, scrollController: scrollController);
          },
        );
      },
    );
  }
}

class _ManagePricesSheet extends ConsumerStatefulWidget {
  final dynamic customer;
  final ScrollController scrollController;

  const _ManagePricesSheet({required this.customer, required this.scrollController});

  @override
  ConsumerState<_ManagePricesSheet> createState() => _ManagePricesSheetState();
}

class _ManagePricesSheetState extends ConsumerState<_ManagePricesSheet> {
  late Map<String, double> _productPrices;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _productPrices = Map<String, double>.from(widget.customer.productPrices ?? {});
  }

  Future<void> _savePrices() async {
    setState(() => _isSaving = true);
    try {
      final repository = ref.read(customerRepositoryProvider);
      final updatedCustomer = widget.customer.copyWith(productPrices: _productPrices);
      await repository.update(widget.customer.id, updatedCustomer.toMap());
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prices updated successfully.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Manage Prices', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: productsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
            data: (allProducts) {
              final products = allProducts.where((p) => p.isActive).toList();
              if (products.isEmpty) {
                return const Center(child: Text('No active products found.'));
              }
              return ListView.builder(
                controller: widget.scrollController,
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final p = products[index];
                  final initialPrice = _productPrices[p.id]?.toString() ?? '';
                  
                  return ListTile(
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('HSN: ${p.hsnCode ?? 'N/A'}'),
                    trailing: SizedBox(
                      width: 100,
                      child: TextFormField(
                        initialValue: initialPrice,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          prefixText: '₹ ',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        onChanged: (val) {
                          final price = double.tryParse(val);
                          if (price != null && price >= 0) {
                            _productPrices[p.id] = price;
                          } else {
                            _productPrices.remove(p.id);
                          }
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _savePrices,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
              child: _isSaving 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save Prices', style: TextStyle(fontSize: 16)),
            ),
          ),
        ),
      ],
    );
  }
}

class _CustomerLedger extends StatelessWidget {
  final String customerId;
  final WidgetRef ref;
  
  const _CustomerLedger({required this.customerId, required this.ref});

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoicesStreamProvider);
    final paymentsAsync = ref.watch(paymentsStreamProvider);
    
    if (invoicesAsync.isLoading || paymentsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final invoices = invoicesAsync.value?.where((i) => i.customerId == customerId).toList() ?? [];
    final payments = paymentsAsync.value?.where((p) => p.customerId == customerId).toList() ?? [];
    
    if (invoices.isEmpty && payments.isEmpty) {
      return const Center(child: Text('No ledger entries found for this customer.'));
    }
    
    // Create unified ledger entries
    final List<Map<String, dynamic>> ledgerEntries = [];
    
    for (var inv in invoices) {
      ledgerEntries.add({
        'date': inv.invoiceDate,
        'type': 'invoice',
        'title': 'Invoice #${inv.invoiceNumber}',
        'amount': inv.total, // debit (increases outstanding)
        'id': inv.id,
      });
    }
    
    for (var pay in payments) {
      ledgerEntries.add({
        'date': pay.paymentDate,
        'type': 'payment',
        'title': 'Payment Received',
        'amount': pay.amount, // credit (decreases outstanding)
        'id': pay.id,
      });
    }
    
    // Sort chronologically (oldest first) to compute running balance
    ledgerEntries.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    
    double runningBalance = 0.0;
    for (var entry in ledgerEntries) {
      if (entry['type'] == 'invoice') {
        runningBalance += entry['amount'] as double;
      } else {
        runningBalance -= entry['amount'] as double;
      }
      entry['balance'] = runningBalance;
    }
    
    // Reverse so newest entries are at the top
    final displayEntries = ledgerEntries.reversed.toList();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: displayEntries.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final entry = displayEntries[index];
        final isPayment = entry['type'] == 'payment';
        final amount = entry['amount'] as double;
        final balance = entry['balance'] as double;
        
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isPayment ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPayment ? Icons.arrow_downward : Icons.arrow_upward,
                color: isPayment ? Colors.green : Colors.red,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry['title'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('dd MMM yyyy, hh:mm a').format(entry['date'] as DateTime),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isPayment ? '-₹${amount.toStringAsFixed(2)}' : '+₹${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: isPayment ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Bal: ₹${balance.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.blueGrey.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _CustomerTimeline extends StatelessWidget {
  final String customerId;
  final WidgetRef ref;

  const _CustomerTimeline({required this.customerId, required this.ref});

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(enrichedCustomersProvider);
    final ordersAsync = ref.watch(ordersStreamProvider);
    final invoicesAsync = ref.watch(invoicesStreamProvider);
    final paymentsAsync = ref.watch(paymentsStreamProvider);

    if (customersAsync.isLoading ||
        ordersAsync.isLoading ||
        invoicesAsync.isLoading ||
        paymentsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final customer = customersAsync.value?.where((c) => c.id == customerId).firstOrNull;
    final orders = ordersAsync.value?.where((o) => o.customerId == customerId).toList() ?? [];
    final invoices = invoicesAsync.value?.where((i) => i.customerId == customerId).toList() ?? [];
    final payments = paymentsAsync.value?.where((p) => p.customerId == customerId).toList() ?? [];

    if (customer == null) {
      return const Center(child: Text('Customer not found.'));
    }

    // Map to a unified TimelineEvent structure
    final List<Map<String, dynamic>> timelineEvents = [];

    // 1. Customer Creation
    timelineEvents.add({
      'date': customer.createdAt,
      'title': 'Customer Profile Created',
      'icon': Icons.person_add_outlined,
      'color': Colors.blue,
    });

    // 2. Orders
    for (var order in orders) {
      timelineEvents.add({
        'date': order.orderDate,
        'title': 'Order #${order.orderNumber} Placed',
        'subtitle': 'Total: ₹${order.total.toStringAsFixed(2)}',
        'icon': Icons.shopping_cart_outlined,
        'color': Colors.orange,
      });
    }

    // 3. Invoices
    for (var inv in invoices) {
      timelineEvents.add({
        'date': inv.invoiceDate,
        'title': 'Invoice #${inv.invoiceNumber} Generated',
        'subtitle': 'Total: ₹${inv.total.toStringAsFixed(2)}',
        'icon': Icons.receipt_long_outlined,
        'color': Colors.red,
      });
    }

    // 4. Payments
    for (var pay in payments) {
      timelineEvents.add({
        'date': pay.paymentDate,
        'title': 'Payment Received',
        'subtitle': 'Amount: ₹${pay.amount.toStringAsFixed(2)} via ${pay.paymentMethod}',
        'icon': Icons.payments_outlined,
        'color': Colors.green,
      });
    }

    // Sort newest first
    timelineEvents.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    if (timelineEvents.isEmpty) {
      return const Center(child: Text('No timeline events yet.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      itemCount: timelineEvents.length,
      itemBuilder: (context, index) {
        final event = timelineEvents[index];
        final isLast = index == timelineEvents.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline line and icon
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (event['color'] as Color).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    event['icon'] as IconData,
                    color: event['color'] as Color,
                    size: 20,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 40,
                    color: Colors.grey.shade300,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            // Timeline Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event['title'] as String,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd MMM yyyy, hh:mm a').format(event['date'] as DateTime),
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    if (event['subtitle'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        event['subtitle'] as String,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
