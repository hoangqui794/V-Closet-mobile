import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'api_service.dart';

class BgRemovalService {
  final ApiService _apiService;

  BgRemovalService(this._apiService);

  /// Removes the background of an image using the backend API.
  /// Returns the image bytes (PNG) if successful, or null if it fails.
  Future<Uint8List?> removeBackground(File imageFile) async {
    try {
      String fileName = imageFile.path.split(Platform.pathSeparator).last;
      
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(
          imageFile.path,
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
