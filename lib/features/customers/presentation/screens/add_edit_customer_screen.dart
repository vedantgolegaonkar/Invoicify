import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../domain/customer_model.dart';
import '../../data/customer_repository.dart';
import '../../providers/customer_providers.dart';

class AddEditCustomerScreen extends ConsumerStatefulWidget {
  final String? customerId;

  const AddEditCustomerScreen({super.key, this.customerId});

  @override
  ConsumerState<AddEditCustomerScreen> createState() => _AddEditCustomerScreenState();
}

class _AddEditCustomerScreenState extends ConsumerState<AddEditCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _gstController = TextEditingController();
  final _stateNameController = TextEditingController();
  final _stateCodeController = TextEditingController();

  bool _whatsappSameAsMobile = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _mobileController.addListener(_syncWhatsApp);
    _gstController.addListener(_deriveStateFromGst);

    if (widget.customerId != null) {
      final customers = ref.read(customersStreamProvider).value;
      if (customers != null) {
        try {
          final customer = customers.firstWhere((c) => c.id == widget.customerId);
          _nameController.text = customer.name;
          _businessNameController.text = customer.businessName ?? '';
          _mobileController.text = customer.mobile;
          final existingWhatsapp = customer.whatsappNumber ?? '';
          // If whatsapp matches mobile, keep toggle on; else turn it off
          if (existingWhatsapp.isNotEmpty && existingWhatsapp != customer.mobile) {
            _whatsappSameAsMobile = false;
            _whatsappController.text = existingWhatsapp;
          } else {
            _whatsappSameAsMobile = true;
            _whatsappController.text = customer.mobile;
          }
          _emailController.text = customer.email ?? '';
          _addressController.text = customer.address;
          _gstController.text = customer.gstNumber ?? '';
          _stateNameController.text = customer.stateName ?? '';
          _stateCodeController.text = customer.stateCode ?? '';
        } catch (_) {}
      }
    } else {
      // Default: sync whatsapp with mobile on new customer
      _whatsappController.text = _mobileController.text;
    }
  }

  void _syncWhatsApp() {
    if (_whatsappSameAsMobile) {
      _whatsappController.text = _mobileController.text;
    }
  }

  void _deriveStateFromGst() {
    final gst = _gstController.text.trim();
    if (gst.length >= 2 && _stateCodeController.text.isEmpty) {
      final code = gst.substring(0, 2);
      if (RegExp(r'^\d{2}$').hasMatch(code)) {
        _stateCodeController.text = code;
        if (_stateNameController.text.isEmpty) {
          const stateMap = {
            '01': 'Jammu & Kashmir',
            '02': 'Himachal Pradesh',
            '03': 'Punjab',
            '04': 'Chandigarh',
            '05': 'Uttarakhand',
            '06': 'Haryana',
            '07': 'Delhi',
            '08': 'Rajasthan',
            '09': 'Uttar Pradesh',
            '10': 'Bihar',
            '19': 'West Bengal',
            '23': 'Madhya Pradesh',
            '24': 'Gujarat',
            '27': 'Maharashtra',
            '29': 'Karnataka',
            '32': 'Kerala',
            '33': 'Tamil Nadu',
            '36': 'Telangana',
            '37': 'Andhra Pradesh',
          };
          if (stateMap.containsKey(code)) {
            _stateNameController.text = stateMap[code]!;
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _mobileController.removeListener(_syncWhatsApp);
    _gstController.removeListener(_deriveStateFromGst);
    _nameController.dispose();
    _businessNameController.dispose();
    _mobileController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _gstController.dispose();
    _stateNameController.dispose();
    _stateCodeController.dispose();
    super.dispose();
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(customerRepositoryProvider);

      final now = DateTime.now();
      final id = widget.customerId ?? const Uuid().v4();

      // Preserve existing outstanding if editing
      double outstanding = 0.0;
      if (widget.customerId != null) {
        final customers = ref.read(customersStreamProvider).value;
        final existing = customers?.where((c) => c.id == widget.customerId).firstOrNull;
        outstanding = existing?.currentOutstanding ?? 0.0;
      }

      final whatsapp = _whatsappSameAsMobile
          ? _mobileController.text.trim()
          : _whatsappController.text.trim();

      final customer = CustomerModel(
        id: id,
        name: _nameController.text.trim(),
        businessName: _businessNameController.text.trim().isEmpty
            ? null
            : _businessNameController.text.trim(),
        mobile: _mobileController.text.trim(),
        whatsappNumber: whatsapp.isEmpty ? null : whatsapp,
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        address: _addressController.text.trim(),
        currentOutstanding: outstanding,
        gstNumber: _gstController.text.trim().isEmpty ? null : _gstController.text.trim().toUpperCase(),
        stateName: _stateNameController.text.trim().isEmpty ? null : _stateNameController.text.trim(),
        stateCode: _stateCodeController.text.trim().isEmpty ? null : _stateCodeController.text.trim(),
        createdAt: now,
        updatedAt: now,
      );

      if (widget.customerId == null) {
        await repository.create(customer, id);
      } else {
        await repository.update(id, customer.toMap());
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving customer: $e')),
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
    final isEditing = widget.customerId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Customer' : 'Add Customer'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Personal Info ──────────────────────────────────
              _sectionHeader('Personal Info'),
              CustomTextField(
                label: 'Customer Name',
                hint: 'Enter full name',
                prefixIcon: const Icon(Icons.person_outline),
                controller: _nameController,
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              CustomTextField(
                label: 'Business Name',
                hint: 'Enter business name',
                prefixIcon: const Icon(Icons.business_outlined),
                controller: _businessNameController,
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),

              // ─── Contact Details ────────────────────────────────
              _sectionHeader('Contact Details'),
              CustomTextField(
                label: 'Mobile Number',
                hint: '10 digit mobile number',
                keyboardType: TextInputType.phone,
                prefixIcon: const Icon(Icons.phone_outlined),
                controller: _mobileController,
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),

              // WhatsApp toggle styled as a card
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SwitchListTile(
                  title: Row(
                    children: [
                      Icon(Icons.chat_outlined,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 12),
                      const Text('WhatsApp'),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Same as Mobile Number',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  value: _whatsappSameAsMobile,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  onChanged: (bool value) {
                    setState(() {
                      _whatsappSameAsMobile = value;
                      if (value) {
                        _whatsappController.text = _mobileController.text;
                      } else {
                        _whatsappController.clear();
                      }
                    });
                  },
                ),
              ),

              if (!_whatsappSameAsMobile)
                CustomTextField(
                  label: 'WhatsApp Number',
                  hint: 'Enter WhatsApp number',
                  keyboardType: TextInputType.phone,
                  prefixIcon: const Icon(Icons.chat_outlined),
                  controller: _whatsappController,
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                ),

              CustomTextField(
                label: 'Email',
                hint: 'Optional',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(Icons.email_outlined),
                controller: _emailController,
              ),

              // ─── Statutory & Tax Details (GST) ───────────────────
              _sectionHeader('Tax & GST Details (Optional)'),
              CustomTextField(
                label: 'GSTIN / UIN',
                hint: 'e.g. 27AABCU9603R1ZX',
                prefixIcon: const Icon(Icons.receipt_outlined),
                controller: _gstController,
              ),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: CustomTextField(
                      label: 'State Name',
                      hint: 'e.g. Maharashtra',
                      controller: _stateNameController,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: CustomTextField(
                      label: 'State Code',
                      hint: 'e.g. 27',
                      keyboardType: TextInputType.number,
                      controller: _stateCodeController,
                    ),
                  ),
                ],
              ),

              // ─── Address ─────────────────────────────────────
              _sectionHeader('Address'),
              CustomTextField(
                label: 'Business Address',
                hint: 'Enter full business address',
                maxLines: 3,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 48),
                  child: Icon(Icons.location_on_outlined),
                ),
                controller: _addressController,
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),

              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveCustomer,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(
                          isEditing ? 'Update Customer' : 'Save Customer',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
