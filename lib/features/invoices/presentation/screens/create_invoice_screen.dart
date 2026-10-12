import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../domain/invoice_model.dart';
import '../../data/invoice_repository.dart';
import '../../../customers/providers/customer_providers.dart';
import '../../../customers/domain/customer_model.dart';
import '../../../customers/data/customer_repository.dart';
import '../../providers/invoice_providers.dart';
import '../../../settings/providers/settings_providers.dart';
import '../../../settings/data/settings_repository.dart';
import '../../../products/providers/product_providers.dart';
import '../../../products/data/product_repository.dart';
import '../../../inventory/data/inventory_repository.dart';
import '../../../inventory/domain/inventory_transaction_model.dart';
import '../../../settings/domain/settings_model.dart';

class CreateInvoiceScreen extends ConsumerStatefulWidget {
  final String? invoiceId;

  const CreateInvoiceScreen({super.key, this.invoiceId});

  @override
  ConsumerState<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends ConsumerState<CreateInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  
  CustomerModel? _selectedCustomer;
  final List<InvoiceItem> _items = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  double get _subtotal => _items.fold(0, (sum, item) => sum + item.subtotal);
  double get _gst => _items.fold(0, (sum, item) => sum + item.gstAmount);
  double get _total => _items.fold(0, (sum, item) => sum + item.total);

  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a customer')));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one item')));
      return;
    }
    
    setState(() => _isLoading = true);

    try {
      final repository = ref.read(invoiceRepositoryProvider);
      final customerRepo = ref.read(customerRepositoryProvider);
      final settingsRepo = ref.read(settingsRepositoryProvider);
      
      final now = DateTime.now();
      final id = widget.invoiceId ?? const Uuid().v4();
      
      String invoiceNumber = '';
      SettingsModel? settings;
      
      if (widget.invoiceId != null) {
        // We don't generate a new number on edit, we just use the existing one when updating
      } else {
        try {
          final settingsList = await settingsRepo.getAll();
          settings = settingsList.isNotEmpty ? settingsList.first : null;
          final prefix = settings?.invoicePrefix ?? 'INV-';
          final nextNum = settings?.invoiceNextNumber ?? 1;
          invoiceNumber = '$prefix${nextNum.toString().padLeft(3, '0')}';
        } catch (e) {
          debugPrint('Error calculating invoice number: $e');
          invoiceNumber = 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
        }
      }
      
      final invoice = InvoiceModel(
        id: id,
        customerId: _selectedCustomer!.id,
        orderId: 'dummy_order_id', // Would normally come from converting an order
        invoiceNumber: widget.invoiceId != null ? 'existing' : invoiceNumber, // Will be overridden correctly below
        invoiceDate: now,
        items: _items,
        subtotal: _subtotal,
        gst: _gst,
        total: _total,
        status: InvoiceStatus.unpaid,
        isDelivered: false,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: now,
        updatedAt: now,
      );

      if (widget.invoiceId == null) {
        await repository.create(invoice, id);
        if (settings != null) {
          await settingsRepo.update('default', {'invoiceNextNumber': settings.invoiceNextNumber + 1});
        }
        final newOutstanding = _selectedCustomer!.currentOutstanding + _total;
        await customerRepo.update(_selectedCustomer!.id, {'currentOutstanding': newOutstanding});
        
        if (invoice.orderId == 'dummy_order_id') {
          final productRepo = ref.read(productRepositoryProvider);
          final inventoryRepo = ref.read(inventoryRepositoryProvider);
          final currentProducts = await productRepo.getAll();

          Map<String, double> newQuantities = {};
          for (var item in _items) {
            newQuantities[item.productId] = (newQuantities[item.productId] ?? 0) + item.quantity;
          }
          
          for (var entry in newQuantities.entries) {
            final pId = entry.key;
            final qty = entry.value;
            
            final productMatches = currentProducts.where((p) => p.id == pId);
            if (productMatches.isNotEmpty) {
              final product = productMatches.first;
              final previousStock = product.currentStock;
              final newStock = previousStock - qty;
              
              try {
                productRepo.update(pId, {'currentStock': newStock});
                final txnId = const Uuid().v4();
                final transaction = InventoryTransactionModel(
                  id: txnId,
                  productId: pId,
                  type: TransactionType.stockOut,
                  quantity: qty,
                  previousStock: previousStock,
                  newStock: newStock,
                  remarks: 'Invoice Created: $invoiceNumber',
                  createdAt: now,
                  updatedAt: now,
                );
                inventoryRepo.create(transaction, txnId);
              } catch (e) {
                debugPrint('Error updating inventory: $e');
              }
            }
          }
        }
      } else {
        final oldInvoice = (ref.read(invoicesStreamProvider).value ?? []).firstWhere(
          (i) => i.id == widget.invoiceId,
          orElse: () => invoice, // Fallback if not found for some reason
        );
        final invoiceMap = invoice.toMap();
        invoiceMap['invoiceNumber'] = oldInvoice.invoiceNumber;
        await repository.update(id, invoiceMap);
        final diff = _total - oldInvoice.total;
        final newOutstanding = (_selectedCustomer!.currentOutstanding + diff).clamp(0.0, double.infinity);
        await customerRepo.update(_selectedCustomer!.id, {'currentOutstanding': newOutstanding});
        
        if (invoice.orderId == 'dummy_order_id') {
          final productRepo = ref.read(productRepositoryProvider);
          final inventoryRepo = ref.read(inventoryRepositoryProvider);
          final currentProducts = await productRepo.getAll();
          
          Map<String, double> oldQuantities = {};
          for (var item in oldInvoice.items) {
            oldQuantities[item.productId] = (oldQuantities[item.productId] ?? 0) + item.quantity;
          }
          
          Map<String, double> newQuantities = {};
          for (var item in _items) {
            newQuantities[item.productId] = (newQuantities[item.productId] ?? 0) + item.quantity;
          }

          final allProductIds = {...oldQuantities.keys, ...newQuantities.keys};

          for (var pId in allProductIds) {
            final oldQ = oldQuantities[pId] ?? 0;
            final newQ = newQuantities[pId] ?? 0;
            final delta = newQ - oldQ;
            
            if (delta != 0) {
              final productMatches = currentProducts.where((p) => p.id == pId);
              if (productMatches.isNotEmpty) {
                final product = productMatches.first;
                final previousStock = product.currentStock;
                final newStock = previousStock - delta;
                
                try {
                  productRepo.update(pId, {'currentStock': newStock});
                  final txnId = const Uuid().v4();
                  final transaction = InventoryTransactionModel(
                    id: txnId,
                    productId: pId,
                    type: delta > 0 ? TransactionType.stockOut : TransactionType.stockIn,
                    quantity: delta.abs(),
                    previousStock: previousStock,
                    newStock: newStock,
                    remarks: 'Invoice Updated: ${oldInvoice.invoiceNumber}',
                    createdAt: now,
                    updatedAt: now,
                  );
                  inventoryRepo.create(transaction, txnId);
                } catch (e) {
                  debugPrint('Error updating inventory: $e');
                }
              }
            }
          }
        }
      }
      
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving invoice: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _addDummyItem() {
    setState(() {
      _items.add(
        InvoiceItem(
          productId: 'dummy_prod',
          productName: 'Custom Item',
          hsnCode: '1234',
          quantity: 1,
          unitPrice: 100,
          subtotal: 100,
          gstAmount: 18,
          total: 118,
        )
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.invoiceId != null;
    final customersAsync = ref.watch(customersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Invoice' : 'Create Invoice'),
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
                  return DropdownButtonFormField<CustomerModel>(
                    decoration: const InputDecoration(
                      labelText: 'Customer',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedCustomer,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Invoice Items', style: Theme.of(context).textTheme.titleMedium),
                  TextButton.icon(
                    onPressed: _addDummyItem,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Item'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No items added', textAlign: TextAlign.center),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return ListTile(
                      title: Text(item.productName),
                      subtitle: Text('${item.quantity} x ₹${item.unitPrice}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('₹${item.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() => _items.removeAt(index));
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('₹${_total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Notes',
                hint: 'Optional notes',
                maxLines: 3,
                controller: _notesController,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveInvoice,
                child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isEditing ? 'Update Invoice' : 'Save Invoice'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
