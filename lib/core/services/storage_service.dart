import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_client.dart';

/// Handles image selection + upload to Supabase Storage.
///
/// Files are stored under `<uid>/<timestamp>.<ext>` so the storage RLS policies
/// (which key on the first folder segment) grant the owner write access.
class StorageService {
  static const String productImages = 'product-images';
  static const String businessLogos = 'business-logos';
  static const String kycDocuments = 'kyc-documents';

  final ImagePicker _picker = ImagePicker();

  /// Pick an image from gallery (or camera) and return its bytes + name.
  Future<PickedImage?> pickImage({bool fromCamera = false}) async {
    final XFile? file = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1280,
      imageQuality: 82,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return PickedImage(bytes: bytes, name: file.name);
  }

  String _ext(String name) {
    final i = name.lastIndexOf('.');
    return i == -1 ? 'jpg' : name.substring(i + 1).toLowerCase();
  }

  /// Upload bytes to [bucket]; returns a public URL (public buckets) or the
  /// storage path (private buckets like KYC).
  Future<String> upload({
    required String bucket,
    required Uint8List bytes,
    required String fileName,
    bool publicUrl = true,
  }) async {
    final uid = currentAuthUser!.id;
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.${_ext(fileName)}';

    await supabase.storage.from(bucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: 'image/${_ext(fileName) == 'png' ? 'png' : 'jpeg'}',
        upsert: true,
      ),
    );

    if (publicUrl) {
      return supabase.storage.from(bucket).getPublicUrl(path);
    }
    return path; // private: store the path, fetch via signed URL when needed
  }

  /// Create a temporary signed URL for a private object (e.g. KYC image).
  Future<String> signedUrl(String bucket, String path,
      {int expiresIn = 3600}) async {
    return supabase.storage.from(bucket).createSignedUrl(path, expiresIn);
  }
}

class PickedImage {
  final Uint8List bytes;
  final String name;
  PickedImage({required this.bytes, required this.name});
}
