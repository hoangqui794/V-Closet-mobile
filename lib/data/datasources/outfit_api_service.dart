import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'api_service.dart';

class OutfitApiService {
  final ApiService _apiService;

  OutfitApiService(this._apiService);

  Future<List<Map<String, dynamic>>> getUserOutfits() async {
    try {
      final response = await _apiService.get('/Outfits');
      final data = response.data;
      if (response.statusCode == 200 && data is List) {
        return data
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      return [];
    } on DioException {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createOutfit({
    required String title,
    required bool isPublic,
    required Uint8List snapshotBytes,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final formData = FormData.fromMap({
        'title': title,
        'isPublic': isPublic.toString(),
        'itemsJson': jsonEncode(items),
        'snapshot': MultipartFile.fromBytes(
          snapshotBytes,
          filename: 'outfit_collage.png',
        ),
      });

      final response = await _apiService.post('/Outfits', data: formData);
      final data = response.data;
      if ((response.statusCode == 200 || response.statusCode == 201) && data is Map) {
        return Map<String, dynamic>.from(data);
      }

      throw Exception('Create outfit failed with status ${response.statusCode}.');
    } on DioException catch (e) {
      final errorData = e.response?.data;
      if (errorData is Map && errorData['message'] != null) {
        throw Exception(errorData['message'].toString());
      }
      rethrow;
    }
  }

  Future<void> deleteOutfit(String id) async {
    try {
      await _apiService.delete('/Outfits/$id');
    } on DioException {
      rethrow;
    }
  }

  Future<void> updateOutfitTitle(String id, String title) async {
    try {
      await _apiService.put(
        '/Outfits/$id/title',
        data: {'title': title},
      );
    } on DioException {
      rethrow;
    }
  }
}
