// lib/features/vendor/screens/service_form_screen.dart
// v1.0-2025-07 – Service Listing Form + Consent + Expiration Preview

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../../core/widgets/consent_dialog.dart';
import '../../../core/widgets/multi_image_field.dart';
import '../../../models/models.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/vendor_providers.dart';
import 'vendor_products_screen.dart';

/// E2b — Service Listing Form – v1.0 with consent + expiration
class ServiceFormScreen extends ConsumerStatefulWidget {
  final Service? service;
  const ServiceFormScreen({super.key, this.service});

  @override
  ConsumerState<ServiceFormScreen> createState() => ServiceFormScreenState();
}

class ServiceFormScreenState extends ConsumerState<ServiceFormScreen> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController title;
  late final TextEditingController description;
  late final TextEditingController price;
  late final TextEditingController availability;
  late final TextEditingController location;
  ServiceCategory category = ServiceCategory.hairGrooming;
  bool priceFrom = false;
  bool loading = false;

  final storage = StorageService();
  List<GalleryEntry> gallery = [];

  bool _consentChecked = false;

  bool get isEdit => widget.service != null;

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    title = TextEditingController(text: s?.title ?? '');
    description = TextEditingController(text: s?.description ?? '');
    price = TextEditingController(text: s != null ? '${s.price}' : '');
    availability = TextEditingController(text: s?.availability ?? '');
    location = TextEditingController(text: s?.location ?? '');
    category = s?.category ?? ServiceCategory.hairGrooming;
    priceFrom = s?.priceFrom ?? false;
    _consentChecked = isEdit; // already consented if editing
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    price.dispose();
    availability.dispose();
    location.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    final vendor = await ref.read(currentVendorProvider.future);
    if (vendor == null) return;
    if (!isEdit && !vendor.isVerified) {
      final products = await ref.read(myProductsProvider.future);
      final services = await ref.read(myServicesProvider.future);
      if (products.length + services.length >= 5) {
        if (mounted) {
          ConfirmActions.showError(context,
              'Identity verification is required to publish more than 5 listings. '
              'Submit your Ghana Card or Student ID and wait for admin approval.');
        }
        return;
      }
    }

    // v1.0 – consent dialog BEFORE confirm (new services only)
    if (!isEdit && !_consentChecked) {
      final consented = await showConsentDialog(
        context,
        type: ConsentType.servicePost,
        policyVersion: 'v2.0-2026-07',
        title: 'Service Listing Policy',
        bodyMarkdown: '''
Service Listing Policy - v2.0 - July 2026

- Your first 5 combined product and service listings do not require identity verification.
- An admin-approved Ghana Card or Student ID is required for listing 6 and beyond.
- Duration and authorization fees follow the current Platform Settings shown before posting.
- Authorization fees already consumed by a listing period are non-refundable.
- You are responsible for accurate descriptions, availability, pricing, and delivery.
- Prohibited: exam malpractice, alcohol to minors, illegal or unsafe services.
''',
        requiredCheckboxes: [
          'I agree to the Service Listing Policy v2.0',
          'I understand identity approval is required after 5 combined listings',
          'I accept the current duration and authorization terms shown in the app',
        ],
        scrollToAccept: true,
        ref: ref,
      );
      if (!consented) return;
      setState(() => _consentChecked = true);
    }

    final confirmed = await ConfirmActions.confirm(
      context,
      title: isEdit ? 'Save changes?' : 'Post service?',
      message: isEdit
          ? 'Update this service with your changes?'
          : 'Publish this service to your campus?',
      confirmLabel: isEdit ? 'Save' : 'Post service',
      icon: isEdit ? Icons.save_outlined : Icons.add_box_outlined,
    );
    if (!confirmed) return;

    setState(() => loading = true);
    try {
      final imageUrls = <String>[];
      for (final entry in gallery) {
        if (entry.isNew) {
          final url = await storage.upload(
            bucket: StorageService.productImages,
            bytes: entry.picked!.bytes,
            fileName: entry.picked!.name,
          );
          imageUrls.add(url);
        } else if (entry.url != null) {
          imageUrls.add(entry.url!);
        }
      }

      final now = DateTime.now();
      final expiresAt = widget.service?.expiresAt ?? now.add(const Duration(days: 14));

      final data = {
        'vendor_id': vendor.vendorId,
        'title': title.text.trim(),
        'description': description.text.trim(),
        'category': category.db,
        'price': double.tryParse(price.text.trim()) ?? 0,
        'price_from': priceFrom,
        'availability': availability.text.trim().isEmpty ? null : availability.text.trim(),
        'location': location.text.trim().isEmpty ? null : location.text.trim(),
        'expires_at': expiresAt.toIso8601String(),
        'consent_given': true,
        'consent_given_at': widget.service?.consentGivenAt?.toIso8601String() ?? now.toIso8601String(),
        'status': 'available',
      };

      final repo = ref.read(vendorRepositoryProvider);
      await repo.upsertService(
        data,
        serviceId: widget.service?.serviceId,
        imageUrls: imageUrls,
      );

      ref.invalidate(myServicesProvider);
      if (!mounted) return;

      if (isEdit) {
        Navigator.pop(context);
        ConfirmActions.toast(context, 'Service updated', success: true);
      } else {
        String? newId;
        try {
          final list = await ref.refresh(myServicesProvider.future);
          if (list.isNotEmpty) newId = list.first.serviceId;
        } catch (_) {}

        if (newId != null) {
          context.go('/vendor/services/posted/$newId');
        } else {
          context.pop();
          ConfirmActions.toast(context, 'Service posted', success: true);
        }
      }
    } catch (e) {
      if (mounted) ConfirmActions.showError(context, e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final platformAsync = ref.watch(platformSettingsProvider);
    final settings = platformAsync.valueOrNull;
    final authFee = settings?.serviceAuthFee ?? 30.0;
    final isFreeMode = settings?.isFreeMode ?? (authFee == 0);
    
    final expiresPreview = widget.service?.expiresAt ?? DateTime.now().add(const Duration(days: 14));

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Service' : 'Offer a Service')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppCard(
                      color: isFreeMode
                          ? Colors.green.withValues(alpha: 0.06)
                          : scheme.secondaryContainer.withValues(alpha: 0.5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isFreeMode ? Icons.all_inclusive : Icons.timer_outlined,
                            color: isFreeMode ? Colors.green.shade700 : scheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isFreeMode ? 'Free Mode Active' : '14-day listing period',
                                  style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isFreeMode
                                      ? 'Your service stays live with no time limit during launch.'
                                      : 'Expires: ${expiresPreview.day}/${expiresPreview.month}/${expiresPreview.year} • then authorize for 30 days.',
                                  style: AppTextStyles.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    MultiImageField(
                      initialUrls: widget.service?.gallery ?? const [],
                      onChanged: (entries) => gallery = entries,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: title,
                      label: 'Service Title',
                      hint: 'e.g., Professional Haircut & Fade',
                      prefixIcon: AppIcons.label,
                      validator: (v) => Validators.required(v, 'Title'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<ServiceCategory>(
                      value: category,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(AppIcons.services, size: 20),
                      ),
                      items: ServiceCategory.values
                          .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                          .toList(),
                      onChanged: (v) => setState(() => category = v ?? ServiceCategory.other),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: description,
                      label: 'Description',
                      hint: 'Describe your service and what\'s included',
                      maxLines: 4,
                      validator: (v) => Validators.required(v, 'Description'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: price,
                      label: 'Price (GH₵)',
                      prefixIcon: AppIcons.price,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        final d = double.tryParse((v ?? '').trim());
                        return (d == null || d < 0) ? 'Enter a valid price' : null;
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('"Starting from" pricing'),
                      subtitle: Text(
                          'Shows as "From ${Money.format(Money.parse(price.text) ?? 0)}"',
                          style: AppTextStyles.bodySmall),
                      value: priceFrom,
                      onChanged: (v) => setState(() => priceFrom = v),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      controller: availability,
                      label: 'Availability',
                      hint: 'e.g., Weekdays 4pm-8pm',
                      prefixIcon: AppIcons.clock,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: location,
                      label: 'Location',
                      hint: 'Campus location or your room number',
                      prefixIcon: AppIcons.mapPin,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: isEdit ? 'Save Changes' : 'Post Service',
                      icon: isEdit ? AppIcons.save : AppIcons.addBox,
                      loading: loading,
                      onPressed: save,
                    ),
                    const SizedBox(height: 24),
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
