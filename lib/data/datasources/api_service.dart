import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  final Dio _dio;

  ApiService(this._dio) {
    _dio.options.baseUrl = dotenv.get('API_URL');

    // Add Interceptors (giống như Middleware trong .NET)
    _dio.interceptors.add(
      LogInterceptor(requestBody: true, responseBody: true),
    );

    // Thêm Auth Interceptor để gửi kèm Token nếu cần
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Lấy token từ storage và gán vào header
          // options.headers['Authorization'] = 'Bearer $token';
          return handler.next(options);
        },
      ),
    );

    // Bỏ qua xác thực SSL khi ở chế độ DEBUG_MODE để tránh lỗi chứng chỉ tự ký (Self-signed certificate) của Localhost .NET
    if (dotenv.get('DEBUG_MODE', fallback: 'false') == 'true') {
      final adapter = _dio.httpClientAdapter;
      if (adapter is IOHttpClientAdapter) {
        adapter.createHttpClient = () {
          final client = HttpClient();
          client.badCertificateCallback =
              (X509Certificate cert, String host, int port) => true;
          return client;
        };
      }
    }
  }

  // GET request
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } catch (e) {
      rethrow;
    }
  }

  // POST request
  Future<Response> post(String path, {dynamic data, Options? options}) async {
    try {
      return await _dio.post(path, data: data, options: options);
    } catch (e) {
      rethrow;
    }
  }

  // PUT request
  Future<Response> put(String path, {dynamic data}) async {
    try {
      return await _dio.put(path, data: data);
    } catch (e) {
      rethrow;
    }
  }

  // DELETE request
  Future<Response> delete(String path, {dynamic data}) async {
    try {
      return await _dio.delete(path, data: data);
    } catch (e) {
      rethrow;
    }
  }
}
