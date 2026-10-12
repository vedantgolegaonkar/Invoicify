import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/customers/domain/customer_model.dart';
import '../../features/products/domain/product_model.dart';
import '../../features/orders/domain/order_model.dart';
import '../../core/theme/app_colors.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared idle state shown before the user types
// ─────────────────────────────────────────────────────────────────────────────
class _SearchIdleState extends StatefulWidget {
  final IconData icon;
  final String hint;

  const _SearchIdleState({required this.icon, required this.hint});

  @override
  State<_SearchIdleState> createState() => _SearchIdleStateState();
}

class _SearchIdleStateState extends State<_SearchIdleState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scale = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _opacity = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (_, __) => Transform.scale(
              scale: _scale.value,
              child: Opacity(
                opacity: _opacity.value,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.icon,
                    size: 36,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.hint,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Start typing to see results',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared no results state when search yields empty results
// ─────────────────────────────────────────────────────────────────────────────
class _NoResultsState extends StatefulWidget {
  final String query;
  final String entityName;
  final VoidCallback onClear;

  const _NoResultsState({
    required this.query,
    required this.entityName,
    required this.onClear,
  });

  @override
  State<_NoResultsState> createState() => _NoResultsStateState();
}

class _NoResultsStateState extends State<_NoResultsState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slide;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    _slide = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacity.value,
            child: Transform.translate(
              offset: Offset(0, _slide.value),
              child: child,
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 64,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No matches found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'We couldn\'t find any ${widget.entityName} for "${widget.query}".\nPlease check for typos or try different keywords.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: widget.onClear,
              icon: const Icon(Icons.clear_all_rounded),
              label: const Text('Clear Search'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Customer Search Delegate
// ─────────────────────────────────────────────────────────────────────────────
class CustomerSearchDelegate extends SearchDelegate<CustomerModel?> {
  final List<CustomerModel> customers;

  CustomerSearchDelegate(this.customers);

  @override
  String get searchFieldLabel => 'Search customers…';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.white60),
        border: InputBorder.none,
      ),
      textTheme: base.textTheme.copyWith(
        titleLarge: const TextStyle(color: Colors.white, fontSize: 18),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear, color: Colors.white),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().isEmpty) {
      return const _SearchIdleState(
        icon: Icons.people_outline,
        hint: 'Search by name, business or mobile',
      );
    }
    return _buildList(context);
  }

  Widget _buildList(BuildContext context) {
    final q = query.toLowerCase().trim();
    final results = customers.where((c) {
      return c.name.toLowerCase().contains(q) ||
          (c.businessName?.toLowerCase().contains(q) ?? false) ||
          c.mobile.contains(q) ||
          (c.email?.toLowerCase().contains(q) ?? false);
    }).toList();

    if (results.isEmpty) {
      return _NoResultsState(
        query: query,
        entityName: 'customers',
        onClear: () => query = '',
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: ListView.builder(
        key: ValueKey(q),
        itemCount: results.length,
        itemBuilder: (context, i) {
          final c = results[i];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF6D4C41),
              child: Text(
                _initials(c.name),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(c.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: c.businessName != null && c.businessName!.isNotEmpty
                ? Text(c.businessName!)
                : Text(c.mobile),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              close(context, c);
              context.push('/customers/${c.id}');
            },
          );
        },
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Product Search Delegate
// ─────────────────────────────────────────────────────────────────────────────
class ProductSearchDelegate extends SearchDelegate<ProductModel?> {
  final List<ProductModel> products;

  ProductSearchDelegate(this.products);

  @override
  String get searchFieldLabel => 'Search products…';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.white60),
        border: InputBorder.none,
      ),
      textTheme: TextTheme(
        titleLarge: const TextStyle(color: Colors.white, fontSize: 18),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear, color: Colors.white),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().isEmpty) {
      return const _SearchIdleState(
        icon: Icons.inventory_2_outlined,
        hint: 'Search by product name or HSN code',
      );
    }
    return _buildList(context);
  }

  Widget _buildList(BuildContext context) {
    final q = query.toLowerCase().trim();
    final results = products.where((p) {
      return p.name.toLowerCase().contains(q) ||
          (p.hsnCode?.toLowerCase().contains(q) ?? false);
    }).toList();

    if (results.isEmpty) {
      return _NoResultsState(
        query: query,
        entityName: 'products',
        onClear: () => query = '',
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: ListView.builder(
        key: ValueKey(q),
        itemCount: results.length,
        itemBuilder: (context, i) {
          final p = results[i];
          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Icon(Icons.inventory_2_outlined,
                  color: Colors.white, size: 18),
            ),
            title: Text(p.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: p.hsnCode != null ? Text('HSN: ${p.hsnCode}') : null,
            trailing: p.isActive
                ? const Icon(Icons.chevron_right)
                : const Icon(Icons.block, color: Colors.red, size: 18),
            onTap: () {
              close(context, p);
              context.push('/products/${p.id}');
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Order Search Delegate
// ─────────────────────────────────────────────────────────────────────────────
class OrderSearchDelegate extends SearchDelegate<OrderModel?> {
  final List<OrderModel> orders;

  OrderSearchDelegate(this.orders);

  @override
  String get searchFieldLabel => 'Search by order number…';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.white60),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear, color: Colors.white),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().isEmpty) {
      return const _SearchIdleState(
        icon: Icons.shopping_cart_outlined,
        hint: 'Search by order number or status',
      );
    }
    return _buildList(context);
  }

  Widget _buildList(BuildContext context) {
    final q = query.toLowerCase().trim();
    final results = orders.where((o) {
      return o.orderNumber.toLowerCase().contains(q) ||
          o.status.name.toLowerCase().contains(q);
    }).toList();

    if (results.isEmpty) {
      return _NoResultsState(
        query: query,
        entityName: 'orders',
        onClear: () => query = '',
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: ListView.builder(
        key: ValueKey(q),
        itemCount: results.length,
        itemBuilder: (context, i) {
          final o = results[i];
          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Icon(Icons.shopping_cart_outlined,
                  color: Colors.white, size: 18),
            ),
            title: Text('Order #${o.orderNumber}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
                '${DateFormat('dd MMM yyyy').format(o.orderDate)} · ₹${o.total.toStringAsFixed(2)}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              close(context, o);
              context.push('/orders/${o.id}');
            },
          );
        },
      ),
    );
  }
}
