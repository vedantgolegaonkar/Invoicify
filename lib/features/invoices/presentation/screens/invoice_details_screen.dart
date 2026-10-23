import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:printing/printing.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../providers/invoice_providers.dart';
import '../../domain/invoice_model.dart';
import '../../../customers/providers/customer_providers.dart';
import '../../../customers/domain/customer_model.dart';
import '../../../products/providers/product_providers.dart';
import '../../../products/domain/product_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/invoice_repository.dart';
import '../../../customers/data/customer_repository.dart';
import '../../../products/data/product_repository.dart';
import '../../../inventory/data/inventory_repository.dart';
import '../../../inventory/domain/inventory_transaction_model.dart';
import 'package:uuid/uuid.dart';
import '../../../orders/providers/order_providers.dart';
import '../../../payments/providers/payment_providers.dart';
import '../../../settings/providers/business_providers.dart';
import '../../../settings/domain/business_model.dart';
import '../../../settings/providers/settings_providers.dart';
import '../../../settings/domain/settings_model.dart';
import '../../../../services/invoice_pdf_service.dart';

class InvoiceDetailsScreen extends ConsumerWidget {
  final String invoiceId;

  const InvoiceDetailsScreen({super.key, required this.invoiceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(invoicesStreamProvider);
    final customersAsync = ref.watch(customersStreamProvider);
    final productsAsync = ref.watch(productsStreamProvider);
    final ordersAsync = ref.watch(ordersStreamProvider);
    final paymentsAsync = ref.watch(paymentsStreamProvider);
    final business = ref.watch(primaryBusinessProvider);
    final settings = ref.watch(settingsStreamProvider).value;

    return invoicesAsync.when(
      loading: () => Scaffold(appBar: AppBar(title: const Text('Invoice Details')), body: const Center(child: CircularProgressIndicator())),
      error: (err, st) => Scaffold(appBar: AppBar(title: const Text('Invoice Details')), body: Center(child: Text('Error: $err'))),
      data: (invoices) {
          final invoiceMatches = invoices.where((i) => i.id == invoiceId);
          if (invoiceMatches.isEmpty) {
            return Scaffold(
              appBar: AppBar(title: const Text('Invoice Details')),
              body: const Center(child: Text('Invoice not found or deleted.')),
            );
          }
          final invoice = invoiceMatches.first;

          final customer = customersAsync.value?.where((c) => c.id == invoice.customerId).firstOrNull;
          final products = productsAsync.value ?? [];
          
          final orders = ordersAsync.value ?? [];
          final isCancelled = orders.any((o) => o.id == invoice.orderId && o.status.name == 'cancelled');
          
          final payments = paymentsAsync.value ?? [];
          final amountPaid = payments
              .where((p) => p.invoiceId == invoiceId)
              .fold(0.0, (sum, p) => sum + p.amount);
          double outstanding = invoice.total - amountPaid;
          if (outstanding < 0) outstanding = 0;

          // Breakdown tax by CGST, SGST, IGST
          double totalCgst = 0.0;
          double totalSgst = 0.0;
          double totalIgst = 0.0;
          final Set<double> cgstRates = {};
          final Set<double> sgstRates = {};
          final Set<double> igstRates = {};

          for (final item in invoice.items) {
            final product = products.where((p) => p.id == item.productId).firstOrNull;
            if (product != null) {
              if (product.cgst > 0) {
                totalCgst += (item.subtotal * product.cgst) / 100;
                cgstRates.add(product.cgst);
              }
              if (product.sgst > 0) {
                totalSgst += (item.subtotal * product.sgst) / 100;
                sgstRates.add(product.sgst);
              }
              if (product.igst > 0) {
                totalIgst += (product.igst * item.quantity);
                igstRates.add(product.igst);
              }
            } else {
              // Fallback split if product not in catalog
              final half = item.gstAmount / 2;
              totalCgst += half;
              totalSgst += half;
            }
          }


          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: const Text('Invoice Details'),
              elevation: 0,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit Invoice',
                  onPressed: () => context.push('/invoices/$invoiceId/edit'),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete Invoice',
                  onPressed: () => _confirmDelete(context, ref, invoice),
                ),
              ],
            ),
            body: SingleChildScrollView(
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
                              'Invoice #${invoice.invoiceNumber}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          isCancelled ? StatusChip.cancelled() : _buildStatusChip(invoice.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('dd MMM yyyy, hh:mm a').format(invoice.createdAt),
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
                                        'INVOICE ITEMS',
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
                                      '${invoice.items.length} Items',
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
                                itemCount: invoice.items.length,
                                separatorBuilder: (_, __) => const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Divider(height: 1),
                                ),
                                itemBuilder: (context, index) {
                                  final item = invoice.items[index];
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
                                        '₹${item.subtotal.toStringAsFixed(2)}',
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
                              _buildSummaryRow('Subtotal', invoice.subtotal),
                              const SizedBox(height: 12),
                              if (totalCgst > 0 || (totalSgst == 0 && totalIgst == 0 && invoice.gst > 0)) ...[
                                _buildSummaryRow(
                                  cgstRates.isNotEmpty
                                      ? 'CGST (${cgstRates.map((r) => r % 1 == 0 ? r.toInt().toString() : r.toStringAsFixed(1)).join(', ')}%)'
                                      : 'CGST',
                                  totalCgst,
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (totalSgst > 0 || (totalCgst > 0 && totalIgst == 0 && invoice.gst > 0 && totalSgst > 0)) ...[
                                _buildSummaryRow(
                                  sgstRates.isNotEmpty
                                      ? 'SGST (${sgstRates.map((r) => r % 1 == 0 ? r.toInt().toString() : r.toStringAsFixed(1)).join(', ')}%)'
                                      : 'SGST',
                                  totalSgst,
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (totalIgst > 0) ...[
                                _buildSummaryRow(
                                  igstRates.isNotEmpty
                                      ? 'IGST (${igstRates.map((r) => '₹${r % 1 == 0 ? r.toInt() : r.toStringAsFixed(2)}').join(', ')})'
                                      : 'IGST',
                                  totalIgst,
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (totalCgst == 0 && totalSgst == 0 && totalIgst == 0 && invoice.gst > 0) ...[
                                _buildSummaryRow('GST', invoice.gst),
                                const SizedBox(height: 12),
                              ],
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Divider(height: 1),
                              ),
                              _buildSummaryRow('Total Amount', invoice.total, isBold: true),
                              const SizedBox(height: 12),
                              _buildSummaryRow('Amount Paid', amountPaid, isBold: true, valueColor: AppColors.success),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Divider(height: 1),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Outstanding Amount',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 16,
                                        color: AppColors.error,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '₹${outstanding.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 22,
                                        color: AppColors.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
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
                                    invoice.notes!,
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
                        
                        // Action Buttons: Preview Invoice & Download
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 50,
                                child: OutlinedButton.icon(
                                  onPressed: () => _previewPdf(context, invoice, customer, business, settings, products, amountPaid),
                                  icon: const Icon(Icons.remove_red_eye_outlined),
                                  label: const Text('Preview', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: () => _sharePdf(invoice, customer, business, settings, products, amountPaid),
                                  icon: const Icon(Icons.download_outlined),
                                  label: const Text('Download', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!isCancelled && invoice.status != InvoiceStatus.paid && outstanding > 0) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: () => context.push(
                                '/payments/record?invoiceId=${invoice.id}&invoiceNumber=${invoice.invoiceNumber}&customerId=${invoice.customerId}&amount=${invoice.total}',
                              ),
                              icon: const Icon(Icons.payment),
                              label: const Text('Record Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          );
        },
      );
  }

  void _previewPdf(
    BuildContext context,
    InvoiceModel invoice,
    CustomerModel? customer,
    BusinessModel? business,
    SettingsModel? settings,
    List<ProductModel>? products,
    double amountPaid,
  ) {
    final rawCustomerName = (customer?.name ?? '').trim();
    final customerName = rawCustomerName.isNotEmpty
        ? rawCustomerName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        : 'Customer';
    final filename = 'INV_$customerName-Invoice.pdf';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('Invoice #${invoice.invoiceNumber}'),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: PdfPreview(
            build: (format) => InvoicePdfService.generateInvoicePdfBytes(
              invoice: invoice,
              customer: customer,
              business: business,
              settings: settings,
              products: products,
              amountPaid: amountPaid,
            ),
            pdfFileName: filename,
            canChangeOrientation: false,
            canChangePageFormat: false,
            canDebug: false,
            allowPrinting: true,
            allowSharing: true,
          ),
        ),
      ),
    );
  }

  Future<void> _sharePdf(
    InvoiceModel invoice,
    CustomerModel? customer,
    BusinessModel? business,
    SettingsModel? settings,
    List<ProductModel>? products,
    double amountPaid,
  ) async {
    await InvoicePdfService.shareInvoicePdf(
      invoice: invoice,
      customer: customer,
      business: business,
      settings: settings,
      products: products,
      amountPaid: amountPaid,
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, InvoiceModel invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: Text(
          'Are you sure you want to delete invoice #${invoice.invoiceNumber}? This will revert the customer outstanding balance and restore deducted inventory.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final invoiceRepo = ref.read(invoiceRepositoryProvider);
        final customerRepo = ref.read(customerRepositoryProvider);
        final productRepo = ref.read(productRepositoryProvider);
        final inventoryRepo = ref.read(inventoryRepositoryProvider);

        // 1. Revert customer outstanding
        try {
          final cust = await customerRepo.getById(invoice.customerId);
          if (cust != null) {
            final newOutstanding = (cust.currentOutstanding - invoice.total).clamp(0.0, double.infinity);
            await customerRepo.update(invoice.customerId, {'currentOutstanding': newOutstanding});
          }
        } catch (e) {
          debugPrint('Error reverting customer outstanding on delete: $e');
        }

        // 2. Restore inventory if created standalone (dummy_order_id)
        if (invoice.orderId == 'dummy_order_id') {
          try {
            final currentProducts = await productRepo.getAll();
            final now = DateTime.now();
            for (final item in invoice.items) {
              final prod = currentProducts.where((p) => p.id == item.productId).firstOrNull;
              if (prod != null) {
                final restoredStock = prod.currentStock + item.quantity;
                await productRepo.update(item.productId, {'currentStock': restoredStock});
                final txnId = const Uuid().v4();
                final txn = InventoryTransactionModel(
                  id: txnId,
                  productId: item.productId,
                  type: TransactionType.stockIn,
                  quantity: item.quantity,
                  previousStock: prod.currentStock,
                  newStock: restoredStock,
                  remarks: 'Invoice Deleted: ${invoice.invoiceNumber}',
                  createdAt: now,
                  updatedAt: now,
                );
                await inventoryRepo.create(txn, txnId);
              }
            }
          } catch (e) {
            debugPrint('Error restoring stock on invoice delete: $e');
          }
        }

        // 3. Soft delete invoice
        await invoiceRepo.softDelete(invoice.id);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invoice deleted successfully')),
          );
          context.pop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting invoice: $e')),
          );
        }
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

  Widget _buildSummaryRow(String label, double value, {bool isBold = false, Color valueColor = AppColors.textPrimary}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary, 
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(width: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '₹${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600, 
              fontSize: 15,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(InvoiceStatus status) {
    // Determine the color based on status
    Color color;
    switch (status) {
      case InvoiceStatus.paid:
        color = AppColors.success;
        break;
      case InvoiceStatus.unpaid:
        color = AppColors.error;
        break;
      case InvoiceStatus.partiallyPaid:
        color = AppColors.warning;
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
