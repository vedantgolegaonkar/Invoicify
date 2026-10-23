import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../domain/invoice_model.dart';
import '../../data/invoice_repository.dart';
import '../../../customers/providers/customer_providers.dart';
import '../../../customers/domain/customer_model.dart';
import '../../../customers/data/customer_repository.dart';
import '../../providers/invoice_providers.dart';
import '../../../settings/data/settings_repository.dart';
import '../../../products/data/product_repository.dart';
import '../../../inventory/data/inventory_repository.dart';
import '../../../inventory/domain/inventory_transaction_model.dart';
import '../../../settings/domain/settings_model.dart';
import '../../../products/domain/product_model.dart';
import '../../../products/providers/product_providers.dart';
import '../../../settings/providers/business_providers.dart';
import '../../../../core/theme/app_colors.dart';

class CreateInvoiceScreen extends ConsumerStatefulWidget {
  final String? invoiceId;

  const CreateInvoiceScreen({super.key, this.invoiceId});

  @override
  ConsumerState<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends ConsumerState<CreateInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _paymentTermsController = TextEditingController(text: '30 Days');
  final _buyerOrderNoController = TextEditingController();
  final _destinationController = TextEditingController();
  final _termsOfDeliveryController = TextEditingController();
  final _referenceNoController = TextEditingController();
  DateTime? _buyerOrderDate;
  
