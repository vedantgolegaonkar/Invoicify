import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('More Options'),
      ),
      body: ListView(
        children: [
          _buildListItem(context, 'Products', Icons.inventory_2_outlined, '/products'),
          _buildListItem(context, 'Payments', Icons.payments_outlined, '/payments'),
          // _buildListItem(context, 'Inventory', Icons.warehouse_outlined, '/inventory'),
          // const Divider(),
          // _buildListItem(context, 'Reports', Icons.bar_chart_outlined, '/reports'),
          const Divider(),
          _buildListItem(context, 'Settings', Icons.settings_outlined, '/settings'),
        ],
      ),
    );
  }

  Widget _buildListItem(BuildContext context, String title, IconData icon, String route) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    );
  }
}
