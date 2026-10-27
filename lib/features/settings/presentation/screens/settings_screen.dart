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
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
            title: const Text('Delete Account', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            subtitle: const Text('Permanently delete your account and all associated data', style: TextStyle(fontSize: 12, color: Colors.grey)),
            onTap: () => _confirmDeleteAccount(context, ref),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Delete Account?'),
          ],
        ),
        content: const Text(
          'This action is irreversible.\n\nAll your account details, business profile, customers, inventory products, and invoices stored in the cloud will be permanently deleted.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(ctx).pop();
              // Show loading overlay
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (dialogCtx) => const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.red),
                          SizedBox(height: 16),
                          Text('Deleting all account data...'),
                        ],
                      ),
                    ),
                  ),
                ),
              );

              try {
                await ref.read(authNotifierProvider.notifier).deleteAccount();
                if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).pop(); // dismiss loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Account and all associated data deleted successfully.')),
                  );
                  context.go('/login');
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).pop(); // dismiss loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting account: $e')),
                  );
                }
              }
            },
            child: const Text('Delete Permanently', style: TextStyle(color: Colors.white)),
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
