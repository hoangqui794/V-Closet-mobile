import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  final Dio _dio;

  ApiService(this._dio) {
    _dio.options.baseUrl = dotenv.get('API_URL');
    
    // Add Interceptors (giống như Middleware trong .NET)
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));

    // Thêm Auth Interceptor để gửi kèm Token nếu cần
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // Lấy token từ storage và gán vào header
        // options.headers['Authorization'] = 'Bearer $token';
        return handler.next(options);
      },
    ));
  }

  // GET request
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } catch (e) {
      rethrow;
    }
  }

  // POST request
  Future<Response> post(String path, {dynamic data}) async {
    try {
      return await _dio.post(path, data: data);
    } catch (e) {
      rethrow;
    }
  }
}
