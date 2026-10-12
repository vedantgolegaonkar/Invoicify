import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../domain/product_model.dart';
import '../../data/product_repository.dart';
import '../../providers/product_providers.dart';

class AddEditProductScreen extends ConsumerStatefulWidget {
  final String? productId;

  const AddEditProductScreen({super.key, this.productId});

  @override
  ConsumerState<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends ConsumerState<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hsnCodeController = TextEditingController();
  final _cgstController = TextEditingController(text: '2.5');
  final _sgstController = TextEditingController(text: '2.5');
  final _igstController = TextEditingController(text: '1.46');
  final _currentStockController = TextEditingController();
  final _minimumStockController = TextEditingController();
  
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cgstController.addListener(_calculateIgst);
    _sgstController.addListener(_calculateIgst);

    if (widget.productId != null) {
      final products = ref.read(productsStreamProvider).value;
      if (products != null) {
        try {
          final product = products.firstWhere((p) => p.id == widget.productId);
          _nameController.text = product.name;
          _hsnCodeController.text = product.hsnCode ?? '';
          _cgstController.text = product.cgst.toString();
          _sgstController.text = product.sgst.toString();
          _igstController.text = product.igst.toString();
          _currentStockController.text = product.currentStock.toString();
          _minimumStockController.text = product.minimumStock.toString();
          _isActive = product.isActive;
        } catch (_) {}
      }
    }
  }

  void _calculateIgst() {
    // IGST calculation based on selling price removed as selling price is now customer-specific.
    // If you need to calculate a default IGST, it should be done elsewhere.
  }

  @override
  void dispose() {
    _cgstController.removeListener(_calculateIgst);
    _sgstController.removeListener(_calculateIgst);
    
    _nameController.dispose();
    _hsnCodeController.dispose();
    _cgstController.dispose();
    _sgstController.dispose();
    _igstController.dispose();
    _currentStockController.dispose();
    _minimumStockController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      final repository = ref.read(productRepositoryProvider);
      
      final now = DateTime.now();
      final id = widget.productId ?? const Uuid().v4();
      
      final product = ProductModel(
        id: id,
        name: _nameController.text.trim(),
        hsnCode: _hsnCodeController.text.trim().isEmpty ? null : _hsnCodeController.text.trim(),
        cgst: double.tryParse(_cgstController.text.trim()) ?? 0.0,
        sgst: double.tryParse(_sgstController.text.trim()) ?? 0.0,
        igst: double.tryParse(_igstController.text.trim()) ?? 0.0,
        currentStock: double.tryParse(_currentStockController.text.trim()) ?? 0.0,
        minimumStock: double.tryParse(_minimumStockController.text.trim()) ?? 0.0,
        isActive: _isActive,
        createdAt: now,
        updatedAt: now,
      );

      if (widget.productId == null) {
        await repository.create(product, id);
      } else {
        await repository.update(id, product.toMap());
      }
      
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving product: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.productId != null;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Product' : 'New Product', style: const TextStyle(fontWeight: FontWeight.w600)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSection(
                title: 'Basic Information',
                children: [
                  CustomTextField(
                    label: 'Product Name',
                    hint: 'Enter product name',
                    controller: _nameController,
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                  CustomTextField(
                    label: 'HSN Code',
                    hint: 'Enter HSN Code',
                    controller: _hsnCodeController,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Status (Active/Inactive)', style: TextStyle(fontWeight: FontWeight.w500)),
                    value: _isActive,
                    activeColor: theme.colorScheme.primary,
                    onChanged: (bool value) {
                      setState(() => _isActive = value);
                    },
                  ),
                ],
              ),
              _buildSection(
                title: 'Inventory',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          label: 'Current Stock',
                          hint: '0',
                          keyboardType: TextInputType.number,
                          controller: _currentStockController,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: CustomTextField(
                          label: 'Minimum Stock',
                          hint: '0',
                          keyboardType: TextInputType.number,
                          controller: _minimumStockController,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              _buildSection(
                title: 'Tax Details',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          label: 'CGST (%)',
                          hint: '2.5',
                          keyboardType: TextInputType.number,
                          controller: _cgstController,
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: CustomTextField(
                          label: 'SGST (%)',
                          hint: '2.5',
                          keyboardType: TextInputType.number,
                          controller: _sgstController,
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  CustomTextField(
                    label: 'IGST (INR)',
                    hint: '1.46',
                    keyboardType: TextInputType.number,
                    controller: _igstController,
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveProduct,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading 
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(
                  isEditing ? 'Update Product' : 'Save Product',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
          ),
        ),
      ),
    );
  }
}
