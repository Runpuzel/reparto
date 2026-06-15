import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/storage_service.dart';

/// A tappable image field that lets the user pick a photo. It returns the
/// selected bytes (for later upload) via [onPicked] and previews the result.
///
/// Use [initialUrl] to show an existing remote image (edit flows).
class ImageUploadField extends StatefulWidget {
  final String label;
  final IconData icon;
  final String? initialUrl;
  final double height;
  final bool circle;
  final void Function(PickedImage? picked) onPicked;

  const ImageUploadField({
    super.key,
    required this.label,
    required this.onPicked,
    this.icon = Icons.add_photo_alternate_outlined,
    this.initialUrl,
    this.height = 160,
    this.circle = false,
  });

  @override
  State<ImageUploadField> createState() => _ImageUploadFieldState();
}

class _ImageUploadFieldState extends State<ImageUploadField> {
  final _storage = StorageService();
  Uint8List? _preview;
  bool _busy = false;

  Future<void> _pick(bool camera) async {
    setState(() => _busy = true);
    try {
      final picked = await _storage.pickImage(fromCamera: camera);
      if (picked != null) {
        setState(() => _preview = picked.bytes);
        widget.onPicked(picked);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _chooseSource() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(true);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = widget.circle
        ? BorderRadius.circular(widget.height)
        : BorderRadius.circular(16);

    Widget content;
    if (_preview != null) {
      content = Image.memory(_preview!, fit: BoxFit.cover);
    } else if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      content = Image.network(widget.initialUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(scheme));
    } else {
      content = _placeholder(scheme);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: radius,
          onTap: _busy ? null : _chooseSource,
          child: Container(
            height: widget.height,
            width: widget.circle ? widget.height : double.infinity,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: radius,
              border: Border.all(
                  color: scheme.outlineVariant, style: BorderStyle.solid),
            ),
            clipBehavior: Clip.antiAlias,
            child: _busy
                ? const Center(child: CircularProgressIndicator())
                : content,
          ),
        ),
      ],
    );
  }

  Widget _placeholder(ColorScheme scheme) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(widget.icon, size: 34, color: scheme.onSurfaceVariant),
        const SizedBox(height: 6),
        Text('Tap to upload',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
      ],
    ),
  );
}