  String? _selectedCustomerId;
  final List<InvoiceItem> _items = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.invoiceId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadInvoice();
      });
    }
  }

  Future<void> _loadInvoice() async {
    setState(() => _isLoading = true);
    try {
      final invoices = await ref.read(invoicesStreamProvider.future);
      final invoice = invoices.firstWhere((i) => i.id == widget.invoiceId);

      if (mounted) {
        setState(() {
          _selectedCustomerId = invoice.customerId;
          _items.addAll(invoice.items);
          _notesController.text = invoice.notes ?? '';
          _paymentTermsController.text = invoice.paymentTerms ?? '';
          _buyerOrderNoController.text = invoice.buyerOrderNo ?? '';
          _buyerOrderDate = invoice.buyerOrderDate;
          _destinationController.text = invoice.destination ?? '';
          _termsOfDeliveryController.text = invoice.termsOfDelivery ?? '';
          _referenceNoController.text = invoice.referenceNoAndDate ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading invoice: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _paymentTermsController.dispose();
    _buyerOrderNoController.dispose();
    _destinationController.dispose();
    _termsOfDeliveryController.dispose();
    _referenceNoController.dispose();
    super.dispose();
  }

  double get _subtotal => _items.fold(0, (sum, item) => sum + item.subtotal);
  double get _gst => _items.fold(0, (sum, item) => sum + item.gstAmount);
  double get _total => _items.fold(0, (sum, item) => sum + item.total);

  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomerId == null) {
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
      final business = ref.read(primaryBusinessProvider);
      
      final now = DateTime.now();
      final id = widget.invoiceId ?? const Uuid().v4();
      
      String invoiceNumber = '';
      SettingsModel? settings;
      
      if (widget.invoiceId != null) {
        // We don't generate a new number on edit, we just use the existing one when updating
      } else {
        final monthStr = DateFormat('MMM').format(now).toUpperCase(); // e.g. OCT, NOV
        try {
          final settingsList = await settingsRepo.getAll();
          settings = settingsList.isNotEmpty ? settingsList.first : null;
          final nextNum = settings?.invoiceNextNumber ?? 1;
          invoiceNumber = 'INV-$monthStr-${nextNum.toString().padLeft(3, '0')}';
        } catch (e) {
          debugPrint('Error calculating invoice number: $e');
          invoiceNumber = 'INV-$monthStr-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
        }
      }

      final invoice = InvoiceModel(
        id: id,
        customerId: _selectedCustomerId!,
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
        paymentTerms: _paymentTermsController.text.trim().isEmpty ? null : _paymentTermsController.text.trim(),
        buyerOrderNo: _buyerOrderNoController.text.trim().isEmpty ? null : _buyerOrderNoController.text.trim(),
        buyerOrderDate: _buyerOrderDate,
        destination: _destinationController.text.trim().isEmpty ? null : _destinationController.text.trim(),
        termsOfDelivery: _termsOfDeliveryController.text.trim().isEmpty ? null : _termsOfDeliveryController.text.trim(),
        referenceNoAndDate: _referenceNoController.text.trim().isEmpty ? null : _referenceNoController.text.trim(),
        createdAt: now,
        updatedAt: now,
      );

      if (widget.invoiceId == null) {
        await repository.create(invoice, id);
        
        if (settings != null) {
          try {
            await settingsRepo.update('default', {'invoiceNextNumber': settings.invoiceNextNumber + 1});
          } catch (e) {
            debugPrint('Error updating next invoice number: $e');
          }
        }
        
        try {
          final currentCust = await customerRepo.getById(_selectedCustomerId!);
          if (currentCust != null) {
            final newOutstanding = currentCust.currentOutstanding + _total;
            await customerRepo.update(_selectedCustomerId!, {'currentOutstanding': newOutstanding});
          }
        } catch (e) {
          debugPrint('Error updating customer outstanding: $e');
        }
        
        if (invoice.orderId == 'dummy_order_id') {
          try {
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
                  await productRepo.update(pId, {'currentStock': newStock});
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
                  await inventoryRepo.create(transaction, txnId);
                } catch (e) {
                  debugPrint('Error updating inventory item $pId: $e');
                }
              }
            }
          } catch (e) {
            debugPrint('Error in inventory sync: $e');
          }
        }
      } else {
        final oldInvoice = (ref.read(invoicesStreamProvider).value ?? []).firstWhere(
          (i) => i.id == widget.invoiceId,
          orElse: () => invoice,
        );
        final invoiceMap = invoice.toMap();
        invoiceMap['invoiceNumber'] = oldInvoice.invoiceNumber;
        await repository.update(id, invoiceMap);
        
        try {
          final currentCust = await customerRepo.getById(_selectedCustomerId!);
          if (currentCust != null) {
            final diff = _total - oldInvoice.total;
            final newOutstanding = (currentCust.currentOutstanding + diff).clamp(0.0, double.infinity);
            await customerRepo.update(_selectedCustomerId!, {'currentOutstanding': newOutstanding});
          }
        } catch (e) {
          debugPrint('Error updating customer outstanding on edit: $e');
        }
        
        if (invoice.orderId == 'dummy_order_id') {
          try {
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
                    await productRepo.update(pId, {'currentStock': newStock});
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
                    await inventoryRepo.create(transaction, txnId);
                  } catch (e) {
                    debugPrint('Error updating inventory for item $pId on edit: $e');
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('Error in inventory sync on edit: $e');
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

  void _showAddItemDialog() {
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer first to load pricing.')),
      );
      return;
    }

    final customers = ref.read(customersStreamProvider).value ?? [];
    final customer = customers.where((c) => c.id == _selectedCustomerId).firstOrNull;

    if (customer == null || customer.productPrices == null || customer.productPrices!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please configure product prices for this customer first.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            final productsAsync = ref.watch(productsStreamProvider);
            return productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => Center(child: Text('Error: $err')),
              data: (allProducts) {
                final products = allProducts.where((p) => p.isActive).toList();
                if (products.isEmpty) {
                  return const Center(child: Text('No products available. Please add products first.'));
                }
                return Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Select Product', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final p = products[index];
                          final price = customer.productPrices?[p.id] ?? 0.0;
                          return ListTile(
                            title: Text(p.name),
                            subtitle: Text(p.currentStock > 0 
                                ? 'Stock: ${p.currentStock} | ₹${price.toStringAsFixed(2)}'
                                : '₹${price.toStringAsFixed(2)}'),
                            onTap: () {
                              if (price <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please add the rate for this product'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }
                              Navigator.pop(context);
                              _addProduct(p, customer);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _addProduct(ProductModel product, CustomerModel customer) {
    final price = customer.productPrices?[product.id] ?? 0.0;
    if (price <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add the rate for this product'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final existingIndex = _items.indexWhere((i) => i.productId == product.id);
    if (existingIndex >= 0) {
      final item = _items[existingIndex];
      _updateItemQuantity(existingIndex, item.quantity + 1);
    } else {
      final qty = 1.0;
      final subtotal = price * qty;
      final gstAmount = (subtotal * (product.cgst + product.sgst) / 100) + (product.igst * qty);

      setState(() {
        _items.add(
          InvoiceItem(
            productId: product.id,
            productName: product.name,
            hsnCode: product.hsnCode,
            quantity: qty,
            unitPrice: price,
            subtotal: subtotal,
            gstAmount: gstAmount,
            total: subtotal + gstAmount,
          ),
        );
      });
    }
  }

  void _updateItemQuantity(int index, double newQty) {
    if (newQty <= 0) {
      setState(() => _items.removeAt(index));
      return;
    }

    final item = _items[index];
    final subtotal = item.unitPrice * newQty;
    final unitGst = item.quantity > 0 ? (item.gstAmount / item.quantity) : 0.0;
    final newGstAmount = unitGst * newQty;

    setState(() {
      _items[index] = InvoiceItem(
        productId: item.productId,
        productName: item.productName,
        hsnCode: item.hsnCode,
        quantity: newQty,
        unitPrice: item.unitPrice,
        subtotal: subtotal,
        gstAmount: newGstAmount,
        total: subtotal + newGstAmount,
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
                  final activeCustomers = customers.where((c) => !c.isDeleted).toList();
                  final hasSelectedCustomer = activeCustomers.any((c) => c.id == _selectedCustomerId);

                  return DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Customer',
                      border: OutlineInputBorder(),
                    ),
                    value: hasSelectedCustomer ? _selectedCustomerId : null,
                    items: activeCustomers.map((c) {
                      return DropdownMenuItem<String>(
                        value: c.id,
                        child: Text(c.name),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedCustomerId = val;
                      });
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
                    onPressed: _showAddItemDialog,
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
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName, 
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${item.unitPrice} / unit', 
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.blue),
                                onPressed: () => _updateItemQuantity(index, item.quantity - 1),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                child: Text(
                                  '${item.quantity.toInt()}', 
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                                onPressed: () => _updateItemQuantity(index, item.quantity + 1),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '₹${item.subtotal.toStringAsFixed(2)}', 
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 4),
                              InkWell(
                                onTap: () => setState(() => _items.removeAt(index)),
                                child: const Icon(Icons.delete, color: Colors.red, size: 20),
                              ),
                            ],
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
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 1.0),
                ),
                clipBehavior: Clip.antiAlias,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.local_shipping_outlined, color: AppColors.primary, size: 22),
                    ),
                    title: const Text(
                      'Dispatch & Order References',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'PO No, Payment terms, destination & delivery terms',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    children: [
                      CustomTextField(
                        label: 'Mode / Terms of Payment',
                        hint: 'e.g. 30 Days',
                        controller: _paymentTermsController,
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: CustomTextField(
                              label: "Buyer's Order / PO No.",
                              hint: 'e.g. PO-2024-001',
                              controller: _buyerOrderNoController,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _buyerOrderDate ?? DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2035),
                                  );
                                  if (picked != null) {
                                    setState(() => _buyerOrderDate = picked);
                                  }
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Order / PO Date',
                                    border: OutlineInputBorder(),
                                    suffixIcon: Icon(Icons.calendar_today, size: 18),
                                  ),
                                  child: Text(
                                    _buyerOrderDate != null
                                        ? '${_buyerOrderDate!.day.toString().padLeft(2, '0')}-${_buyerOrderDate!.month.toString().padLeft(2, '0')}-${_buyerOrderDate!.year}'
                                        : 'Select Date',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _buyerOrderDate != null ? null : Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      CustomTextField(
                        label: 'Destination',
                        hint: 'e.g. Pune, MH',
                        controller: _destinationController,
                      ),
                      CustomTextField(
                        label: 'Terms of Delivery',
                        hint: 'e.g. Ex-Works / By Transport',
                        controller: _termsOfDeliveryController,
                      ),
                      CustomTextField(
                        label: 'Reference No. & Date',
                        hint: 'Optional reference',
                        controller: _referenceNoController,
                      ),
                    ],
                  ),
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
