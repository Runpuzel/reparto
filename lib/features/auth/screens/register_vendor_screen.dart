// lib/features/auth/screens/register_vendor_screen.dart
// UPDATED – v1.0-2025-07 – Frictionless onboarding
// REMOVED: Ghana Card fields (moved to post-registration IdentityVerificationScreen)
// ADDED: SellerAgreement redirect gate

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
  ConsumerState<RegisterVendorScreen> createState() => RegisterVendorScreenState();
}

class RegisterVendorScreenState extends ConsumerState<RegisterVendorScreen> {
  final formKey = GlobalKey<FormState>();
  final business = TextEditingController();
  final owner = TextEditingController();
  final businessPhone = TextEditingController();
  final momo = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  String? campusId;
  String momoNetwork = 'MTN';
  bool obscure = true;
  bool loading = false;
  bool agreeTerms = false;

  PickedImage? logo;
  // REMOVED in v1.0: ghanaCard, ghanaCardImage

  final storage = StorageService();

  @override
  void dispose() {
    business.dispose();
    owner.dispose();
    businessPhone.dispose();
    momo.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    if (campusId == null) {
      snack('Please select your campus');
      return;
    }
    if (!agreeTerms) {
      snack('Please accept the Seller Terms to continue');
      return;
    }
    setState(() => loading = true);
    final repo = ref.read(authRepositoryProvider);
    try {
      final res = await repo.signUpVendor(
        businessName: business.text.trim(),
        ownerName: owner.text.trim(),
        businessPhone: businessPhone.text.trim(),
        momoNumber: momo.text.trim(),
        momoNetwork: momoNetwork,
        email: email.text.trim(),
        password: password.text,
        ghanaCardNumber: '',
        campusId: campusId!,
      );

      // Upload logo if session exists
      if (res.session != null && currentAuthUser != null && logo != null) {
        final logoUrl = await storage.upload(
          bucket: StorageService.businessLogos,
          bytes: logo!.bytes,
          fileName: logo!.name,
        );
        // Phase 5: update vendor logo via vendorRepository.updateStoreDetails
        await repo.createVendorRecord(
          businessName: business.text.trim(),
          ownerName: owner.text.trim(),
          businessPhone: businessPhone.text.trim(),
          momoNumber: momo.text.trim(),
          momoNetwork: momoNetwork,
          ghanaCardNumber: '', // v1.0 – KYC post-registration
          campusId: campusId!,
          logoUrl: logoUrl,
          ghanaCardImageUrl: null, // removed
        );
      }

      if (!mounted) return;
      ref.invalidate(currentUserProvider);
      snack(
        'Welcome! Complete your Seller Agreement to start selling.',
        success: true,
      );
      // v1.0 redirect: Seller Agreement gate, NOT /login
      context.go('/vendor/agreement');
    } catch (e) {
      snack(AppError.friendly(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void snack(String msg, {bool success = false}) {
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
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const InfoBannerV1(),
                    const SizedBox(height: AppSpacing.lg),

                    const SectionLabel('Business identity'),
                    const SizedBox(height: AppSpacing.sm + 4),
                    Center(
                      child: SizedBox(
                        width: 130,
                        child: ImageUploadField(
                          label: 'Logo (optional)',
                          icon: Icons.storefront_outlined,
                          height: 110,
                          circle: true,
                          onPicked: (p) => logo = p,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: business,
                      label: 'Business name',
                      hint: 'The shop name customers will see',
                      prefixIcon: AppIcons.storefront,
                      validator: (v) =>
                          Validators.required(v, 'Business name'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: owner,
                      label: 'Your full name',
                      prefixIcon: AppIcons.user,
                      validator: (v) => Validators.required(v, 'Owner name'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AsyncView<List<Campus>>(
                      value: campuses,
                      data: (list) => DropdownButtonFormField<String>(
                        value: campusId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Campus',
                          prefixIcon: Icon(AppIcons.campus, size: 20),
                        ),
                        items: list
                            .map((c) => DropdownMenuItem(
                            value: c.campusId, child: Text(c.campusName)))
                            .toList(),
                        onChanged: (v) => setState(() => campusId = v),
                        validator: (v) =>
                            v == null ? 'Please select your campus' : null,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    const SectionLabel('Business contact'),
                    const SizedBox(height: AppSpacing.sm + 4),
                    AppTextField(
                      controller: businessPhone,
                      label: 'Business phone number',
                      hint: 'Customers can contact your shop on this number',
                      prefixIcon: AppIcons.phoneBusiness,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: Validators.phone,
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    const SectionLabel('Mobile money (for payouts)'),
                    const SizedBox(height: AppSpacing.sm + 4),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final networkField = DropdownButtonFormField<String>(
                            value: momoNetwork,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Network',
                              prefixIcon: Icon(Icons.sim_card_outlined),
                            ),
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
                                setState(() => momoNetwork = v ?? 'MTN'),
                          );
                        final numberField = AppTextField(
                            controller: momo,
                            label: 'MoMo number',
                            prefixIcon: AppIcons.wallet,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            validator: Validators.momo,
                          );

                        if (constraints.maxWidth < 360) {
                          return Column(
                            children: [
                              networkField,
                              const SizedBox(height: AppSpacing.md),
                              numberField,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 150, child: networkField),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(child: numberField),
                          ],
                        );
                      },
                    ),

                    // REMOVED v1.0: Identity verification (Ghana Card) section
                    // → moved to /vendor/settings/verification post-registration

                    const SizedBox(height: AppSpacing.lg),
                    const SectionLabel('Account'),
                    const SizedBox(height: AppSpacing.sm + 4),
                    AppTextField(
                      controller: email,
                      label: 'Email',
                      prefixIcon: AppIcons.email,
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.email,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: password,
                      label: 'Password',
                      helper: '8+ chars, 1 number, 1 uppercase',
                      prefixIcon: AppIcons.lock,
                      obscureText: obscure,
                      suffixIcon: obscure ? AppIcons.eyeOff : AppIcons.eye,
                      onSuffixTap: () => setState(() => obscure = !obscure),
                      validator: Validators.password,
                    ),

                    const SizedBox(height: AppSpacing.md),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: agreeTerms,
                      onChanged: (v) => setState(() => agreeTerms = v ?? false),
                      title: const Text(
                        'I agree to the Seller Terms and Privacy Policy. The full Seller Agreement will be shown after sign-up.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: loading
                          ? 'Creating account…'
                          : 'Create Seller Account',
                      icon: loading ? null : AppIcons.shield,
                      loading: loading,
                      onPressed: submit,
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
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
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

class InfoBannerV1 extends StatelessWidget {
  const InfoBannerV1({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Icon(AppIcons.info, size: 20, color: scheme.onSecondaryContainer),
        const SizedBox(width: AppSpacing.sm + 2),
        Expanded(
          child: Text(
            'Create your shop with a business contact and payout number. '
                'You can complete ID verification later in Settings to unlock prepayment and the verified badge.',
            style: AppTextStyles.bodySmall
                .copyWith(color: scheme.onSecondaryContainer),
          ),
        ),
      ]),
    );
  }
}
