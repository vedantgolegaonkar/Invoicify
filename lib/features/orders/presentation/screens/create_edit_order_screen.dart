import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../domain/order_model.dart';
import '../../data/order_repository.dart';
import '../../../customers/providers/customer_providers.dart';
import '../../../customers/domain/customer_model.dart';
import '../../../products/providers/product_providers.dart';
import '../../../products/domain/product_model.dart';
import '../../providers/order_providers.dart';
import '../../../invoices/providers/invoice_providers.dart';
import '../../../invoices/domain/invoice_model.dart';
import '../../../invoices/data/invoice_repository.dart';
import '../../../settings/data/settings_repository.dart';
import '../../../settings/domain/settings_model.dart';
import '../../../inventory/data/inventory_repository.dart';
import '../../../inventory/domain/inventory_transaction_model.dart';
import '../../../products/data/product_repository.dart';
import '../../../../services/notification_service.dart';
class CreateEditOrderScreen extends ConsumerStatefulWidget {
  final String? orderId;

  const CreateEditOrderScreen({super.key, this.orderId});

  @override
  ConsumerState<CreateEditOrderScreen> createState() => _CreateEditOrderScreenState();
}

class _CreateEditOrderScreenState extends ConsumerState<CreateEditOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  
  CustomerModel? _selectedCustomer;
  final List<OrderItem> _items = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.orderId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadOrder();
      });
    }
  }

  Future<void> _loadOrder() async {
    setState(() => _isLoading = true);
    try {
      final orders = await ref.read(ordersStreamProvider.future);
      final order = orders.firstWhere((o) => o.id == widget.orderId);
      
      final customers = await ref.read(customersStreamProvider.future);
      final customerMatches = customers.where((c) => c.id == order.customerId).toList();

      if (mounted) {
        setState(() {
          _selectedCustomer = customerMatches.isNotEmpty ? customerMatches.first : null;
          _items.addAll(order.items);
          _notesController.text = order.notes ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading order: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  double get _subtotal => _items.fold(0, (sum, item) => sum + item.subtotal);
  double get _gst => _items.fold(0, (sum, item) => sum + item.gstAmount);
  double get _total => _items.fold(0, (sum, item) => sum + item.total);

  Future<void> _saveOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a customer')));
      return;
    }
    if (_selectedCustomer!.productPrices == null || _selectedCustomer!.productPrices!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please configure product prices for this customer before creating an order')));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one item')));
      return;
    }
    
    setState(() => _isLoading = true);

    try {
      final repository = ref.read(orderRepositoryProvider);
      
      final now = DateTime.now();
      final id = widget.orderId ?? const Uuid().v4();
      
      if (widget.orderId != null) {
        List<OrderModel> existingOrders = ref.read(ordersStreamProvider).value ?? [];
        if (existingOrders.isEmpty) {
          try {
            existingOrders = await repository.getAll().timeout(const Duration(seconds: 2));
          } catch (e) {
            debugPrint('Error fetching existing orders for update: $e');
          }
        }
        
        OrderModel? existingOrder;
        try {
          existingOrder = existingOrders.firstWhere((o) => o.id == widget.orderId);
        } catch (_) {}
        
        if (existingOrder == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order not found')));
            setState(() => _isLoading = false);
          }
          return;
        }
        
        final order = existingOrder.copyWith(
          customerId: _selectedCustomer!.id,
          items: _items,
          subtotal: _subtotal,
          gst: _gst,
          total: _total,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          updatedAt: now,
        );
        
        // Workaround for copyWith nullable issues:
        final orderMap = order.toMap();
        if (_notesController.text.trim().isEmpty) orderMap['notes'] = null;

        final orderUpdateFuture = repository.update(id, orderMap);
        
        // Calculate inventory delta
        final productRepo = ref.read(productRepositoryProvider);
        final inventoryRepo = ref.read(inventoryRepositoryProvider);
        final currentProducts = await productRepo.getAll();
          
          Map<String, double> oldQuantities = {};
          for (var item in existingOrder.items) {
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
                    remarks: 'Order Updated: ${existingOrder.orderNumber}',
                    createdAt: now,
                    updatedAt: now,
                  );
                  inventoryRepo.create(transaction, txnId);
                  
                  if (product.minimumStock > 0 && newStock <= product.minimumStock) {
                    NotificationService().showLowStockNotification(
                      productId: pId,
                      productName: product.name,
                      currentStock: newStock,
                    );
                  }
                } catch (e) {
                  debugPrint('Error updating inventory: $e');
                }
              }
            }
          }

        try {
          await orderUpdateFuture.timeout(const Duration(seconds: 2));
        } catch (e) {
          debugPrint('Order update sync delayed: $e');
        }

        // Update corresponding invoice
        try {
          List<InvoiceModel> existingInvoices = ref.read(invoicesStreamProvider).value ?? [];
          if (existingInvoices.isEmpty) {
            try {
              final invoiceRepo = ref.read(invoiceRepositoryProvider);
              existingInvoices = await invoiceRepo.getAll().timeout(const Duration(seconds: 2));
            } catch (e) {
              debugPrint('Error fetching existing invoices for update: $e');
            }
          }
          final correspondingInvoices = existingInvoices.where((inv) => inv.orderId == widget.orderId).toList();
          
          if (correspondingInvoices.isNotEmpty) {
            final invoiceRepo = ref.read(invoiceRepositoryProvider);
            final invoiceToUpdate = correspondingInvoices.first;
            
            final invoiceItems = _items.map((i) => InvoiceItem(
              productId: i.productId,
              productName: i.productName,
              hsnCode: i.hsnCode,
              quantity: i.quantity,
              unitPrice: i.unitPrice,
              subtotal: i.subtotal,
              gstAmount: i.gstAmount,
              total: i.total,
            )).toList();
            
            final updatedInvoice = invoiceToUpdate.copyWith(
              customerId: _selectedCustomer!.id,
              items: invoiceItems,
              subtotal: _subtotal,
              gst: _gst,
              total: _total,
              updatedAt: now,
              notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            );
            
            final invoiceMap = updatedInvoice.toMap();
            if (_notesController.text.trim().isEmpty) invoiceMap['notes'] = null;
            
            try {
              await invoiceRepo.update(invoiceToUpdate.id, invoiceMap).timeout(const Duration(seconds: 2));
            } catch (e) {
              debugPrint('Invoice update sync delayed: $e');
            }
          }
        } catch (e) {
          debugPrint('Error updating corresponding invoice: $e');
        }
      } else {
        List<OrderModel> existingOrders = ref.read(ordersStreamProvider).value ?? [];
        if (existingOrders.isEmpty) {
          try {
            existingOrders = await repository.getAll().timeout(const Duration(seconds: 2));
          } catch (e) {
            debugPrint('Error fetching existing orders: $e');
          }
        }
        
        String orderNumber = 'ORD-0001';
        if (existingOrders.isNotEmpty) {
          int maxNumber = 0;
          for (var o in existingOrders) {
            final numberPart = o.orderNumber.replaceAll(RegExp(r'[^0-9]'), '');
            if (numberPart.isNotEmpty) {
              final number = int.tryParse(numberPart);
              if (number != null && number > maxNumber) {
                maxNumber = number;
              }
            }
          }
          final nextNumber = maxNumber + 1;
          orderNumber = 'ORD-${nextNumber.toString().padLeft(4, '0')}';
        }

        final order = OrderModel(
          id: id,
          customerId: _selectedCustomer!.id,
          orderNumber: orderNumber,
          orderDate: now,
          status: OrderStatus.draft,
          items: _items,
          subtotal: _subtotal,
          gst: _gst,
          total: _total,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          createdAt: now,
          updatedAt: now,
        );
        
        final orderCreateFuture = repository.create(order, id);
        
        // Deduct inventory
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
                  remarks: 'Order Created: $orderNumber',
                  createdAt: now,
                  updatedAt: now,
                );
                inventoryRepo.create(transaction, txnId);
                
                if (product.minimumStock > 0 && newStock <= product.minimumStock) {
                  NotificationService().showLowStockNotification(
                    productId: pId,
                    productName: product.name,
                    currentStock: newStock,
                  );
                }
              } catch (e) {
                debugPrint('Error updating inventory: $e');
              }
            }
          }
          
        try {
          await orderCreateFuture.timeout(const Duration(seconds: 2));
        } catch (e) {
          // Timeout exception or other errors. The write is already queued locally.
          debugPrint('Order create sync delayed: $e');
        }

        // Auto-generate invoice
        try {
          final invoiceRepo = ref.read(invoiceRepositoryProvider);
          
          String invNumber = '';
          SettingsModel? settings;
          try {
            final settingsList = await ref.read(settingsRepositoryProvider).getAll();
            settings = settingsList.isNotEmpty ? settingsList.first : null;
            final prefix = settings?.invoicePrefix ?? 'INV-';
            final nextNum = settings?.invoiceNextNumber ?? 1;
            invNumber = '$prefix${nextNum.toString().padLeft(3, '0')}';
          } catch (e) {
            debugPrint('Error calculating invoice number: $e');
            invNumber = 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
          }

          final invoiceItems = _items.map((i) => InvoiceItem(
            productId: i.productId,
            productName: i.productName,
            hsnCode: i.hsnCode,
            quantity: i.quantity,
            unitPrice: i.unitPrice,
            subtotal: i.subtotal,
            gstAmount: i.gstAmount,
            total: i.total,
          )).toList();

          final invoiceId = const Uuid().v4();
          final invoice = InvoiceModel(
            id: invoiceId,
            customerId: _selectedCustomer!.id,
            orderId: id,
            invoiceNumber: invNumber,
            invoiceDate: now,
            items: invoiceItems,
            subtotal: _subtotal,
            gst: _gst,
            total: _total,
            status: InvoiceStatus.unpaid,
            isDelivered: false,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            createdAt: now,
            updatedAt: now,
          );
          
          try {
            await invoiceRepo.create(invoice, invoiceId).timeout(const Duration(seconds: 2));
            if (settings != null) {
              await ref.read(settingsRepositoryProvider).update('default', {'invoiceNextNumber': settings.invoiceNextNumber + 1});
            }
          } catch (e) {
            debugPrint('Invoice create sync delayed: $e');
          }
        } catch (e) {
          debugPrint('Error auto-generating invoice: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error auto-generating invoice: $e')));
          }
        }
      }
      
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving order: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddItemDialog() {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a customer first to load pricing.')));
      return;
    }
    
    if (_selectedCustomer!.productPrices == null || _selectedCustomer!.productPrices!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please configure product prices for this customer first.')));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
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
                          return ListTile(
                            title: Text(p.name),
                            subtitle: Text(p.currentStock > 0 
                                ? 'Stock: ${p.currentStock} | ₹${(_selectedCustomer!.productPrices?[p.id] ?? 0.0).toStringAsFixed(2)}'
                                : '₹${(_selectedCustomer!.productPrices?[p.id] ?? 0.0).toStringAsFixed(2)}'),
                            onTap: () {
                              Navigator.pop(context);
                              _addProduct(p);
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

  void _addProduct(ProductModel product) {
    final existingIndex = _items.indexWhere((i) => i.productId == product.id);
    if (existingIndex >= 0) {
      final item = _items[existingIndex];
      _updateItemQuantity(existingIndex, item.quantity + 1);
    } else {
      final qty = 1.0;
      final price = _selectedCustomer!.productPrices?[product.id] ?? 0.0;
      final subtotal = price * qty;
      final gstAmount = (subtotal * (product.cgst + product.sgst) / 100) + (product.igst * qty);
      
      setState(() {
        _items.add(
          OrderItem(
            productId: product.id,
            productName: product.name,
            hsnCode: product.hsnCode,
            quantity: qty,
            unitPrice: price,
            subtotal: subtotal,
            gstAmount: gstAmount,
            total: subtotal + gstAmount,
          )
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
    
    final unitGst = item.gstAmount / item.quantity;
    final newGstAmount = unitGst * newQty;
    
    setState(() {
      _items[index] = OrderItem(
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
    final isEditing = widget.orderId != null;
    final customersAsync = ref.watch(customersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Order' : 'Create Order'),
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
                  final matchedCustomer = activeCustomers.where((c) => c.id == _selectedCustomer?.id).firstOrNull;

                  return DropdownButtonFormField<CustomerModel>(
                    decoration: const InputDecoration(
                      labelText: 'Customer',
                      border: OutlineInputBorder(),
                    ),
                    value: matchedCustomer,
                    items: activeCustomers.map((c) {
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
                  Text('Order Items', style: Theme.of(context).textTheme.titleMedium),
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
                                Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('₹${item.unitPrice} / unit', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.blue),
                                onPressed: () => _updateItemQuantity(index, item.quantity - 1),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text('${item.quantity.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                                onPressed: () => _updateItemQuantity(index, item.quantity + 1),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('₹${item.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
              CustomTextField(
                label: 'Notes',
                hint: 'Optional notes',
                maxLines: 3,
                controller: _notesController,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveOrder,
                child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isEditing ? 'Update Order' : 'Save Order'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
