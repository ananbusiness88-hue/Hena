import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImageUploadService {
  ImageUploadService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String storeImagesBucket = 'store-images';
  static const String productImagesBucket = 'product-images';

  Future<String> uploadStoreImage({
    required XFile file,
    required String storeId,
    required String imageType,
  }) {
    return _upload(
      bucket: storeImagesBucket,
      file: file,
      folder: storeId,
      imageType: imageType,
    );
  }

  Future<String> uploadProductImage({
    required XFile file,
    required String productId,
  }) {
    return _upload(
      bucket: productImagesBucket,
      file: file,
      folder: productId,
      imageType: 'main',
    );
  }

  Future<String> _upload({
    required String bucket,
    required XFile file,
    required String folder,
    required String imageType,
  }) async {
    final Uint8List bytes = await file.readAsBytes();

    if (bytes.isEmpty) {
      throw const FormatException('Selected image is empty.');
    }

    final extension = _extension(file.name);
    final contentType = _contentType(extension);
    final path = '$folder/$imageType.$extension';

    await _client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            cacheControl: '3600',
            contentType: contentType,
            upsert: true,
          ),
        );

    return _client.storage.from(bucket).getPublicUrl(path);
  }

  String _extension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');

    if (dotIndex == -1 || dotIndex == fileName.length - 1) {
      return 'jpg';
    }

    final extension = fileName.substring(dotIndex + 1).toLowerCase();

    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'jpg';
      case 'png':
        return 'png';
      case 'webp':
        return 'webp';
      default:
        throw FormatException(
          'Unsupported image format: .$extension. Use JPG, PNG, or WEBP.',
        );
    }
  }

  String _contentType(String extension) {
    switch (extension) {
      case 'jpg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        throw FormatException('Unsupported image format: .$extension.');
    }
  }
}