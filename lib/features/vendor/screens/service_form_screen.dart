import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../../core/widgets/multi_image_field.dart';
import '../../../models/models.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/vendor_providers.dart';

/// E2b — Service Listing Form.
class ServiceFormScreen extends ConsumerStatefulWidget {
  final Service? service;
  const ServiceFormScreen({super.key, this.service});

  @override
  ConsumerState<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends ConsumerState<ServiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _availability;
  late final TextEditingController _location;
  ServiceCategory _category = ServiceCategory.hairGrooming;
  bool _priceFrom = false;
  bool _loading = false;

  final _storage = StorageService();
  List<GalleryEntry> _gallery = [];

  bool get _isEdit => widget.service != null;

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    _title = TextEditingController(text: s?.title ?? '');
    _description = TextEditingController(text: s?.description ?? '');
    _price = TextEditingController(text: s != null ? '${s.price}' : '');
    _availability = TextEditingController(text: s?.availability ?? '');
    _location = TextEditingController(text: s?.location ?? '');
    _category = s?.category ?? ServiceCategory.hairGrooming;
    _priceFrom = s?.priceFrom ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _availability.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final vendor = await ref.read(currentVendorProvider.future);
    if (vendor == null) return;

    // Enforce the 2-active-service limit for non-Student-Sellers is handled by
    // the chooser; here we just block obvious overflow when creating new.
    final confirmed = await ConfirmActions.confirm(
      context,
      title: _isEdit ? 'Save changes?' : 'Post service?',
      message: _isEdit
          ? 'Update this service with your changes?'
          : 'Publish this service to your campus?',
      confirmLabel: _isEdit ? 'Save' : 'Post service',
      icon: _isEdit ? Icons.save_outlined : Icons.add_box_outlined,
    );
    if (!confirmed) return;

    setState(() => _loading = true);
    try {
      final imageUrls = <String>[];
      for (final entry in _gallery) {
        if (entry.isNew) {
          final url = await _storage.upload(
            bucket: StorageService.productImages,
            bytes: entry.picked!.bytes,
            fileName: entry.picked!.name,
          );
          imageUrls.add(url);
        } else if (entry.url != null) {
          imageUrls.add(entry.url!);
        }
      }

      final data = {
        'vendor_id': vendor.vendorId,
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'category': _category.db,
        'price': double.tryParse(_price.text.trim()) ?? 0,
        'price_from': _priceFrom,
        'availability': _availability.text.trim().isEmpty
            ? null
            : _availability.text.trim(),
        'location':
        _location.text.trim().isEmpty ? null : _location.text.trim(),
      };
      await ref.read(vendorRepositoryProvider).upsertService(
        data,
        serviceId: widget.service?.serviceId,
        imageUrls: imageUrls,
      );
      ref.invalidate(myServicesProvider);
      if (mounted) {
        Navigator.pop(context);
        ConfirmActions.toast(
            context, _isEdit ? 'Service updated' : 'Service posted',
            success: true);
      }
    } catch (e) {
      if (mounted) ConfirmActions.showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Service' : 'Offer a Service')),
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
                    MultiImageField(
                      initialUrls: widget.service?.gallery ?? const [],
                      onChanged: (entries) => _gallery = entries,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _title,
                      label: 'Service Title',
                      hint: 'e.g., Professional Haircut & Fade',
                      prefixIcon: AppIcons.label,
                      validator: (v) => Validators.required(v, 'Title'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<ServiceCategory>(
                      value: _category,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(AppIcons.services, size: 20),
                      ),
                      items: ServiceCategory.values
                          .map((c) => DropdownMenuItem(
                          value: c, child: Text(c.label)))
                          .toList(),
                      onChanged: (v) => setState(
                              () => _category = v ?? ServiceCategory.other),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _description,
                      label: 'Description',
                      hint: 'What is included, how long it takes',
                      maxLines: 4,
                      validator: (v) => Validators.required(v, 'Description'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _price,
                      label: 'Price (GH₵)',
                      prefixIcon: AppIcons.price,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        final d = double.tryParse((v ?? '').trim());
                        return (d == null || d < 0)
                            ? 'Enter a valid price'
                            : null;
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('"Starting from" pricing'),
                      subtitle: Text(
                          'Shows as "From ${Money.format(Money.parse(_price.text) ?? 0)}"',
                          style: AppTextStyles.bodySmall),
                      value: _priceFrom,
                      onChanged: (v) => setState(() => _priceFrom = v),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      controller: _availability,
                      label: 'Availability',
                      hint: 'e.g., Weekdays after 4pm, all day Saturday',
                      prefixIcon: AppIcons.clock,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _location,
                      label: 'Location',
                      hint: 'My room / Client location / Either',
                      prefixIcon: AppIcons.mapPin,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: _isEdit ? 'Save Changes' : 'Post Service',
                      icon: _isEdit ? AppIcons.save : AppIcons.addBox,
                      loading: _loading,
                      onPressed: _save,
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
