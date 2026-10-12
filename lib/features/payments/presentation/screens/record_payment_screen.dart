import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../domain/payment_model.dart';
import '../../data/payment_repository.dart';
import '../../../customers/providers/customer_providers.dart';
import '../../../customers/domain/customer_model.dart';
import '../../providers/payment_providers.dart';
import '../../../invoices/data/invoice_repository.dart';
import '../../../invoices/domain/invoice_model.dart';
import '../../../invoices/providers/invoice_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../customers/data/customer_repository.dart';

class RecordPaymentScreen extends ConsumerStatefulWidget {
  final String? invoiceId;
  final String? invoiceNumber;
  final String? customerId;
  final double? amount;

  const RecordPaymentScreen({
    super.key,
    this.invoiceId,
    this.invoiceNumber,
    this.customerId,
    this.amount,
  });

  @override
  ConsumerState<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends ConsumerState<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  
  CustomerModel? _selectedCustomer;
  String _selectedMethod = 'Cash';
  bool _isLoading = false;

  final List<String> _paymentMethods = ['Cash', 'Bank Transfer', 'UPI', 'Cheque'];

  @override
  void initState() {
    super.initState();
    if (widget.invoiceId != null) {
      _notesController.text = 'Payment for Invoice #${widget.invoiceNumber ?? ''}'; 
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _savePayment() async {
    if (!_formKey.currentState!.validate()) return;
    CustomerModel? finalCustomer = _selectedCustomer;
    if (finalCustomer == null && widget.customerId != null) {
      final customers = ref.read(customersStreamProvider).value ?? [];
      finalCustomer = customers.where((c) => c.id == widget.customerId).firstOrNull;
    }
    
    if (finalCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a customer')));
      return;
    }
    
    setState(() => _isLoading = true);

    try {
      final repository = ref.read(paymentRepositoryProvider);
      final invoiceRepo = ref.read(invoiceRepositoryProvider);
      final customerRepo = ref.read(customerRepositoryProvider);
      
      final now = DateTime.now();
      final enteredAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
      final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();
      
      if (widget.invoiceId != null) {
        // Single invoice payment logic
        final id = const Uuid().v4();
        final payment = PaymentModel(
          id: id,
          invoiceId: widget.invoiceId!,
          customerId: finalCustomer.id,
          amount: enteredAmount,
          paymentDate: now,
          paymentMethod: _selectedMethod,
          notes: notes,
          createdAt: now,
          updatedAt: now,
        );
        
        double paidSoFar = 0.0;
        final payments = ref.read(paymentsStreamProvider).value ?? [];
        paidSoFar = payments
            .where((p) => p.invoiceId == widget.invoiceId)
            .fold(0.0, (sum, p) => sum + p.amount);

        await repository.create(payment, id);
        
        if (widget.amount != null) {
          try {
            final totalPaid = paidSoFar + enteredAmount;
            final currentOutstanding = widget.amount! - totalPaid;
            
            InvoiceStatus newStatus;
            if (currentOutstanding <= 0.01) {
              newStatus = InvoiceStatus.paid;
            } else if (currentOutstanding < widget.amount!) {
              newStatus = InvoiceStatus.partiallyPaid;
            } else {
              newStatus = InvoiceStatus.unpaid;
            }
            
            await invoiceRepo.update(widget.invoiceId!, {'status': newStatus.name});
          } catch (e) {
            debugPrint('Failed to update invoice status: $e');
          }
        }
      } else {
        // Lump sum payment logic
        final invoices = ref.read(invoicesStreamProvider).value ?? [];
        final payments = ref.read(paymentsStreamProvider).value ?? [];
        
        // Find unpaid/partially paid invoices for this customer
        final customerInvoices = invoices.where((i) => 
          i.customerId == finalCustomer!.id && 
          (i.status == InvoiceStatus.unpaid || i.status == InvoiceStatus.partiallyPaid)
        ).toList();
        
        // Sort oldest first
        customerInvoices.sort((a, b) => a.invoiceDate.compareTo(b.invoiceDate));
        
        double remainingAmountToAllocate = enteredAmount;
        
        for (final inv in customerInvoices) {
          if (remainingAmountToAllocate <= 0.01) break;
          
          final invPayments = payments.where((p) => p.invoiceId == inv.id).fold(0.0, (sum, p) => sum + p.amount);
          final invOutstanding = inv.total - invPayments;
          
          if (invOutstanding > 0.01) {
            final amountToAllocate = remainingAmountToAllocate > invOutstanding ? invOutstanding : remainingAmountToAllocate;
            
            final id = const Uuid().v4();
            final payment = PaymentModel(
              id: id,
              invoiceId: inv.id,
              customerId: finalCustomer.id,
              amount: amountToAllocate,
              paymentDate: now,
              paymentMethod: _selectedMethod,
              notes: notes,
              createdAt: now,
              updatedAt: now,
            );
            await repository.create(payment, id);
            
            final totalPaidNow = invPayments + amountToAllocate;
            final currentOutstanding = inv.total - totalPaidNow;
            
            InvoiceStatus newStatus;
            if (currentOutstanding <= 0.01) {
              newStatus = InvoiceStatus.paid;
            } else if (currentOutstanding < inv.total) {
              newStatus = InvoiceStatus.partiallyPaid;
            } else {
              newStatus = InvoiceStatus.unpaid;
            }
            
            await invoiceRepo.update(inv.id, {'status': newStatus.name});
            
            remainingAmountToAllocate -= amountToAllocate;
          }
        }
        
        // If there's still money left over (overpayment or no invoices)
        if (remainingAmountToAllocate > 0.01) {
          final id = const Uuid().v4();
          final payment = PaymentModel(
            id: id,
            invoiceId: 'dummy_invoice_id',
            customerId: finalCustomer.id,
            amount: remainingAmountToAllocate,
            paymentDate: now,
            paymentMethod: _selectedMethod,
            notes: notes != null ? '$notes (Advance/Overpayment)' : 'Advance/Overpayment',
            createdAt: now,
            updatedAt: now,
          );
          await repository.create(payment, id);
        }
      }

      // Update the customer's outstanding balance in Firestore
      final newOutstanding = (finalCustomer.currentOutstanding - enteredAmount).clamp(0.0, double.infinity);
      await customerRepo.update(finalCustomer.id, {'currentOutstanding': newOutstanding});
      
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error recording payment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersStreamProvider);
    final paymentsAsync = ref.watch(paymentsStreamProvider);
    
    double totalInvoiceAmount = widget.amount ?? 0.0;
    double amountPaidTillNow = 0.0;
    
    if (widget.invoiceId != null) {
      final payments = paymentsAsync.value ?? [];
      amountPaidTillNow = payments
          .where((p) => p.invoiceId == widget.invoiceId)
          .fold(0.0, (sum, p) => sum + p.amount);
    }
    
    double outstandingAmount = totalInvoiceAmount - amountPaidTillNow;
    if (outstandingAmount < 0) outstandingAmount = 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Payment'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              customersAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, st) => Text('Error loading customers: $e'),
                data: (customers) {
                    // Try to auto-select if _selectedCustomer is null but we have widget.customerId
                    CustomerModel? initialCustomer = _selectedCustomer;
                    if (initialCustomer == null && widget.customerId != null) {
                      initialCustomer = customers.where((c) => c.id == widget.customerId).firstOrNull;
                    }

                    return DropdownButtonFormField<CustomerModel>(
                      decoration: const InputDecoration(
                        labelText: 'Customer',
                        border: OutlineInputBorder(),
                      ),
                      value: initialCustomer,
                      items: customers.map((c) {
                        return DropdownMenuItem(
                          value: c,
                          child: Text(c.name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedCustomer = val);
                      },
                    validator: (val) => val == null ? 'Required' : null,
                  );
                },
              ),
              const SizedBox(height: 16),
              if (widget.amount != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow('Total Invoice Amount', totalInvoiceAmount, isBold: true),
                      const Divider(),
                      _buildSummaryRow('Amount Paid Till Now', amountPaidTillNow, color: AppColors.success),
                      const Divider(),
                      _buildSummaryRow('Outstanding Amount', outstandingAmount, color: AppColors.error, isBold: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else if (widget.invoiceId == null) ...[
                // Only show dummy invoice selection if not launching from a specific invoice
                const CustomTextField(
                  label: 'Invoice (Optional)',
                  hint: 'Select Invoice',
                  readOnly: true,
                  suffixIcon: Icon(Icons.receipt_long),
                ),
                const SizedBox(height: 16),
              ],
              CustomTextField(
                label: 'Amount Received (₹)',
                hint: '0.00',
                keyboardType: TextInputType.number,
                controller: _amountController,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Required';
                  final amount = double.tryParse(val);
                  if (amount == null || amount <= 0) return 'Enter a valid amount';
                  if (amount > (outstandingAmount + 0.01) && outstandingAmount > 0) {
                    return 'Cannot exceed outstanding amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Payment Method',
                  border: OutlineInputBorder(),
                ),
                value: _selectedMethod,
                items: _paymentMethods.map((method) {
                  return DropdownMenuItem(
                    value: method,
                    child: Text(method),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedMethod = val);
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Reference / Notes',
                hint: 'e.g., Cheque No. or UPI Ref',
                maxLines: 2,
                controller: _notesController,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: (_isLoading || outstandingAmount <= 0.01) ? null : _savePayment,
                style: ElevatedButton.styleFrom(
                  disabledBackgroundColor: AppColors.surfaceVariant,
                  disabledForegroundColor: AppColors.textSecondary,
                ),
                child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Record Payment'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            '₹${amount.toStringAsFixed(2)}', 
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color,
            )
          ),
        ],
      ),
    );
  }
}
