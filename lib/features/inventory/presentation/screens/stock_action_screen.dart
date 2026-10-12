import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../products/providers/product_providers.dart';
import '../../../products/domain/product_model.dart';
import '../../../products/data/product_repository.dart';
import '../../data/inventory_repository.dart';
import '../../domain/inventory_transaction_model.dart';

class StockActionScreen extends ConsumerStatefulWidget {
  final String actionType; // 'in' or 'out'

  const StockActionScreen({super.key, required this.actionType});

  @override
  ConsumerState<StockActionScreen> createState() => _StockActionScreenState();
}

class _StockActionScreenState extends ConsumerState<StockActionScreen> {
  String? _selectedProductId;
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  String get _title =>
      widget.actionType == 'in' ? 'Stock In' : 'Stock Out';

  Color get _accentColor =>
      widget.actionType == 'in' ? AppColors.success : AppColors.error;

  IconData get _actionIcon =>
      widget.actionType == 'in' ? Icons.add_circle_outline : Icons.remove_circle_outline;

  @override
  void dispose() {
    _quantityController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a product')),
      );
      return;
    }
    
    final currentProducts = ref.read(productsStreamProvider).value ?? [];
    final selectedProduct = currentProducts.where((p) => p.id == _selectedProductId).firstOrNull;
    
    if (selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected product not found')),
      );
      return;
    }

    final qty = double.tryParse(_quantityController.text.trim()) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity must be greater than 0')),
      );
      return;
    }

    if (widget.actionType == 'out' && qty > selectedProduct.currentStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Not enough stock. Current stock: ${selectedProduct.currentStock}'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final productRepo = ref.read(productRepositoryProvider);
      final inventoryRepo = ref.read(inventoryRepositoryProvider);

      final previousStock = selectedProduct.currentStock;
      final newStock = widget.actionType == 'in'
          ? previousStock + qty
          : previousStock - qty;

      // 1. Update product stock in Firestore
      await productRepo.update(selectedProduct.id, {
        'currentStock': newStock,
      });

      // 2. Log inventory transaction
      final txnId = const Uuid().v4();
      final now = DateTime.now();
      final transaction = InventoryTransactionModel(
        id: txnId,
        productId: selectedProduct.id,
        type: widget.actionType == 'in'
            ? TransactionType.stockIn
            : TransactionType.stockOut,
        quantity: qty,
        previousStock: previousStock,
        newStock: newStock,
        remarks: _remarksController.text.trim().isNotEmpty
            ? _remarksController.text.trim()
            : null,
        createdAt: now,
        updatedAt: now,
      );
      await inventoryRepo.create(transaction, txnId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$_title recorded successfully!'),
            backgroundColor: _accentColor,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Gradient Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.actionType == 'in'
                        ? [const Color(0xFF2E7D32), const Color(0xFF66BB6A)]
                        : [const Color(0xFFC62828), const Color(0xFFEF5350)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _accentColor.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_actionIcon, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.actionType == 'in'
                                ? 'Add received goods to stock'
                                : 'Remove damaged/lost items',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Inputs Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product dropdown
                    const Text('Select Product', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    productsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Text('Error: $e'),
                      data: (products) {
                        final currentSelectedProduct = products.where((p) => p.id == _selectedProductId).firstOrNull;
                        
                        return DropdownButtonFormField<ProductModel>(
                          value: currentSelectedProduct,
                          isExpanded: true,
                          icon: const Icon(Icons.unfold_more_rounded, color: AppColors.textSecondary),
                          decoration: InputDecoration(
                            hintText: 'Tap to select a product',
                            hintStyle: const TextStyle(color: AppColors.textSecondary),
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          items: products.map((p) => DropdownMenuItem(
                            value: p,
                            child: Row(
                              children: [
                                Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('Qty: ${p.currentStock}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                ),
                              ],
                            ),
                          )).toList(),
                          onChanged: (val) => setState(() => _selectedProductId = val?.id),
                          validator: (val) => val == null ? 'Please select a product' : null,
                        );
                      },
                    ),

                    if (_selectedProductId != null) ...[
                      const SizedBox(height: 24),
                      // Quantity
                      const Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _quantityController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: '0.0',
                          hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5)),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          suffixIcon: Container(
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: _accentColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.numbers_rounded, color: _accentColor, size: 20),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Quantity is required';
                          if (double.tryParse(val) == null) return 'Enter a valid number';
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                    ],

                    const SizedBox(height: 24),
                    // Remarks
                    const Text('Remarks (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _remarksController,
                      maxLines: 3,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Add notes here...',
                        hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5)),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: _accentColor.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_actionIcon, size: 22),
                            const SizedBox(width: 10),
                            Text(
                              'Save $_title',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
