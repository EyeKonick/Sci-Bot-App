import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Utility class for image processing operations
/// Handles picking, resizing, cropping, and saving profile pictures
class ImageUtils {
  ImageUtils._();

  static final ImagePicker _picker = ImagePicker();

  /// Pick image from camera
  /// Returns null if user cancels or if camera is unavailable
  static Future<File?> pickImageFromCamera() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );

      if (pickedFile == null) return null;
      return File(pickedFile.path);
    } catch (e) {
      if (kDebugMode) debugPrint('Error picking image from camera: $e');
      return null;
    }
  }

  /// Pick image from gallery
  /// Returns null if user cancels
  static Future<File?> pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );

      if (pickedFile == null) return null;
      return File(pickedFile.path);
    } catch (e) {
      if (kDebugMode) debugPrint('Error picking image from gallery: $e');
      return null;
    }
  }

  /// Resize and crop image to 300x300 square
  /// Crops to center square first, then resizes
  /// Returns processed image file
  static Future<File?> resizeAndCropImage(File imageFile) async {
    try {
      // Read image from file
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);

      if (image == null) {
        if (kDebugMode) debugPrint('Could not decode image');
        return null;
      }

      // Crop to square (center crop)
      final size = image.width < image.height ? image.width : image.height;
      final offsetX = (image.width - size) ~/ 2;
      final offsetY = (image.height - size) ~/ 2;

      img.Image cropped = img.copyCrop(
        image,
        x: offsetX,
        y: offsetY,
        width: size,
        height: size,
      );

      // Resize to 300x300
      img.Image resized = img.copyResize(
        cropped,
        width: 300,
        height: 300,
        interpolation: img.Interpolation.average,
      );

      // Convert to JPEG with 85% quality
      final List<int> jpeg = img.encodeJpg(resized, quality: 85);

      // Write to temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(jpeg);

      return tempFile;
    } catch (e) {
      if (kDebugMode) debugPrint('Error resizing and cropping image: $e');
      return null;
    }
  }

  /// Save profile image to app documents directory
  /// Deletes any existing profile picture first
  /// Returns path to saved image
  static Future<String?> saveProfileImage(File imageFile) async {
    try {
      // Get app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final profileImagesDir = Directory('${appDir.path}/profile_images');

      // Create directory if it doesn't exist
      if (!await profileImagesDir.exists()) {
        await profileImagesDir.create(recursive: true);
      }

      // Delete existing profile picture if it exists
      final existingFile = File('${profileImagesDir.path}/profile_picture.jpg');
      if (await existingFile.exists()) {
        await existingFile.delete();
      }

      // Copy new image to profile directory
      final savedFile = File('${profileImagesDir.path}/profile_picture.jpg');
      await imageFile.copy(savedFile.path);

      return savedFile.path;
    } catch (e) {
      if (kDebugMode) debugPrint('Error saving profile image: $e');
      return null;
    }
  }

  /// Delete profile image from storage
  static Future<void> deleteProfileImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error deleting profile image: $e');
    }
  }

  /// Process and save profile image (combined operation)
  /// Picks, resizes, crops, and saves in one call
  /// Returns path to saved image or null on error
  static Future<String?> processAndSaveProfileImage(File imageFile) async {
    try {
      // Resize and crop
      final processedFile = await resizeAndCropImage(imageFile);
      if (processedFile == null) return null;

      // Save to app directory
      final savedPath = await saveProfileImage(processedFile);

      // Clean up temporary file
      if (await processedFile.exists()) {
        await processedFile.delete();
      }

      return savedPath;
    } catch (e) {
      if (kDebugMode) debugPrint('Error processing and saving profile image: $e');
      return null;
    }
  }

  /// Get file size in KB
  static Future<double> getFileSizeKB(File file) async {
    final bytes = await file.length();
    return bytes / 1024;
  }

  /// Check if file exists at path
  static Future<bool> fileExists(String path) async {
    try {
      return await File(path).exists();
    } catch (e) {
      return false;
    }
  }
}
