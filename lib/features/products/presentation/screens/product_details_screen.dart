import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/product_providers.dart';
import '../../data/product_repository.dart';
import '../../domain/product_model.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:uuid/uuid.dart';
import '../../../inventory/data/inventory_repository.dart';
import '../../../inventory/domain/inventory_transaction_model.dart';
class ProductDetailsScreen extends ConsumerWidget {
  final String productId;

  const ProductDetailsScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsStreamProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
        data: (products) {
          final product = products.firstWhere(
            (p) => p.id == productId, 
            orElse: () => throw Exception('Product not found'),
          );

          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(context, product, ref, theme),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      _buildInfoCard(
                        context: context,
                        title: 'Pricing & Inventory',
                        icon: Icons.inventory_2_outlined,
                        children: [

                          _buildDetailRow('Current Stock', '${product.currentStock} units', theme, icon: Icons.shopping_basket_outlined),
                          if (product.minimumStock > 0) ...[
                            _buildDivider(),
                            _buildDetailRow('Minimum Stock', '${product.minimumStock} units', theme, icon: Icons.warning_amber_rounded),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInfoCard(
                        context: context,
                        title: 'Tax Information',
                        icon: Icons.account_balance_outlined,
                        children: [
                          _buildDetailRow('HSN Code', product.hsnCode?.isNotEmpty == true ? product.hsnCode! : 'N/A', theme, icon: Icons.tag),
                          _buildDivider(),
                          _buildDetailRow('CGST', '${product.cgst}%', theme, icon: Icons.receipt_long_outlined),
                          _buildDivider(),
                          _buildDetailRow('SGST', '${product.sgst}%', theme, icon: Icons.receipt_long_outlined),
                          _buildDivider(),
                          _buildDetailRow('IGST', '₹ ${product.igst.toStringAsFixed(2)}', theme, icon: Icons.monetization_on_outlined),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/products/$productId/edit'),
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Edit Product', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 4,
      ),
      bottomNavigationBar: productsAsync.maybeWhen(
        data: (products) {
          final productMatches = products.where((p) => p.id == productId);
          if (productMatches.isEmpty) return const SizedBox.shrink();
          final product = productMatches.first;
          
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () => _showAddStockDialog(context, ref, product),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Add Stock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          );
        },
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(BuildContext context, ProductModel product, WidgetRef ref, ThemeData theme) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      elevation: 0,
      backgroundColor: theme.colorScheme.primary,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
          onPressed: () => _confirmDelete(context, ref),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withOpacity(0.8),
                theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              ],
              stops: const [0.0, 0.7, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(Icons.inventory_2_rounded, size: 44, color: theme.colorScheme.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  product.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
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
                          shape: BoxShape.circle,
                          color: product.isActive ? AppColors.success : AppColors.error,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        product.isActive ? 'Active' : 'Inactive',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: product.isActive ? AppColors.success : AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: theme.colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, ThemeData theme, {bool isBold = false, Color? valueColor, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Divider(height: 1, thickness: 1, color: Colors.grey.withOpacity(0.1)),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Product'),
          ],
        ),
        content: const Text('Are you sure you want to delete this product? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurface)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      if (context.mounted) {
        context.pop();
      }
      await ref.read(productRepositoryProvider).softDelete(productId);
    }
  }

  Future<void> _showAddStockDialog(BuildContext context, WidgetRef ref, ProductModel product) async {
    final TextEditingController controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Stock'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Quantity to Add',
                border: OutlineInputBorder(),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Please enter quantity';
                final qty = double.tryParse(val);
                if (qty == null || qty <= 0) return 'Enter a valid positive number';
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final qtyToAdd = double.parse(controller.text);
                  final newStock = product.currentStock + qtyToAdd;
                  
                  final productRepo = ref.read(productRepositoryProvider);
                  final inventoryRepo = ref.read(inventoryRepositoryProvider);
                  
                  try {
                    await productRepo.update(product.id, {'currentStock': newStock});
                    
                    final txnId = const Uuid().v4();
                    final transaction = InventoryTransactionModel(
                      id: txnId,
                      productId: product.id,
                      type: TransactionType.stockIn,
                      quantity: qtyToAdd,
                      previousStock: product.currentStock,
                      newStock: newStock,
                      remarks: 'Manual Stock Added',
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );
                    await inventoryRepo.create(transaction, txnId);
                    
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock added successfully')));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding stock: $e')));
                    }
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}
