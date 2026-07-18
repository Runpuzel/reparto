import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/listing_policy.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../../core/widgets/multi_image_field.dart';
import '../../../models/models.dart';
import '../../auth/providers/auth_providers.dart';
import '../../shared/providers/shared_providers.dart';
import '../providers/vendor_providers.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final Product? product;
  const ProductFormScreen({super.key, this.product});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _brand;
  late final TextEditingController _specifications;
  String _condition = 'new';
  late final TextEditingController _price;
  late final TextEditingController _quantity;
  String? _categoryId;
  bool _loading = false;

  final _storage = StorageService();
  List<GalleryEntry> _gallery = [];

  bool get _isEdit => widget.product != null;

  int get _pricePesewas => Money.parse(_price.text.trim()) ?? 0;

  int _feePesewas(PlatformSetting settings) =>
      (_pricePesewas * settings.platformFeeSellerPercent / 100).round();

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.productName ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _brand = TextEditingController(text: p?.brand ?? '');
    _specifications = TextEditingController(text: p?.specifications ?? '');
    _condition = p?.itemCondition ?? 'new';
    _price = TextEditingController(text: p != null ? '${p.price}' : '');
    _quantity = TextEditingController(text: p != null ? '${p.quantityAvailable}' : '');
    _categoryId = p?.categoryId;
    
    // Initialize gallery with existing URLs
    if (p != null) {
      _gallery = p.gallery.map((u) => GalleryEntry.url(u)).toList();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _brand.dispose();
    _specifications.dispose();
    _price.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final settings = await ref.read(marketplaceSettingsProvider.future);
    final fee = _feePesewas(settings);
    final earnings = (_pricePesewas - fee).clamp(0, _pricePesewas);
    
    final confirmed = await ConfirmActions.confirm(
      context,
      title: _isEdit ? 'Save changes?' : 'Add product?',
      message: _isEdit
          ? 'Update this product?\n\nAdmin deduction per sale: ${Money.format(fee)}\nYour earnings per sale: ${Money.format(earnings)}'
          : 'Publish this product to your shop?\n\nAdmin deduction per sale: ${Money.format(fee)}\nYour earnings per sale: ${Money.format(earnings)}',
      confirmLabel: _isEdit ? 'Save' : 'Add product',
      icon: _isEdit ? Icons.save_outlined : Icons.add_box_outlined,
    );
    if (!confirmed) return;

    final vendor = await ref.read(currentVendorProvider.future);
    if (vendor == null) return;
    if (!_isEdit && !vendor.isVerified) {
      final products = await ref.read(myProductsProvider.future);
      final services = await ref.read(myServicesProvider.future);
      if (products.length + services.length >= unverifiedListingLimit) {
        if (mounted) {
          ConfirmActions.showError(context,
              'Identity verification is required to publish more than $unverifiedListingLimit listings. '
              'Submit your Student ID and wait for admin approval.');
        }
        return;
      }
    }
    
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
        'category_id': _categoryId,
        'product_name': _name.text.trim(),
        'description': _description.text.trim(),
        'brand': _brand.text.trim().isEmpty ? null : _brand.text.trim(),
        'item_condition': _condition,
        'specifications': _specifications.text.trim().isEmpty
            ? null : _specifications.text.trim(),
        'price': double.tryParse(_price.text.trim()) ?? 0,
        'quantity_available': int.tryParse(_quantity.text.trim()) ?? 0,
        'image_url': imageUrls.isNotEmpty ? imageUrls.first : null,
      };

      await ref.read(vendorRepositoryProvider).upsertProduct(
        data,
        productId: widget.product?.productId,
        imageUrls: imageUrls,
      );

      ref.invalidate(myProductsProvider);
      if (mounted) {
        Navigator.pop(context);
        ConfirmActions.toast(
            context, _isEdit ? 'Product updated' : 'Product added',
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
    final categories = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Product' : 'Add Product')),
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
                      initialUrls: widget.product?.gallery ?? const [],
                      onChanged: (entries) => _gallery = entries,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _name,
                      label: 'Product Name',
                      prefixIcon: AppIcons.label,
                      validator: (v) => Validators.required(v, 'Name'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AsyncView<List<Category>>(
                      value: categories,
                      data: (cats) => DropdownButtonFormField<String>(
                        value: _categoryId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(AppIcons.category, size: 20),
                        ),
                        items: cats
                            .map((c) => DropdownMenuItem(
                            value: c.categoryId,
                            child: Text(c.categoryName)))
                            .toList(),
                        onChanged: (v) => setState(() => _categoryId = v),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(children: [
                      Expanded(
                        child: AppTextField(
                          controller: _price,
                          label: 'Price',
                          prefixIcon: AppIcons.price,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            final d = double.tryParse(v ?? '');
                            return (d == null || d < 0) ? 'Enter a valid price' : null;
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm + 4),
                      Expanded(
                        child: AppTextField(
                          controller: _quantity,
                          label: 'Quantity',
                          prefixIcon: AppIcons.numbers,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            return (n == null || n < 0) ? 'Enter a quantity' : null;
                          },
                        ),
                      ),
                    ]),
                    const SizedBox(height: AppSpacing.md),
                    Consumer(builder: (context, ref, _) {
                      final settings = ref.watch(marketplaceSettingsProvider);
                      return AsyncView<PlatformSetting>(
                        value: settings,
                        data: (value) {
                          final fee = _feePesewas(value);
                          final earnings =
                              (_pricePesewas - fee).clamp(0, _pricePesewas);
                          return Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('Earnings per sale',
                                    style: AppTextStyles.titleSmall),
                                const SizedBox(height: AppSpacing.sm),
                                Text('Admin deduction (${value.platformFeeSellerPercent.toStringAsFixed(1)}%): ${Money.format(fee)}'),
                                const SizedBox(height: 4),
                                Text('You receive: ${Money.format(earnings)}',
                                    style: AppTextStyles.titleSmall.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary)),
                              ],
                            ),
                          );
                        },
                      );
                    }),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _description,
                      label: 'Description (optional)',
                      maxLines: 4,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _brand,
                      label: 'Brand (optional)',
                      prefixIcon: Icons.branding_watermark_outlined,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      value: _condition,
                      decoration: const InputDecoration(
                          labelText: 'Condition',
                          prefixIcon: Icon(Icons.verified_outlined)),
                      items: const [
                        DropdownMenuItem(value: 'new', child: Text('New')),
                        DropdownMenuItem(value: 'used_like_new', child: Text('Used – like new')),
                        DropdownMenuItem(value: 'used_good', child: Text('Used – good')),
                        DropdownMenuItem(value: 'used_fair', child: Text('Used – fair')),
                      ],
                      onChanged: (v) => setState(() => _condition = v ?? 'new'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _specifications,
                      label: 'More details (size, colour, model, etc.)',
                      maxLines: 4,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: _isEdit ? 'Save Changes' : 'Add Product',
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
