import 'package:dio/dio.dart';
import 'api_service.dart';

class AffiliateApiService {
  final ApiService _apiService;

  AffiliateApiService(this._apiService);

  /// Lấy danh sách sản phẩm tiếp thị đang hoạt động.
  /// Hỗ trợ phân trang, lọc theo danh mục và tìm kiếm tên sản phẩm.
  Future<Map<String, dynamic>> getProducts({
    int page = 1,
    int pageSize = 20,
    String? category,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page, 'pageSize': pageSize};
      if (category != null && category.isNotEmpty) {
        queryParams['category'] = category;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _apiService.get(
        '/api/affiliate/products',
        queryParameters: queryParams,
      );

      final data = response.data;
      if (response.statusCode == 200 && data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return {'items': [], 'totalCount': 0};
    } on DioException {
      rethrow;
    }
  }

  /// Lấy thông tin chi tiết một sản phẩm tiếp thị.
  Future<Map<String, dynamic>?> getProductById(String id) async {
    try {
      final response = await _apiService.get('/api/affiliate/products/$id');
      final data = response.data;
      if (response.statusCode == 200 && data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return null;
    } on DioException {
      rethrow;
    }
  }

  /// Ghi nhận lượt click khi người dùng bấm "Mua ngay" trên App.
  /// Trả về map chứa: {clickId, targetAffiliateLink}
  Future<Map<String, dynamic>?> recordClick({
    required String productId,
    String? outfitId,
    String? clickSource,
  }) async {
    try {
      final response = await _apiService.post(
        '/api/affiliate/click',
        data: {
          'productId': productId,
          'outfitId': outfitId,
          'clickSource': clickSource,
        },
      );

      final data = response.data;
      if (response.statusCode == 200 && data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return null;
    } on DioException {
      rethrow;
    }
  }
}
