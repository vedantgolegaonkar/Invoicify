import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          _buildSettingsItem(context, 'Business Profile', Icons.storefront_outlined, '/settings/business-profile'),
          _buildSettingsItem(context, 'Invoice Settings', Icons.receipt_long_outlined, '/settings/invoice-settings'),
          const Divider(),
          Consumer(
            builder: (context, ref, child) {
              return ListTile(
                leading: const Icon(Icons.cloud_upload_outlined),
                title: const Text('Backup Data'),
                subtitle: const Text('Live synced to cloud'),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Your data is securely backed up and synced to the cloud in real-time.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              );
            }
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            subtitle: const Text('Version 1.0.0'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Invoicify',
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(Icons.receipt_long, size: 48),
                children: const [
                  Text('A comprehensive billing and inventory management application by Herambh Software Technologies and Solutions.'),
                ],
              );
            },
          ),
          const Divider(),
          _buildSettingsItem(context, 'Terms & Conditions', Icons.description_outlined, '/settings/terms-conditions'),
          _buildSettingsItem(context, 'Privacy Policy', Icons.privacy_tip_outlined, '/settings/privacy-policy'),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await ref.read(authNotifierProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(BuildContext context, String title, IconData icon, String route) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    );
  }
}
