import 'api_service.dart';

class ClosetApiService {
  final ApiService _apiService;

  ClosetApiService(this._apiService);

  /// Lấy danh sách tủ đồ của user
  Future<List<Map<String, dynamic>>> getClosets() async {
    try {
      final response = await _apiService.get('/api/Closets');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => Map<String, dynamic>.from(json)).toList();
      }
      return [];
    } catch (e) {
      print('Lỗi lấy danh sách tủ đồ: $e');
      return [];
    }
  }

  /// Tạo tủ đồ mới
  Future<bool> createCloset(String name) async {
    try {
      final response = await _apiService.post('/api/Closets', data: {
        'name': name,
      });
      return response.statusCode == 200;
    } catch (e) {
      print('Lỗi tạo tủ đồ: $e');
      return false;
    }
  }

  /// Gán món đồ vào tủ đồ tự chọn
  Future<bool> assignItemToCloset(String itemId, String? closetId) async {
    try {
      final response = await _apiService.put(
        '/api/Wardrobe/$itemId/assign-closet',
        queryParameters: {
          if (closetId != null) 'closetId': closetId,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Lỗi gán món đồ vào tủ đồ: $e');
      return false;
    }
  }

  /// Đổi tên tủ đồ
  Future<bool> updateCloset(String closetId, String newName) async {
    try {
      final response = await _apiService.put(
        '/api/Closets/$closetId',
        data: {
          'name': newName,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Lỗi đổi tên tủ đồ: $e');
      return false;
    }
  }

  /// Xóa tủ đồ
  Future<bool> deleteCloset(String closetId) async {
    try {
      final response = await _apiService.delete('/api/Closets/$closetId');
      return response.statusCode == 200;
    } catch (e) {
      print('Lỗi xóa tủ đồ: $e');
      return false;
    }
  }
}
