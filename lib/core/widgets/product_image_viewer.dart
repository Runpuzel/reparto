import 'package:flutter/material.dart';

import 'app_network_image.dart';

Future<void> showProductImage(
  BuildContext context, {
  required String? imageUrl,
  required String productName,
}) async {
  if (imageUrl == null || imageUrl.isEmpty) return;

  await showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (context) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: SizedBox.expand(
                  child: AppNetworkImage(
                    url: imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Close image',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class OrderProductThumbnail extends StatelessWidget {
  const OrderProductThumbnail({
    super.key,
    required this.imageUrl,
    required this.productName,
    this.size = 44,
    this.borderRadius = 6,
  });

  final String? imageUrl;
  final String productName;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final canOpen = imageUrl != null && imageUrl!.isNotEmpty;
    return Tooltip(
      message: canOpen ? 'View full image' : 'No product image',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: canOpen
              ? () => showProductImage(
                    context,
                    imageUrl: imageUrl,
                    productName: productName,
                  )
              : null,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppNetworkImage(url: imageUrl, iconSize: size * 0.45),
                if (canOpen)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      margin: const EdgeInsets.all(3),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.zoom_in,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
