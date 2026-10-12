import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class LegalScreen extends StatelessWidget {
  final int initialTabIndex;

  const LegalScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Legal & Compliance'),
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: [
              Tab(text: 'Terms & Conditions', icon: Icon(Icons.description_outlined)),
              Tab(text: 'Privacy Policy', icon: Icon(Icons.privacy_tip_outlined)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _TermsContent(),
            _PrivacyContent(),
          ],
        ),
      ),
    );
  }
}

class _TermsContent extends StatelessWidget {
  const _TermsContent();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader('Invoicify Terms and Conditions', 'Last Updated: October 2026'),
          const SizedBox(height: 16),
          _buildSection(
            '1. Acceptance of Terms',
            'By accessing or using the Invoicify mobile application operated by Herambh Software Technologies and Solutions, you agree to comply with and be bound by these Terms. If you do not agree, please do not use the application.',
          ),
          _buildSection(
            '2. Description of Service',
            'Invoicify provides billing, invoicing, customer ledger tracking, inventory management, and business reporting tools designed for commercial business operations.',
          ),
          _buildSection(
            '3. User Responsibility & Tax Compliance',
            'You are solely responsible for ensuring that all invoices, tax rates (such as GST), HSN/SAC codes, and numbers generated through this software comply with all applicable tax laws and regulatory requirements in your jurisdiction. Invoicify does not provide formal legal, tax, or accounting advice.',
          ),
          _buildSection(
            '4. Ownership of Business Data',
            'You retain full ownership and rights over all customer records, product catalogs, pricing, and transactions inputted into this app. You warrant that you have obtained appropriate consent from your customers to store and process their contact details.',
          ),
          _buildSection(
            '5. Security & Credentials',
            'You are responsible for securing access to your mobile device, including keeping any PIN codes confidential. You are solely responsible for any activity conducted on your device.',
          ),
          _buildSection(
            '6. Disclaimer of Warranties',
            'The application is provided "AS IS" without warranty of any kind. Herambh Software Technologies and Solutions does not guarantee that the software will be completely error-free or uninterrupted at all times.',
          ),
          _buildSection(
            '7. Limitation of Liability',
            'To the maximum extent permitted by law, Herambh Software Technologies and Solutions shall not be liable for any indirect, incidental, or consequential damages resulting from your use of the application.',
          ),
          _buildSection(
            '8. Governing Law',
            'These Terms are governed by the laws of India. Any disputes shall be subject to the exclusive jurisdiction of the competent courts in Pune, Maharashtra, India.',
          ),
          const SizedBox(height: 20),
          _buildContactBox(),
        ],
      ),
    );
  }
}

class _PrivacyContent extends StatelessWidget {
  const _PrivacyContent();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader('Privacy Policy', 'Last Updated: October 2026'),
          const SizedBox(height: 16),
          _buildSection(
            '1. Information We Collect',
            '• Business Details: Business name, address, phone number, GSTIN, FSSAI number, bank account / UPI ID, and business logo.\n• Customer Data: Customer names, mobile numbers, WhatsApp numbers, addresses, and purchase history.\n• Invoicing Records: Itemized transaction details, payment history, and outstanding balances.\n• Technical Diagnostics: Crash reports via Firebase Crashlytics to maintain application stability.',
          ),
          _buildSection(
            '2. How We Use Data',
            'Your data is strictly used to create invoices, track customer ledgers, manage inventory, calculate reports, and enable sharing via WhatsApp or email. We do not sell, rent, or share your data with advertisers or brokers.',
          ),
          _buildSection(
            '3. Data Storage & Cloud Sync',
            'Data is securely synced with Google Firebase Cloud Firestore using industry-standard HTTPS/TLS encryption in transit and AES encryption at rest.',
          ),
          _buildSection(
            '4. App Permissions',
            '• Internet: To sync data securely with Firebase cloud storage.\n• Notifications: To provide low stock and payment alerts.\n• Photo Library: To select a business logo or signature image when configured.',
          ),
          _buildSection(
            '5. Data Control & Deletion',
            'You have full control to add, edit, or delete customer and invoice records directly within the app. To request permanent account and cloud data deletion, please contact support@herambh.com.',
          ),
          const SizedBox(height: 20),
          _buildContactBox(),
        ],
      ),
    );
  }
}

Widget _buildHeader(String title, String subtitle) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
    ],
  );
}

Widget _buildSection(String title, String body) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
      ],
    ),
  );
}

Widget _buildContactBox() {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surfaceVariant.withAlpha(100),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.textSecondary.withAlpha(40)),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contact & Developer Information',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        SizedBox(height: 6),
        Text(
          'Herambh Software Technologies and Solutions\nPune, Maharashtra, India\nSupport: support@herambh.com',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
        ),
      ],
    ),
  );
}
