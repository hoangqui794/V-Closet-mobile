import 'package:dio/dio.dart';
import 'api_service.dart';
import 'auth_local_storage.dart';

class AuthApiService {
  final ApiService _apiService;
  final AuthLocalStorage _localStorage;

  AuthApiService(this._apiService, this._localStorage);

  /// Đăng nhập
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _apiService.post(
        '/api/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        await _saveAuthResponse(data);
        return data;
      }
      throw Exception('Đăng nhập thất bại.');
    } on DioException catch (e) {
      final errorMsg = _getDioErrorMessage(e);
      throw Exception(errorMsg);
    }
  }

  /// Đăng ký tài khoản mới
  Future<String> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final response = await _apiService.post(
        '/api/auth/register',
        data: {
          'email': email,
          'password': password,
          'displayName': displayName,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data.toString();
      }
      throw Exception('Đăng ký thất bại.');
    } on DioException catch (e) {
      final errorMsg = _getDioErrorMessage(e);
      throw Exception(errorMsg);
    }
  }

  /// Xác thực mã OTP sau đăng ký (hoặc khi đăng nhập nếu cần)
  Future<Map<String, dynamic>> verifyOtp(String email, String otpCode) async {
    try {
      final response = await _apiService.post(
        '/api/auth/verify-otp',
        data: {
          'email': email,
          'otpCode': otpCode,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        await _saveAuthResponse(data);
        return data;
      }
      throw Exception('Mã OTP không chính xác hoặc đã hết hạn.');
    } on DioException catch (e) {
      final errorMsg = _getDioErrorMessage(e);
      throw Exception(errorMsg);
    }
  }

  /// Gửi lại mã OTP
  Future<String> resendOtp(String email) async {
    try {
      final response = await _apiService.post(
        '/api/auth/resend-otp',
        data: {
          'email': email,
        },
      );
      if (response.statusCode == 200) {
        return response.data.toString();
      }
      throw Exception('Không thể gửi lại mã OTP.');
    } on DioException catch (e) {
      final errorMsg = _getDioErrorMessage(e);
      throw Exception(errorMsg);
    }
  }

  /// Quên mật khẩu - gửi mã OTP
  Future<String> forgotPassword(String email) async {
    try {
      final response = await _apiService.post(
        '/api/auth/forgot-password',
        data: {
          'email': email,
        },
      );
      if (response.statusCode == 200) {
        return response.data.toString();
      }
      throw Exception('Không thể yêu cầu khôi phục mật khẩu.');
    } on DioException catch (e) {
      final errorMsg = _getDioErrorMessage(e);
      throw Exception(errorMsg);
    }
  }

  /// Đặt lại mật khẩu mới bằng OTP
  Future<String> resetPassword({
    required String email,
    required String otpCode,
    required String newPassword,
  }) async {
    try {
      final response = await _apiService.post(
        '/api/auth/reset-password',
        data: {
          'email': email,
          'otpCode': otpCode,
          'newPassword': newPassword,
        },
      );
      if (response.statusCode == 200) {
        return response.data.toString();
      }
      throw Exception('Đặt lại mật khẩu thất bại.');
    } on DioException catch (e) {
      final errorMsg = _getDioErrorMessage(e);
      throw Exception(errorMsg);
    }
  }

  /// Đăng nhập bằng Google
  Future<Map<String, dynamic>> googleLogin(String idToken) async {
    try {
      final response = await _apiService.post(
        '/api/auth/google-login',
        data: {
          'idToken': idToken,
        },
      );

      if (response.statusCode == 200) {
        final body = response.data as Map<String, dynamic>;
        // Ở BE: return Ok(new { message = "Đăng nhập Google thành công", data = response });
        final data = body['data'] as Map<String, dynamic>;
        await _saveAuthResponse(data);
        return data;
      }
      throw Exception('Xác thực Google thất bại.');
    } on DioException catch (e) {
      final errorMsg = _getDioErrorMessage(e);
      throw Exception(errorMsg);
    }
  }

  /// Đổi mật khẩu (yêu cầu Authorization)
  Future<String> changePassword(String oldPassword, String newPassword) async {
    try {
      final response = await _apiService.post(
        '/api/auth/change-password',
        data: {
          'oldPassword': oldPassword,
          'newPassword': newPassword,
        },
      );
      if (response.statusCode == 200) {
        return response.data.toString();
      }
      throw Exception('Đổi mật khẩu thất bại.');
    } on DioException catch (e) {
      final errorMsg = _getDioErrorMessage(e);
      throw Exception(errorMsg);
    }
  }

  /// Làm mới token (Refresh Token)
  Future<Map<String, dynamic>> refreshTokens(String accessToken, String refreshToken) async {
    try {
      final response = await _apiService.post(
        '/api/auth/refresh-token',
        data: {
          'accessToken': accessToken,
          'refreshToken': refreshToken,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        await _saveAuthResponse(data);
        return data;
      }
      throw Exception('Làm mới token thất bại.');
    } on DioException catch (e) {
      final errorMsg = _getDioErrorMessage(e);
      throw Exception(errorMsg);
    }
  }

  /// Đăng xuất (yêu cầu Authorization)
  Future<String> logout() async {
    try {
      final refreshToken = _localStorage.getRefreshToken();
      if (refreshToken != null) {
        await _apiService.post(
          '/api/auth/logout',
          data: {
            'refreshToken': refreshToken,
          },
        );
      }
    } catch (e) {
      // Bỏ qua lỗi BE khi gọi logout (vẫn tiến hành xóa session ở client)
      print('Lỗi gọi API logout: $e');
    } finally {
      await _localStorage.clearSession();
    }
    return 'Đăng xuất thành công.';
  }

  /// Lưu thông tin AuthResponse vào Storage
  /// BE trả về camelCase (accessToken, refreshToken...)
  /// → đọc cả PascalCase lẫn camelCase để tương thích
  Future<void> _saveAuthResponse(Map<String, dynamic> data) async {
    // Đọc PascalCase trước (thực tế BE), fallback camelCase
    final accessToken  = (data['AccessToken']  ?? data['accessToken'])  as String? ?? '';
    final refreshToken = (data['RefreshToken'] ?? data['refreshToken']) as String? ?? '';
    final userId       = (data['UserId']        ?? data['userId'])        as int?    ?? 0;
    final email        = (data['Email']         ?? data['email'])         as String? ?? '';
    final displayName  = (data['DisplayName']   ?? data['displayName'])   as String? ?? '';
    final role         = (data['Role']          ?? data['role'])          as String? ?? 'Customer';
    final avatarUrl    = (data['AvatarUrl']      ?? data['avatarUrl'])     as String?;
    final isOnboardingCompleted =
        (data['IsOnboardingCompleted'] ?? data['isOnboardingCompleted']) as bool? ?? false;
    final isPasswordSet =
        (data['IsPasswordSet'] ?? data['isPasswordSet']) as bool? ?? true;

    // Đọc thông tin subscription từ login response để lưu ngay
    final hasActivePremium =
        (data['HasActivePremium'] ?? data['hasActivePremium']) as bool? ?? false;
    final planType =
        (data['PlanType'] ?? data['planType']) as String? ?? 'free';

    await _localStorage.saveTokens(accessToken, refreshToken);
    await _localStorage.saveUser(
      userId: userId,
      email: email,
      displayName: displayName,
      role: role,
      avatarUrl: avatarUrl,
      isOnboardingCompleted: isOnboardingCompleted,
      isPasswordSet: isPasswordSet,
    );
    // Lưu premium status ngay sau login — dùng hasActivePremium (bool) cho badge, planType cho credits
    await _localStorage.saveHasActivePremium(hasActivePremium);
    await _localStorage.saveSubscription(planType, 5, 5);
  }

  /// Chuyển đổi lỗi Dio thành thông báo thân thiện bằng tiếng Việt
  String _getDioErrorMessage(DioException e) {
    if (e.response != null) {
      final data = e.response?.data;
      if (data != null) {
        if (data is Map) {
          if (data['message'] != null) {
            return data['message'].toString();
          }
          if (data['errors'] != null && data['errors'] is Map) {
            final errorsMap = data['errors'] as Map;
            final buffer = StringBuffer();
            errorsMap.forEach((key, value) {
              if (value is List) {
                buffer.writeln(value.join(', '));
              } else {
                buffer.writeln('$value');
              }
            });
            if (buffer.isNotEmpty) return buffer.toString().trim();
          }
          if (data['title'] != null) {
            return data['title'].toString();
          }
        }
        if (data is String && data.isNotEmpty) {
          return data;
        }
      }
      if (e.response?.statusCode == 400) {
        return 'Yêu cầu không hợp lệ. Vui lòng kiểm tra lại thông tin.';
      }
      if (e.response?.statusCode == 401) {
        return 'Tài khoản hoặc mật khẩu không chính xác.';
      }
      if (e.response?.statusCode == 409) {
        return 'Tài khoản hoặc email đã tồn tại.';
      }
      return 'Lỗi hệ thống (${e.response?.statusCode}). Vui lòng thử lại sau.';
    }
    if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
      return 'Kết nối mạng quá hạn. Vui lòng kiểm tra lại kết nối.';
    }
    return 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra lại mạng.';
  }
}
