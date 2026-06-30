import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Worker function that runs in a background Isolate
Uint8List _compressImageWorker(Map<String, dynamic> params) {
  final Uint8List bytes = params['bytes'];
  final int targetSize = params['targetSize'];
  final bool isPng = params['isPng'] ?? false;

  img.Image? decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;

  img.Image resized = decoded;
  if (decoded.width > targetSize || decoded.height > targetSize) {
    if (decoded.width > decoded.height) {
      resized = img.copyResize(decoded, width: targetSize);
    } else {
      resized = img.copyResize(decoded, height: targetSize);
    }
  }

  if (isPng) {
    // Encode as PNG with maximum compression (level 9) to keep transparency
    return Uint8List.fromList(img.encodePng(resized, level: 9));
  } else {
    // Encode as JPG with 80% quality
    return Uint8List.fromList(img.encodeJpg(resized, quality: 80));
  }
}

class ImageCompressionHelper {
  /// Compress image file (JPEG or PNG) if it exceeds target size (default 500 KB)
  static Future<File> compressIfNeeded(
    File file, {
    int maxSizeInBytes = 500 * 1024,
    int targetDimension = 800,
  }) async {
    try {
      final int fileSize = await file.length();
      if (fileSize <= maxSizeInBytes) {
        return file; // Already small enough, no compression needed
      }

      final String path = file.path.toLowerCase();
      final bool isPng = path.endsWith('.png');

      debugPrint(
        'Compressing file: ${file.path} (${(fileSize / 1024).toStringAsFixed(1)} KB)',
      );
      final Uint8List bytes = await file.readAsBytes();

      final Uint8List compressedBytes = await compute(_compressImageWorker, {
        'bytes': bytes,
        'targetSize': targetDimension,
        'isPng': isPng,
      });

      final String extension = isPng ? 'png' : 'jpg';
      final tempFile = File(
        '${Directory.systemTemp.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.$extension',
      );
      await tempFile.writeAsBytes(compressedBytes);

      debugPrint(
        'Compression finished: ${tempFile.path} (${(compressedBytes.length / 1024).toStringAsFixed(1)} KB)',
      );
      return tempFile;
    } catch (e) {
      debugPrint('Error in ImageCompressionHelper: $e');
      return file; // Fallback to original file
    }
  }
}
