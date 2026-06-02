import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'api_service.dart';

// Top-level worker function to compress image in isolate background
Uint8List _compressImageInIsolate(Map<String, dynamic> params) {
  final Uint8List bytes = params['bytes'];
  final int targetSize = params['targetSize'];
  
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
  
  return Uint8List.fromList(img.encodeJpg(resized, quality: 80));
}

class BgRemovalService {
  final ApiService _apiService;

  BgRemovalService(this._apiService);

  /// Removes the background of an image using the backend API.
  /// Returns the image bytes (PNG) if successful, or null if it fails.
  Future<Uint8List?> removeBackground(File imageFile) async {
    try {
      File fileToUse = imageFile;
      
      // Auto-compress large files (> 1MB) to prevent HTTP 413 (Payload Too Large)
      final int fileSize = await imageFile.length();
      if (fileSize > 1 * 1024 * 1024) {
        debugPrint('Tệp ảnh lớn (${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB), đang nén tự động...');
        final bytes = await imageFile.readAsBytes();
        final compressedBytes = await compute(_compressImageInIsolate, {
          'bytes': bytes,
          'targetSize': 1024,
        });
        
        final tempFile = File('${Directory.systemTemp.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await tempFile.writeAsBytes(compressedBytes);
        fileToUse = tempFile;
        debugPrint('Đã nén xong: ${(compressedBytes.length / 1024).toStringAsFixed(2)} KB');
      }

      String fileName = fileToUse.path.split(Platform.pathSeparator).last;
      
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(
          fileToUse.path,
          filename: fileName,
        ),
      });

      // Backend route is /api/Wardrobe/remove-bg
      // ApiService baseUrl should already include /api
      Response response = await _apiService.post(
        '/api/Wardrobe/remove-bg',
        data: formData,
        options: Options(
          responseType: ResponseType.bytes, // Get raw bytes for the image
          receiveTimeout: const Duration(seconds: 60), // Processing may take time
        ),
      );

      // Clean up temp file if created
      if (fileToUse.path != imageFile.path) {
        try {
          await fileToUse.delete();
        } catch (e) {
          debugPrint('Không thể xóa tệp tạm: $e');
        }
      }

      if (response.statusCode == 200) {
        return response.data as Uint8List;
      } else {
        print('Failed to remove background. Status Code: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error calling remove-bg API: $e');
      return null;
    }
  }
}
