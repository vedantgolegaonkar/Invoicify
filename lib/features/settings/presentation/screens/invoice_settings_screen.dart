import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../providers/settings_providers.dart';
import '../../data/settings_repository.dart';
import '../../domain/settings_model.dart';

class InvoiceSettingsScreen extends ConsumerStatefulWidget {
  const InvoiceSettingsScreen({super.key});

  @override
  ConsumerState<InvoiceSettingsScreen> createState() => _InvoiceSettingsScreenState();
}

class _InvoiceSettingsScreenState extends ConsumerState<InvoiceSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _signatureController = TextEditingController();
  
  bool _isLoading = false;
  SettingsModel? _currentSettings;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
    });
  }

  Future<void> _loadSettings() async {
    final settingsAsync = await ref.read(settingsStreamProvider.future);
    if (mounted && settingsAsync != null) {
      setState(() {
        _currentSettings = settingsAsync;
        _signatureController.text = settingsAsync.digitalSignature ?? '';
      });
    }
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final repository = ref.read(settingsRepositoryProvider);
      final signature = _signatureController.text.trim();
      
      if (_currentSettings != null) {
        await repository.update('default', {
          'digitalSignature': signature,
          'updatedAt': DateTime.now(),
        });
      } else {
        final now = DateTime.now();
        final newSettings = SettingsModel(
          id: 'default',
          pinEnabled: false,
          digitalSignature: signature,
          invoicePrefix: 'INV-',
          invoiceNextNumber: 1,
          createdAt: now,
          updatedAt: now,
        );
        await repository.create(newSettings, 'default');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice signature saved successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomTextField(
                label: 'Digital Signature',
                hint: 'Enter your name or signature text',
                controller: _signatureController,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Signature is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Text(
                'This digital signature will appear on all generated invoices in the Authorized Signatory section.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveSettings,
                child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
