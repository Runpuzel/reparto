import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/commission.dart';
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
  late final TextEditingController _price;
  late final TextEditingController _quantity;
  String? _categoryId;
  bool _loading = false;

  final _storage = StorageService();
  List<GalleryEntry> _gallery = [];

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.productName ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _price = TextEditingController(text: p != null ? '${p.price}' : '');
    _quantity =
        TextEditingController(text: p != null ? '${p.quantityAvailable}' : '');
    _categoryId = p?.categoryId;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final confirmed = await ConfirmActions.confirm(
      context,
      title: _isEdit ? 'Save changes?' : 'Add product?',
      message: _isEdit
          ? 'Update this product with your changes?'
          : 'Publish this product to your shop?',
      confirmLabel: _isEdit ? 'Save' : 'Add product',
      icon: _isEdit ? Icons.save_outlined : Icons.add_box_outlined,
    );
    if (!confirmed) return;
    final vendor = await ref.read(currentVendorProvider.future);
    if (vendor == null) return;
    setState(() => _loading = true);
    try {
      // Upload any newly-picked images, preserving order. Existing URLs are
      // kept as-is so we don't re-upload unchanged photos.
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
        'price': double.tryParse(_price.text.trim()) ?? 0,
        'quantity_available': int.tryParse(_quantity.text.trim()) ?? 0,
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

  /// Live "Platform fee for this price" line under the price field (spec E2a).
  Widget _liveFee() {
    final scheme = Theme.of(context).colorScheme;
    final pesewas = Money.parse(_price.text) ?? 0;
    final tiers =
        ref.watch(commissionTiersProvider).valueOrNull ?? Commission.defaults;
    final campusId = ref.watch(currentUserProvider).valueOrNull?.campusId;
    final fee = Commission.forPrice(pesewas, campusId: campusId, tiers: tiers);
    return Row(
      children: [
        Icon(AppIcons.info, size: 15, color: scheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs + 2),
        Expanded(
          child: Text(
            pesewas <= 0
                ? 'Free items have no platform fee.'
                : 'Platform fee for this price: ${Money.format(fee)}',
            style: AppTextStyles.bodySmall,
          ),
        ),
      ],
    );
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
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            final d = double.tryParse(v ?? '');
                            return (d == null || d < 0)
                                ? 'Enter a valid price'
                                : null;
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
                            return (n == null || n < 0)
                                ? 'Enter a quantity'
                                : null;
                          },
                        ),
                      ),
                    ]),
                    const SizedBox(height: AppSpacing.sm),
                    _liveFee(),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _description,
                      label: 'Description (optional)',
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
