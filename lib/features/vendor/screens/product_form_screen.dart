import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/storage_service.dart';
import '../../../core/utils/validators.dart';
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

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Product' : 'Add Product')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
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
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                          labelText: 'Product Name',
                          prefixIcon: Icon(Icons.label_outline)),
                      validator: (v) => Validators.required(v, 'Name'),
                    ),
                    const SizedBox(height: 14),
                    AsyncView<List<Category>>(
                      value: categories,
                      data: (cats) => DropdownButtonFormField<String>(
                        value: _categoryId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Category',
                            prefixIcon: Icon(Icons.category_outlined)),
                        items: cats
                            .map((c) => DropdownMenuItem(
                            value: c.categoryId,
                            child: Text(c.categoryName)))
                            .toList(),
                        onChanged: (v) => setState(() => _categoryId = v),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: _price,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Price',
                              prefixIcon: Icon(Icons.attach_money)),
                          validator: (v) {
                            final d = double.tryParse(v ?? '');
                            return (d == null || d < 0)
                                ? 'Enter a valid price'
                                : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _quantity,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Quantity',
                              prefixIcon: Icon(Icons.numbers)),
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            return (n == null || n < 0)
                                ? 'Enter a quantity'
                                : null;
                          },
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _description,
                      maxLines: 4,
                      decoration: const InputDecoration(
                          labelText: 'Description (optional)',
                          alignLabelWithHint: true),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _save,
                      child: _loading
                          ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white))
                          : Text(_isEdit ? 'Save Changes' : 'Add Product'),
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
