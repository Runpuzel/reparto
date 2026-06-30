import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/supabase_client.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_error.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
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
      backgroundColor:
      success ? Colors.green.shade700 : Theme.of(context).colorScheme.error,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final campuses = ref.watch(campusesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Student Seller Application')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _InfoBanner(),
                    const SizedBox(height: AppSpacing.lg),

                    const _SectionLabel('Business identity'),
                    const SizedBox(height: AppSpacing.sm + 4),
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
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _business,
                      label: 'Business Name',
                      prefixIcon: AppIcons.storefront,
                      validator: (v) =>
                          Validators.required(v, 'Business name'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _owner,
                      label: 'Owner Name',
                      prefixIcon: AppIcons.user,
                      validator: (v) => Validators.required(v, 'Owner name'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AsyncView<List<Campus>>(
                      value: campuses,
                      data: (list) => DropdownButtonFormField<String>(
                        value: _campusId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Campus',
                          prefixIcon: Icon(AppIcons.campus, size: 20),
                        ),
                        items: list
                            .map((c) => DropdownMenuItem(
                            value: c.campusId, child: Text(c.campusName)))
                            .toList(),
                        onChanged: (v) => setState(() => _campusId = v),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    const _SectionLabel('Contact numbers'),
                    const SizedBox(height: AppSpacing.sm + 4),
                    AppTextField(
                      controller: _phone,
                      label: 'Personal Phone Number',
                      prefixIcon: AppIcons.phone,
                      keyboardType: TextInputType.phone,
                      validator: Validators.phone,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _businessPhone,
                      label: 'Business Phone Number',
                      prefixIcon: AppIcons.phoneBusiness,
                      keyboardType: TextInputType.phone,
                      validator: Validators.phone,
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    const _SectionLabel('Mobile money (for payouts)'),
                    const SizedBox(height: AppSpacing.sm + 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 130,
                          child: DropdownButtonFormField<String>(
                            value: _momoNetwork,
                            decoration:
                            const InputDecoration(labelText: 'Network'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'MTN', child: Text('MTN')),
                              DropdownMenuItem(
                                  value: 'Vodafone', child: Text('Telecel')),
                              DropdownMenuItem(
                                  value: 'AirtelTigo',
                                  child: Text('AirtelTigo')),
                            ],
                            onChanged: (v) =>
                                setState(() => _momoNetwork = v ?? 'MTN'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: AppTextField(
                            controller: _momo,
                            label: 'MoMo Number',
                            prefixIcon: AppIcons.wallet,
                            keyboardType: TextInputType.phone,
                            validator: Validators.momo,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    const _SectionLabel('Identity verification (Ghana Card)'),
                    const SizedBox(height: AppSpacing.sm + 4),
                    AppTextField(
                      controller: _ghanaCard,
                      label: 'Ghana Card Number',
                      hint: 'GHA-123456789-0',
                      prefixIcon: AppIcons.badge,
                      inputFormatters: [UpperCaseTextFormatter()],
                      validator: Validators.ghanaCard,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ImageUploadField(
                      label: 'Ghana Card photo',
                      icon: Icons.badge_outlined,
                      onPicked: (p) => _ghanaCardImage = p,
                    ),
                    const SizedBox(height: AppSpacing.xs + 2),
                    Text(
                      'Your card photo is stored privately and only visible to '
                          'administrators for verification.',
                      style: AppTextStyles.bodySmall,
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    const _SectionLabel('Account'),
                    const SizedBox(height: AppSpacing.sm + 4),
                    AppTextField(
                      controller: _email,
                      label: 'Email',
                      prefixIcon: AppIcons.email,
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.email,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _password,
                      label: 'Password',
                      helper: '8+ chars, 1 number, 1 uppercase',
                      prefixIcon: AppIcons.lock,
                      obscureText: _obscure,
                      suffixIcon: _obscure ? AppIcons.eyeOff : AppIcons.eye,
                      onSuffixTap: () => setState(() => _obscure = !_obscure),
                      validator: Validators.password,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: _loading
                          ? 'Submitting…'
                          : 'Submit Application',
                      icon: _loading ? null : AppIcons.shield,
                      loading: _loading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Already have an account? Sign in'),
                    ),
                  ]
                      .animate(interval: 40.ms)
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.03, end: 0),
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
      style: AppTextStyles.labelMedium.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: AppRadius.brLg,
      ),
      child: Row(children: [
        Icon(AppIcons.info, size: 20, color: scheme.onSecondaryContainer),
        const SizedBox(width: AppSpacing.sm + 2),
        Expanded(
          child: Text(
            'Student Seller accounts require admin approval before you can '
                'list products.',
            style: AppTextStyles.bodySmall
                .copyWith(color: scheme.onSecondaryContainer),
          ),
        ),
      ]),
    );
  }
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
