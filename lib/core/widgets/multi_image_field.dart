import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/storage_service.dart';

/// One entry in the gallery editor: either an already-uploaded URL or a
/// freshly-picked image awaiting upload.
class GalleryEntry {
  final String? url; // existing remote image
  final PickedImage? picked; // newly chosen image
  GalleryEntry.url(this.url) : picked = null;
  GalleryEntry.picked(this.picked) : url = null;

  bool get isNew => picked != null;
}

/// A horizontal, reorderable-by-removal gallery editor that supports multiple
/// product images. The first image is treated as the cover.
class MultiImageField extends StatefulWidget {
  final List<String> initialUrls;
  final int maxImages;
  final ValueChanged<List<GalleryEntry>> onChanged;

  const MultiImageField({
    super.key,
    this.initialUrls = const [],
    this.maxImages = 6,
    required this.onChanged,
  });

  @override
  State<MultiImageField> createState() => _MultiImageFieldState();
}

class _MultiImageFieldState extends State<MultiImageField> {
  final _storage = StorageService();
  late List<GalleryEntry> _entries;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _entries = widget.initialUrls.map((u) => GalleryEntry.url(u)).toList();
  }

  void _emit() => widget.onChanged(_entries);

  Future<void> _add(bool camera) async {
    setState(() => _busy = true);
    try {
      final picked = await _storage.pickImage(fromCamera: camera);
      if (picked != null) {
        setState(() => _entries.add(GalleryEntry.picked(picked)));
        _emit();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _remove(int index) {
    setState(() => _entries.removeAt(index));
    _emit();
  }

  void _makeCover(int index) {
    if (index == 0) return;
    setState(() {
      final e = _entries.removeAt(index);
      _entries.insert(0, e);
    });
    _emit();
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
                _add(false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _add(true);
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
    final canAdd = _entries.length < widget.maxImages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Product photos',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(width: 8),
            Text('${_entries.length}/${widget.maxImages}',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 104,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < _entries.length; i++)
                _thumb(i, _entries[i], scheme),
              if (canAdd)
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _busy ? null : _chooseSource,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: _busy
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined,
                            color: scheme.onSurfaceVariant),
                        const SizedBox(height: 4),
                        Text('Add',
                            style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text('Tap an image to make it the cover. First image is the cover.',
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _thumb(int index, GalleryEntry e, ColorScheme scheme) {
    final isCover = index == 0;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => _makeCover(index),
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCover ? scheme.primary : scheme.outlineVariant,
                  width: isCover ? 2.4 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: e.isNew
                  ? Image.memory(e.picked!.bytes, fit: BoxFit.cover)
                  : Image.network(e.url!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                  const Icon(Icons.broken_image)),
            ),
          ),
          if (isCover)
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Cover',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          Positioned(
            right: 2,
            top: 2,
            child: GestureDetector(
              onTap: () => _remove(index),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(3),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
