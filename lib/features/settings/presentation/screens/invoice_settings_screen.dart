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
  final _prefixController = TextEditingController();
  final _nextNumberController = TextEditingController();
  
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
        _prefixController.text = settingsAsync.invoicePrefix;
        _nextNumberController.text = settingsAsync.invoiceNextNumber.toString();
      });
    } else if (mounted) {
      setState(() {
        _prefixController.text = 'INV-';
        _nextNumberController.text = '1';
      });
    }
  }

  @override
  void dispose() {
    _prefixController.dispose();
    _nextNumberController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final repository = ref.read(settingsRepositoryProvider);
      final nextNum = int.tryParse(_nextNumberController.text.trim()) ?? 1;
      final prefix = _prefixController.text.trim();
      
      if (_currentSettings != null) {
        await repository.update('default', {
          'invoicePrefix': prefix,
          'invoiceNextNumber': nextNum,
          'updatedAt': DateTime.now(),
        });
      } else {
        final now = DateTime.now();
        final newSettings = SettingsModel(
          id: 'default',
          pinEnabled: false,
          invoicePrefix: prefix,
          invoiceNextNumber: nextNum,
          createdAt: now,
          updatedAt: now,
        );
        await repository.create(newSettings, 'default');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice settings saved successfully')),
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
                label: 'Invoice Prefix',
                hint: 'e.g., INV-',
                controller: _prefixController,
                validator: (val) => val == null || val.isEmpty ? 'Prefix is required' : null,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Next Invoice Number',
                hint: 'e.g., 1001',
                keyboardType: TextInputType.number,
                controller: _nextNumberController,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Number is required';
                  if (int.tryParse(val) == null) return 'Must be a valid integer';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text('Signature', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Container(
                height: 100,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text('Tap to upload signature image (Coming Soon)', style: TextStyle(color: Colors.grey)),
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
