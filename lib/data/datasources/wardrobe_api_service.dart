import 'dart:io';
import 'package:dio/dio.dart';
import '../../domain/entities/clothing_item.dart';
import 'api_service.dart';

class WardrobeApiService {
  final ApiService _apiService;

  WardrobeApiService(this._apiService);

  /// Lấy danh sách tủ đồ từ backend
  Future<List<ClothingItem>> getItems({String? category, String? color}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (category != null && category.isNotEmpty) queryParams['category'] = category;
      if (color != null && color.isNotEmpty) queryParams['color'] = color;

      final response = await _apiService.get('/api/Wardrobe', queryParameters: queryParams);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => ClothingItem.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Lỗi lấy danh sách tủ đồ: $e');
      return [];
    }
  }

  /// Lấy chi tiết 1 item
  Future<ClothingItem?> getItem(String id) async {
    try {
      final response = await _apiService.get('/api/Wardrobe/$id');
      if (response.statusCode == 200) {
        return ClothingItem.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('Lỗi lấy chi tiết item: $e');
      return null;
    }
  }

  /// Upload ảnh và tạo item mới vào tủ đồ
  Future<ClothingItem?> uploadAndCreateItem({
    required File imageFile,
    required String category, // 0 = Tops, 1 = Bottoms, 2 = Outerwear, 3 = Shoes, 4 = Accessories
    String? name,
    String? brand,
  }) async {
    try {
      String fileName = imageFile.path.split(Platform.pathSeparator).last;
      
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
        "category": category,
        if (name != null) "name": name,
        if (brand != null) "brand": brand,
      });

      final response = await _apiService.post('/api/Wardrobe/upload-and-create', data: formData);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ClothingItem.fromJson(response.data);
      }
      return null;
    } on DioException catch (e) {
      print('Lỗi upload tạo item: ${e.response?.data}');
      rethrow;
    } catch (e) {
      print('Lỗi upload tạo item: $e');
      return null;
    }
  }

  /// Cập nhật thông tin item
  Future<ClothingItem?> updateItem(String id, Map<String, dynamic> data) async {
    try {
      final response = await _apiService.put('/api/Wardrobe/$id', data: data);
      if (response.statusCode == 200) {
        return ClothingItem.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('Lỗi cập nhật item: $e');
      return null;
    }
  }

  /// Xóa item
  Future<bool> deleteItem(String id) async {
    try {
      final response = await _apiService.delete('/api/Wardrobe/$id');
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      print('Lỗi xóa item: $e');
      return false;
    }
  }
}
