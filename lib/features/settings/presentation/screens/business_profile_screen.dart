import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../domain/business_model.dart';
import '../../data/business_repository.dart';
import '../../providers/business_providers.dart';

class BusinessProfileScreen extends ConsumerStatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  ConsumerState<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends ConsumerState<BusinessProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _businessNameCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _fssaiCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _msmeCtrl = TextEditingController();
  final _arnCtrl = TextEditingController();
  final _jurisdictionCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _bankAccountCtrl = TextEditingController();
  final _bankIfscCtrl = TextEditingController();
  final _upiIdCtrl = TextEditingController();
  final _termsCtrl = TextEditingController();

  bool _loaded = false;
  bool _saving = false;
  BusinessModel? _existing;
  String? _logoUrl;
  String? _paymentQrUrl;

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _gstCtrl.dispose();
    _fssaiCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _panCtrl.dispose();
    _msmeCtrl.dispose();
    _arnCtrl.dispose();
    _jurisdictionCtrl.dispose();
    _addressCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankAccountCtrl.dispose();
    _bankIfscCtrl.dispose();
    _upiIdCtrl.dispose();
    _termsCtrl.dispose();
    super.dispose();
  }

  void _populate(BusinessModel biz) {
    if (_loaded) return;
    _loaded = true;
    _existing = biz;
    _businessNameCtrl.text = biz.businessName;
    _gstCtrl.text = biz.gstNumber ?? '';
    _fssaiCtrl.text = biz.fssaiNumber ?? '';
    _phoneCtrl.text = biz.phone;
    _emailCtrl.text = biz.email ?? '';
    _panCtrl.text = biz.panNumber ?? '';
    _msmeCtrl.text = biz.msmeNumber ?? '';
    _arnCtrl.text = biz.arnNumber ?? '';
    _jurisdictionCtrl.text = biz.jurisdictionCity ?? '';
    _addressCtrl.text = biz.address;
    _bankNameCtrl.text = biz.bankName ?? '';
    _bankAccountCtrl.text = biz.bankAccount ?? '';
    _bankIfscCtrl.text = biz.bankIfsc ?? '';
    _upiIdCtrl.text = biz.upiId ?? '';
    _termsCtrl.text = biz.termsAndConditions ?? '';
    _logoUrl = biz.logoUrl;
    _paymentQrUrl = biz.paymentQrUrl;
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _logoUrl = image.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _pickPaymentQr() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _paymentQrUrl = image.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking Payment QR: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(businessRepositoryProvider);
      final storage = ref.read(storageServiceProvider);
      final userId = ref.read(authUserIdProvider) ?? 'common';
      final now = DateTime.now();

      // If a new local image was picked (not starting with http or data:), upload or encode
      String? uploadedLogoUrl = _logoUrl;
      if (_logoUrl != null &&
          _logoUrl!.isNotEmpty &&
          !_logoUrl!.startsWith('http://') &&
          !_logoUrl!.startsWith('https://') &&
          !_logoUrl!.startsWith('data:image')) {
        final localFile = File(_logoUrl!);
        if (await localFile.exists()) {
          final ext = _logoUrl!.split('.').last.toLowerCase();
          final storagePath = 'users/$userId/business_logo_${DateTime.now().millisecondsSinceEpoch}.$ext';
          
          try {
            final downloadUrl = await storage.uploadFile(path: storagePath, file: localFile);
            if (downloadUrl != null && downloadUrl.isNotEmpty) {
              uploadedLogoUrl = downloadUrl;
            } else {
              // Firebase Storage upload failed/returned null - fallback to base64 encoding so logo is saved in Firestore database
              final bytes = await localFile.readAsBytes();
              final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
              uploadedLogoUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
            }
          } catch (storageErr) {
            debugPrint('Firebase Storage error: $storageErr. Falling back to base64 storage.');
            final bytes = await localFile.readAsBytes();
            final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
            uploadedLogoUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
          }
        }
      }

      // If a new local payment QR was picked (not starting with http or data:), upload or encode
      String? uploadedPaymentQrUrl = _paymentQrUrl;
      if (_paymentQrUrl != null &&
          _paymentQrUrl!.isNotEmpty &&
          !_paymentQrUrl!.startsWith('http://') &&
          !_paymentQrUrl!.startsWith('https://') &&
          !_paymentQrUrl!.startsWith('data:image')) {
        final localFile = File(_paymentQrUrl!);
        if (await localFile.exists()) {
          final ext = _paymentQrUrl!.split('.').last.toLowerCase();
          final storagePath = 'users/$userId/payment_qr_${DateTime.now().millisecondsSinceEpoch}.$ext';
          
          try {
            final downloadUrl = await storage.uploadFile(path: storagePath, file: localFile);
            if (downloadUrl != null && downloadUrl.isNotEmpty) {
              uploadedPaymentQrUrl = downloadUrl;
            } else {
              // Firebase Storage upload failed/returned null - fallback to base64 encoding so payment QR is saved in Firestore database
              final bytes = await localFile.readAsBytes();
              final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
              uploadedPaymentQrUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
            }
          } catch (storageErr) {
            debugPrint('Firebase Storage error for QR: $storageErr. Falling back to base64 storage.');
            final bytes = await localFile.readAsBytes();
            final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
            uploadedPaymentQrUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
          }
        }
      }

      final gstVal = _gstCtrl.text.trim().isEmpty ? null : _gstCtrl.text.trim().toUpperCase();
      // Auto derive PAN from GST if PAN is empty (standard: chars 3 to 12)
      String? panVal = _panCtrl.text.trim().isEmpty ? null : _panCtrl.text.trim().toUpperCase();
      if (panVal == null && gstVal != null && gstVal.length >= 12) {
        panVal = gstVal.substring(2, 12);
      }

      if (_existing != null) {
        await repo.update(_existing!.id, {
          'businessName': _businessNameCtrl.text.trim(),
          'gstNumber': gstVal,
          'fssaiNumber': _fssaiCtrl.text.trim().isEmpty ? null : _fssaiCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          'panNumber': panVal,
          'msmeNumber': _msmeCtrl.text.trim().isEmpty ? null : _msmeCtrl.text.trim(),
          'arnNumber': _arnCtrl.text.trim().isEmpty ? null : _arnCtrl.text.trim(),
          'jurisdictionCity': _jurisdictionCtrl.text.trim().isEmpty ? null : _jurisdictionCtrl.text.trim(),
          'address': _addressCtrl.text.trim(),
          'bankName': _bankNameCtrl.text.trim().isEmpty ? null : _bankNameCtrl.text.trim(),
          'bankAccount': _bankAccountCtrl.text.trim().isEmpty ? null : _bankAccountCtrl.text.trim(),
          'bankIfsc': _bankIfscCtrl.text.trim().isEmpty ? null : _bankIfscCtrl.text.trim().toUpperCase(),
          'upiId': _upiIdCtrl.text.trim().isEmpty ? null : _upiIdCtrl.text.trim(),
          'paymentQrUrl': uploadedPaymentQrUrl,
          'termsAndConditions': _termsCtrl.text.trim().isEmpty ? null : _termsCtrl.text.trim(),
          'logoUrl': uploadedLogoUrl,
        });
      } else {
        final id = 'primary';
        final newBiz = BusinessModel(
          id: id,
          businessName: _businessNameCtrl.text.trim(),
          gstNumber: gstVal,
          fssaiNumber: _fssaiCtrl.text.trim().isEmpty ? null : _fssaiCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          panNumber: panVal,
          msmeNumber: _msmeCtrl.text.trim().isEmpty ? null : _msmeCtrl.text.trim(),
          arnNumber: _arnCtrl.text.trim().isEmpty ? null : _arnCtrl.text.trim(),
          jurisdictionCity: _jurisdictionCtrl.text.trim().isEmpty ? null : _jurisdictionCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          bankName: _bankNameCtrl.text.trim().isEmpty ? null : _bankNameCtrl.text.trim(),
          bankAccount: _bankAccountCtrl.text.trim().isEmpty ? null : _bankAccountCtrl.text.trim(),
          bankIfsc: _bankIfscCtrl.text.trim().isEmpty ? null : _bankIfscCtrl.text.trim().toUpperCase(),
          upiId: _upiIdCtrl.text.trim().isEmpty ? null : _upiIdCtrl.text.trim(),
          paymentQrUrl: uploadedPaymentQrUrl,
          termsAndConditions: _termsCtrl.text.trim().isEmpty ? null : _termsCtrl.text.trim(),
          logoUrl: uploadedLogoUrl,
          invoicePrefix: 'INV-',
          invoiceStartNumber: 1,
          createdAt: now,
          updatedAt: now,
        );
        await repo.create(newBiz, id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business profile saved!'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessAsync = ref.watch(businessStreamProvider);

    // Populate when first loaded
    businessAsync.whenData((list) {
      if (list.isNotEmpty) _populate(list.first);
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Business Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: businessAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (_) => SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo avatar
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.secondary,
                          backgroundImage: () {
                            if (_logoUrl == null || _logoUrl!.isEmpty) return null;
                            if (_logoUrl!.startsWith('data:image')) {
                              final commaIdx = _logoUrl!.indexOf(',');
                              if (commaIdx != -1) {
                                final b64 = _logoUrl!.substring(commaIdx + 1);
                                return MemoryImage(base64Decode(b64)) as ImageProvider;
                              }
                            }
                            if (_logoUrl!.startsWith('http://') || _logoUrl!.startsWith('https://')) {
                              return NetworkImage(_logoUrl!) as ImageProvider;
                            }
                            final file = File(_logoUrl!);
                            return file.existsSync() ? FileImage(file) : null;
                          }(),
                          child: _logoUrl == null || _logoUrl!.isEmpty 
                            ? const Icon(Icons.storefront, size: 50, color: AppColors.primary)
                            : null,
                        ),
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.primary,
                          child: const Icon(Icons.edit, size: 18, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                _sectionHeader('Business Information', Icons.business_outlined),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Business Name *',
                  hint: 'Enter business name',
                  controller: _businessNameCtrl,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                CustomTextField(
                  label: 'GST Number',
                  hint: 'e.g. 27AABCU9603R1ZX (optional)',
                  controller: _gstCtrl,
                ),
                CustomTextField(
                  label: 'ARN Number',
                  hint: 'e.g. AA2703240012345 (optional)',
                  controller: _arnCtrl,
                ),
                CustomTextField(
                  label: 'MSME / Udyam Reg. No.',
                  hint: 'e.g. UDYAM-MH-12-0012345 (optional)',
                  controller: _msmeCtrl,
                ),
                CustomTextField(
                  label: 'FSSAI Number',
                  hint: 'Optional',
                  controller: _fssaiCtrl,
                ),
                CustomTextField(
                  label: 'Phone Number *',
                  hint: '10 digit mobile number',
                  keyboardType: TextInputType.phone,
                  controller: _phoneCtrl,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                CustomTextField(
                  label: 'Email Address',
                  hint: 'e.g. contact@business.com',
                  keyboardType: TextInputType.emailAddress,
                  controller: _emailCtrl,
                ),
                CustomTextField(
                  label: 'Jurisdiction City',
                  hint: 'e.g. PUNE (defaults to City in address)',
                  controller: _jurisdictionCtrl,
                ),
                CustomTextField(
                  label: 'Address *',
                  hint: 'Full business address (MIDC, City, PIN, State)',
                  maxLines: 3,
                  controller: _addressCtrl,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),

                const SizedBox(height: 20),
                _sectionHeader('Bank & Payment Details', Icons.account_balance_outlined),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Bank Name',
                  hint: 'e.g. State Bank of India',
                  controller: _bankNameCtrl,
                ),
                CustomTextField(
                  label: 'Account Number',
                  hint: 'Your bank account number',
                  keyboardType: TextInputType.number,
                  controller: _bankAccountCtrl,
                ),
                CustomTextField(
                  label: 'IFSC Code',
                  hint: 'e.g. SBIN0001234',
                  controller: _bankIfscCtrl,
                ),
                CustomTextField(
                  label: 'UPI ID',
                  hint: 'e.g. yourname@upi (used for QR on invoice)',
                  controller: _upiIdCtrl,
                ),
                const SizedBox(height: 16),
                // Payment QR Image Field
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment QR (Optional)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _pickPaymentQr,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppColors.secondary,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                              ),
                              child: _paymentQrUrl != null && _paymentQrUrl!.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image(
                                        image: () {
                                          if (_paymentQrUrl!.startsWith('data:image')) {
                                            final commaIdx = _paymentQrUrl!.indexOf(',');
                                            if (commaIdx != -1) {
                                              final b64 = _paymentQrUrl!.substring(commaIdx + 1);
                                              return MemoryImage(base64Decode(b64)) as ImageProvider;
                                            }
                                          }
                                          if (_paymentQrUrl!.startsWith('http://') || _paymentQrUrl!.startsWith('https://')) {
                                            return NetworkImage(_paymentQrUrl!) as ImageProvider;
                                          }
                                          final file = File(_paymentQrUrl!);
                                          return file.existsSync() ? FileImage(file) : null;
                                        }() ?? const AssetImage('assets/placeholder.png'),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => const Icon(
                                          Icons.qr_code_2,
                                          size: 40,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    )
                                  : const Icon(Icons.qr_code_2, size: 40, color: AppColors.primary),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _paymentQrUrl != null && _paymentQrUrl!.isNotEmpty
                                      ? 'Payment QR Selected'
                                      : 'No Payment QR uploaded',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Tap to upload your Google Pay, PhonePe, or UPI QR code image',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: _pickPaymentQr,
                                      icon: const Icon(Icons.upload_file, size: 16),
                                      label: Text(
                                        _paymentQrUrl != null && _paymentQrUrl!.isNotEmpty
                                            ? 'Change'
                                            : 'Upload QR',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                    if (_paymentQrUrl != null && _paymentQrUrl!.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      TextButton.icon(
                                        onPressed: () => setState(() => _paymentQrUrl = null),
                                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                        label: const Text('Remove', style: TextStyle(fontSize: 12, color: Colors.red)),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                _sectionHeader('Invoice Footer', Icons.receipt_long_outlined),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Terms & Conditions',
                  hint: 'e.g. Payment due within 30 days. Goods once sold are not returnable.',
                  maxLines: 4,
                  controller: _termsCtrl,
                ),

                const SizedBox(height: 32),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Save Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
      ],
    );
  }
}
