import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class TryOnApiService {
  final ApiService _apiService;

  TryOnApiService(this._apiService);

  /// Chạy thử đồ ảo bằng cách truyền trực tiếp URLs ảnh.
  /// Trả về predictionId nếu thành công, hoặc null nếu lỗi.
  Future<String?> runTryOnWithUrls({
    required String modelUrl,
    required String garmentUrl,
    String category = 'auto',
    bool restoreBackground = true,
  }) async {
    try {
      final response = await _apiService.post(
        '/TryOn/run',
        data: {
          'modelImageUrl': modelUrl,
          'garmentImageUrl': garmentUrl,
          'category': category,
          'restoreBackground': restoreBackground,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data['predictionId'] as String?;
      }
      return null;
    } on DioException catch (e) {
      debugPrint('Lỗi gọi API RunTryOn: ${e.response?.data}');
      rethrow;
    } catch (e) {
      debugPrint('Lỗi gọi API RunTryOn: $e');
      return null;
    }
  }

  /// Chạy thử đồ ảo dựa trên một món đồ cụ thể trong tủ đồ (WardrobeItem).
  /// Trả về predictionId nếu thành công, hoặc null nếu lỗi.
  Future<String?> runTryOnWithWardrobe({
    required String wardrobeItemId,
    String? modelUrl,
    String category = 'auto',
    bool restoreBackground = true,
  }) async {
    try {
      final response = await _apiService.post(
        '/TryOn/run-wardrobe',
        data: {
          'wardrobeItemId': wardrobeItemId,
          'modelImageUrl': ?modelUrl,
          'category': category,
          'restoreBackground': restoreBackground,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data['predictionId'] as String?;
      }
      return null;
    } on DioException catch (e) {
      debugPrint('Lỗi gọi API RunTryOn với tủ đồ: ${e.response?.data}');
      rethrow;
    } catch (e) {
      debugPrint('Lỗi gọi API RunTryOn với tủ đồ: $e');
      return null;
    }
  }

  /// Kiểm tra trạng thái của tiến trình thử đồ ảo qua predictionId.
  /// Trả về map chứa: {status, outputUrl, error}
  Future<Map<String, dynamic>?> checkStatus(String predictionId) async {
    try {
      final response = await _apiService.get('/TryOn/status/$predictionId');
      if (response.statusCode == 200 && response.data != null) {
        return {
          'status': response.data['status'] as String,
          'outputUrl': response.data['outputUrl'] as String?,
          'error': response.data['error'] as String?,
        };
      }
      return null;
    } catch (e) {
      debugPrint('Lỗi kiểm tra trạng thái thử đồ: $e');
      return null;
    }
  }
}
