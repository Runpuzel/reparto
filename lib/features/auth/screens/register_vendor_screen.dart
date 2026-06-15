import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/supabase_client.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/app_error.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/image_upload_field.dart';
import '../../../models/models.dart';
import '../../shared/providers/shared_providers.dart';
import '../providers/auth_providers.dart';

class RegisterVendorScreen extends ConsumerStatefulWidget {
  const RegisterVendorScreen({super.key});

  @override
  ConsumerState<RegisterVendorScreen> createState() =>
      _RegisterVendorScreenState();
}

class _RegisterVendorScreenState extends ConsumerState<RegisterVendorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _business = TextEditingController();
  final _owner = TextEditingController();
  final _phone = TextEditingController();
  final _businessPhone = TextEditingController();
  final _momo = TextEditingController();
  final _ghanaCard = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _campusId;
  String _momoNetwork = 'MTN';
  bool _obscure = true;
  bool _loading = false;

  PickedImage? _logo;
  PickedImage? _ghanaCardImage;

  final _storage = StorageService();

  @override
  void dispose() {
    _business.dispose();
    _owner.dispose();
    _phone.dispose();
    _businessPhone.dispose();
    _momo.dispose();
    _ghanaCard.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_campusId == null) {
      _snack('Please select your campus');
      return;
    }
    if (_ghanaCardImage == null) {
      _snack('Please upload a photo of your Ghana Card');
      return;
    }
    setState(() => _loading = true);
    final repo = ref.read(authRepositoryProvider);
    try {
      final res = await repo.signUpVendor(
        businessName: _business.text.trim(),
        ownerName: _owner.text.trim(),
        phoneNumber: _phone.text.trim(),
        businessPhone: _businessPhone.text.trim(),
        momoNumber: _momo.text.trim(),
        momoNetwork: _momoNetwork,
        ghanaCardNumber: _ghanaCard.text.trim().toUpperCase(),
        email: _email.text.trim(),
        password: _password.text,
        campusId: _campusId!,
      );

      // If a session exists immediately (email confirmation off), upload the
      // images and complete the vendor record now.
      if (res.session != null && currentAuthUser != null) {
        String? logoUrl;
        String? cardPath;
        if (_logo != null) {
          logoUrl = await _storage.upload(
            bucket: StorageService.businessLogos,
            bytes: _logo!.bytes,
            fileName: _logo!.name,
          );
        }
        cardPath = await _storage.upload(
          bucket: StorageService.kycDocuments,
          bytes: _ghanaCardImage!.bytes,
          fileName: _ghanaCardImage!.name,
          publicUrl: false,
        );
        await repo.createVendorRecord(
          businessName: _business.text.trim(),
          ownerName: _owner.text.trim(),
          phoneNumber: _phone.text.trim(),
          businessPhone: _businessPhone.text.trim(),
          momoNumber: _momo.text.trim(),
          momoNetwork: _momoNetwork,
          ghanaCardNumber: _ghanaCard.text.trim().toUpperCase(),
          campusId: _campusId!,
          logoUrl: logoUrl,
          ghanaCardImageUrl: cardPath,
        );
      }

      if (!mounted) return;
      ref.invalidate(currentUserProvider);
      _snack(
        'Application submitted! Verify your email. An admin will review your business.',
        success: true,
      );
      context.go('/login');
    } catch (e) {
      _snack(AppError.friendly(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      showCloseIcon: true,
      backgroundColor: success ? Colors.green.shade700 : Theme.of(context).colorScheme.error,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final campuses = ref.watch(campusesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Vendor Registration')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _InfoBanner(),
                    const SizedBox(height: 20),

                    _SectionLabel('Business identity'),
                    const SizedBox(height: 12),
                    Center(
                      child: SizedBox(
                        width: 130,
                        child: ImageUploadField(
                          label: 'Logo (optional)',
                          icon: Icons.storefront_outlined,
                          height: 110,
                          circle: true,
                          onPicked: (p) => _logo = p,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _business,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Business Name',
                        prefixIcon: Icon(Icons.storefront_outlined),
                      ),
                      validator: (v) => Validators.required(v, 'Business name'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _owner,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Owner Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => Validators.required(v, 'Owner name'),
                    ),
                    const SizedBox(height: 14),
                    AsyncView<List<Campus>>(
                      value: campuses,
                      data: (list) => DropdownButtonFormField<String>(
                        value: _campusId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Campus',
                          prefixIcon: Icon(Icons.school_outlined),
                        ),
                        items: list
                            .map((c) => DropdownMenuItem(
                            value: c.campusId, child: Text(c.campusName)))
                            .toList(),
                        onChanged: (v) => setState(() => _campusId = v),
                      ),
                    ),

                    const SizedBox(height: 24),
                    _SectionLabel('Contact numbers'),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Personal Phone Number',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: Validators.phone,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _businessPhone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Business Phone Number',
                        prefixIcon: Icon(Icons.call_outlined),
                      ),
                      validator: Validators.phone,
                    ),

                    const SizedBox(height: 24),
                    _SectionLabel('Mobile money (for payouts)'),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 120,
                          child: DropdownButtonFormField<String>(
                            value: _momoNetwork,
                            isExpanded: true,
                            decoration: const InputDecoration(
                                labelText: 'Network'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'MTN', child: Text('MTN')),
                              DropdownMenuItem(
                                  value: 'Vodafone', child: Text('Telecel')),
                              DropdownMenuItem(
                                  value: 'AirtelTigo',
                                  child: Text('AirtelTigo', overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (v) =>
                                setState(() => _momoNetwork = v ?? 'MTN'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _momo,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'MoMo Number',
                              prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                            ),
                            validator: Validators.momo,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    _SectionLabel('Identity verification (Ghana Card)'),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _ghanaCard,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        UpperCaseTextFormatter(),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Ghana Card Number',
                        hintText: 'GHA-123456789-0',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: Validators.ghanaCard,
                    ),
                    const SizedBox(height: 14),
                    ImageUploadField(
                      label: 'Ghana Card photo',
                      icon: Icons.badge_outlined,
                      onPicked: (p) => _ghanaCardImage = p,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your card photo is stored privately and only visible to administrators for verification.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),

                    const SizedBox(height: 24),
                    _SectionLabel('Account'),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        helperText: '8+ chars, 1 number, 1 uppercase',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: Validators.password,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const _BtnSpinner()
                          : const Text('Submit Application'),
                    ),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Already have an account? Sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .secondaryContainer
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(children: [
        Icon(Icons.info_outline, size: 20),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Vendor accounts require admin approval before you can list products.',
            style: TextStyle(fontSize: 13),
          ),
        ),
      ]),
    );
  }
}

class _BtnSpinner extends StatelessWidget {
  const _BtnSpinner();
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 22,
    width: 22,
    child:
    CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
  );
}

/// Forces text input to uppercase (for the Ghana Card field).
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
