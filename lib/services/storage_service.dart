import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class StorageService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Uuid _uuid = Uuid();

  static const String _productImagesBucket = 'product-images';

  Future<String?> uploadProductImage(File imageFile, String productId) async {
    try {
      // Generate unique filename
      final fileExtension = path.extension(imageFile.path);
      final fileName = '${productId}_${_uuid.v4()}$fileExtension';

      // Upload to Supabase storage
      final response = await _supabase.storage
          .from(_productImagesBucket)
          .upload(fileName, imageFile);

      if (response.isEmpty) {
        throw Exception('Upload failed - no response');
      }

      // Get public URL
      final publicUrl = _supabase.storage
          .from(_productImagesBucket)
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      print('Error uploading product image: $e');
      return null;
    }
  }

  Future<bool> deleteProductImage(String imageUrl) async {
    try {
      // Extract filename from URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      final fileName = pathSegments.last;

      // Delete from Supabase storage
      await _supabase.storage.from(_productImagesBucket).remove([fileName]);

      return true;
    } catch (e) {
      print('Error deleting product image: $e');
      return false;
    }
  }

  Future<bool> updateProductImage(
    String oldImageUrl,
    File newImageFile,
    String productId,
  ) async {
    try {
      // Delete old image if exists
      if (oldImageUrl.isNotEmpty) {
        await deleteProductImage(oldImageUrl);
      }

      // Upload new image
      final newImageUrl = await uploadProductImage(newImageFile, productId);
      return newImageUrl != null;
    } catch (e) {
      print('Error updating product image: $e');
      return false;
    }
  }

  Future<List<String>> listProductImages() async {
    try {
      final response = await _supabase.storage
          .from(_productImagesBucket)
          .list();

      return response.map((file) => file.name).toList();
    } catch (e) {
      print('Error listing product images: $e');
      return [];
    }
  }

  String? getImageUrlFromPath(String imagePath) {
    if (imagePath.isEmpty) return null;

    // If it's already a full URL, return as is
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }

    // Otherwise, construct the full URL
    return _supabase.storage.from(_productImagesBucket).getPublicUrl(imagePath);
  }
}
