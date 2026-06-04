import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'package:v_closet_mobile/main.dart';
import 'auth_local_storage.dart';

class ApiService {
  final Dio _dio;
  bool _isRefreshing = false;
  final List<Completer<String?>> _refreshCompleters = [];
  bool _isLoggingOut = false;

  ApiService(this._dio) {
    _dio.options.baseUrl = dotenv.get('API_URL');

    // Add Interceptors (giống như Middleware trong .NET)
    _dio.interceptors.add(
      LogInterceptor(requestBody: true, responseBody: true),
    );

    // Thêm Auth Interceptor để gửi kèm Token và tự động refresh token
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Lấy token từ storage và gán vào header
          if (GetIt.I.isRegistered<AuthLocalStorage>()) {
            final localStorage = GetIt.I<AuthLocalStorage>();
            final token = localStorage.getAccessToken();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          final isAuthApi = error.requestOptions.path.contains('/api/auth/refresh-token') ||
                            error.requestOptions.path.contains('/api/auth/login');

          // Nếu gặp lỗi 401
          if (error.response?.statusCode == 401) {
            if (isAuthApi) {
              // Nếu là chính API login hoặc refresh-token mà trả về 401 thì văng app liền
              await _logoutAndRedirectToLogin();
              return handler.next(error);
            } else {
              // Nếu không phải API login/refresh, thử refresh token
              if (GetIt.I.isRegistered<AuthLocalStorage>()) {
                final localStorage = GetIt.I<AuthLocalStorage>();
                final accessToken = localStorage.getAccessToken();
                final refreshToken = localStorage.getRefreshToken();

                if (accessToken != null && refreshToken != null) {
                  if (_isRefreshing) {
                    final completer = Completer<String?>();
                    _refreshCompleters.add(completer);
                    try {
                      final newAccess = await completer.future;
                      if (newAccess != null && newAccess.isNotEmpty) {
                        // Cập nhật token trong request bị lỗi ban đầu và gửi lại
                        final opts = error.requestOptions;
                        opts.headers['Authorization'] = 'Bearer $newAccess';

                        final cloneReq = await _dio.request(
                          opts.path,
                          options: Options(
                            method: opts.method,
                            headers: opts.headers,
                            contentType: opts.contentType,
                          ),
                          data: opts.data,
                          queryParameters: opts.queryParameters,
                        );
                        return handler.resolve(cloneReq);
                      }
                    } catch (e) {
                      print('Lỗi khi chờ token làm mới: $e');
                    }
                    return handler.next(error);
                  }

                  _isRefreshing = true;
                  try {
                    // Tạo một Dio instance tạm thời để gọi refresh token tránh vòng lặp vô hạn
                    final refreshDio = Dio(BaseOptions(baseUrl: _dio.options.baseUrl));
                    refreshDio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
                    
                    final response = await refreshDio.post('/api/auth/refresh-token', data: {
                      'accessToken': accessToken,
                      'refreshToken': refreshToken,
                    });

                    if (response.statusCode == 200) {
                      final data = response.data as Map<String, dynamic>;
                      final newAccess = (data['AccessToken'] ?? data['accessToken']) as String? ?? '';
                      final newRefresh = (data['RefreshToken'] ?? data['refreshToken']) as String? ?? '';
                      
                      // Parse userId linh hoạt (hỗ trợ cả int và String Guid từ JWT)
                      int userId = 0;
                      final rawUserId = data['UserId'] ?? data['userId'];
                      if (rawUserId is int) {
                        userId = rawUserId;
                      } else if (rawUserId is String && newAccess.isNotEmpty) {
                        try {
                          final parts = newAccess.split('.');
                          if (parts.length >= 2) {
                            final payload = parts[1];
                            final normalized = base64Url.normalize(payload);
                            final decoded = utf8.decode(base64Url.decode(normalized));
                            final jwtPayload = json.decode(decoded) as Map<String, dynamic>;
                            final nameid = jwtPayload['nameid'] ?? jwtPayload['sub'];
                            if (nameid != null) {
                              userId = int.tryParse(nameid.toString()) ?? 0;
                            }
                          }
                        } catch (e) {
                          print('Lỗi giải mã JWT khi refresh token: $e');
                        }
                      }

                      final email        = (data['Email']         ?? data['email'])         as String? ?? '';
                      final displayName  = (data['DisplayName']   ?? data['displayName'])   as String? ?? '';
                      final role         = (data['Role']          ?? data['role'])          as String? ?? 'Customer';
                      final avatarUrl    = (data['AvatarUrl']      ?? data['avatarUrl'])     as String?;
                      final isOnboardingCompleted =
                          (data['IsOnboardingCompleted'] ?? data['isOnboardingCompleted']) as bool? ?? false;
                      final isPasswordSet =
                          (data['IsPasswordSet'] ?? data['isPasswordSet']) as bool? ?? true;

                      if (newAccess.isNotEmpty && newRefresh.isNotEmpty) {
                        // Lưu token và thông tin user mới
                        await localStorage.saveTokens(newAccess, newRefresh);
                        await localStorage.saveUser(
                          userId: userId,
                          email: email,
                          displayName: displayName,
                          role: role,
                          avatarUrl: avatarUrl,
                          isOnboardingCompleted: isOnboardingCompleted,
                          isPasswordSet: isPasswordSet,
                        );

                        // Giải phóng cho toàn bộ request đang chờ
                        for (final completer in _refreshCompleters) {
                          completer.complete(newAccess);
                        }
                        _refreshCompleters.clear();
                        _isRefreshing = false;

                        // Cập nhật token trong request bị lỗi ban đầu và gửi lại
                        final opts = error.requestOptions;
                        opts.headers['Authorization'] = 'Bearer $newAccess';

                        final cloneReq = await _dio.request(
                          opts.path,
                          options: Options(
                            method: opts.method,
                            headers: opts.headers,
                            contentType: opts.contentType,
                          ),
                          data: opts.data,
                          queryParameters: opts.queryParameters,
                        );
                        return handler.resolve(cloneReq);
                      } else {
                        throw Exception('Token returned from server is empty.');
                      }
                    } else {
                      throw Exception('Refresh token failed with status ${response.statusCode}');
                    }
                  } catch (e) {
                    // Nếu refresh token thất bại (user bị khoá / token hết hạn hoàn toàn)
                    print('Lỗi làm mới token: $e');
                    
                    // Giải phóng toàn bộ completer với null
                    for (final completer in _refreshCompleters) {
                      completer.complete(null);
                    }
                    _refreshCompleters.clear();
                    _isRefreshing = false;

                    await _logoutAndRedirectToLogin();
                    return handler.next(error);
                  }
                } else {
                  // Không có token hợp lệ
                  await _logoutAndRedirectToLogin();
                  return handler.next(error);
                }
              } else {
                // Không có LocalStorage đăng ký
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
                });
                return handler.next(error);
              }
            }
          }
          return handler.next(error);
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

  // PATCH request
  Future<Response> patch(String path, {dynamic data}) async {
    try {
      return await _dio.patch(path, data: data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _logoutAndRedirectToLogin() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;

    try {
      if (GetIt.I.isRegistered<AuthLocalStorage>()) {
        await GetIt.I<AuthLocalStorage>().clearSession();
      }
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = navigatorKey.currentContext;
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tài khoản đã bị khoá hoặc phiên đăng nhập hết hạn!'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        } else {
          navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
        }
      });
    } finally {
      Future.delayed(const Duration(seconds: 2), () {
        _isLoggingOut = false;
      });
    }
  }
}
