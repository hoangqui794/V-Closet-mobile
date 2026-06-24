import 'dart:io';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'api_service.dart';
import 'auth_local_storage.dart';

class UserApiService {
  final ApiService _apiService;

  UserApiService(this._apiService);

  /// Lấy thông tin hồ sơ cá nhân của tôi
  Future<Map<String, dynamic>> getMyProfile() async {
    try {
      final response = await _apiService.get('/api/users/me');
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;

        // Đồng bộ Style DNA (nếu có từ BE) vào local storage
        final skinTone = data['skinTone'] ?? data['SkinTone'];
        final bodyType = data['bodyType'] ?? data['BodyType'];
        final stylePref = data['stylePref'] ?? data['StylePref'];
        final colorPref = data['colorPref'] ?? data['ColorPref'];

        if (skinTone != null || bodyType != null || stylePref != null || colorPref != null) {
          final localStorage = GetIt.I<AuthLocalStorage>();
          await localStorage.saveStyleDna(
            skinTone: skinTone?.toString() ?? 'trung_binh',
            bodyType: bodyType?.toString() ?? 'trung_binh',
            stylePref: stylePref?.toString() ?? 'casual',
            colorPref: colorPref?.toString() ?? 'trung_tinh',
          );
        }

        return data;
      }
      throw Exception('Không thể tải thông tin cá nhân.');
    } on DioException catch (e) {
      throw Exception(_getDioErrorMessage(e));
    }
  }

  /// Cập nhật hồ sơ cá nhân
  Future<String> updateMyProfile({
    double? heightCm,
    double? weightKg,
    String? dateOfBirth,
    String? phoneNumber,
    String? address,
    String? gender,
    String? country,
    String? displayName,
    String? lifestyle,
    String? eyeColor,
    String? hair,
    String? skinTone,
    String? bodyType,
    String? stylePref,
    String? colorPref,
  }) async {
    try {
      final response = await _apiService.put(
        '/api/users/me',
        data: {
          if (heightCm != null) 'heightCm': heightCm,
          if (weightKg != null) 'weightKg': weightKg,
          if (dateOfBirth != null) 'dateOfBirth': dateOfBirth,
          if (phoneNumber != null) 'phoneNumber': phoneNumber,
          if (address != null) 'address': address,
          if (gender != null) 'gender': gender,
          if (country != null) 'country': country,
          if (displayName != null) 'displayName': displayName,
          if (lifestyle != null) 'lifestyle': lifestyle,
          if (eyeColor != null) 'eyeColor': eyeColor,
          if (hair != null) 'hair': hair,
          if (skinTone != null) 'skinTone': skinTone,
          if (bodyType != null) 'bodyType': bodyType,
          if (stylePref != null) 'stylePref': stylePref,
          if (colorPref != null) 'colorPref': colorPref,
        },
      );
      if (response.statusCode == 200) {
        return response.data.toString();
      }
      throw Exception('Cập nhật hồ sơ thất bại.');
    } on DioException catch (e) {
      throw Exception(_getDioErrorMessage(e));
    }
  }

  /// Cập nhật ảnh đại diện (avatar)
  Future<String> updateAvatar(File imageFile) async {
    try {
      final fileName = imageFile.path.split(Platform.pathSeparator).last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      });

      final response = await _apiService.post(
        '/api/users/me/avatar',
        data: formData,
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        // Ở BE: return Ok(new { AvatarUrl = newAvatarUrl, Message = "Cập nhật ảnh đại diện thành công!" });
        return data['avatarUrl'] as String;
      }
      throw Exception('Cập nhật ảnh đại diện thất bại.');
    } on DioException catch (e) {
      throw Exception(_getDioErrorMessage(e));
    }
  }

  /// Vô hiệu hóa tài khoản cá nhân
  Future<String> deactivateAccount() async {
    try {
      final response = await _apiService.delete('/api/users/me');
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return data['message'] as String? ?? 'Vô hiệu hóa tài khoản thành công.';
      }
      throw Exception('Vô hiệu hóa tài khoản thất bại.');
    } on DioException catch (e) {
      throw Exception(_getDioErrorMessage(e));
    }
  }

  /// Phân tích lỗi Dio
  String _getDioErrorMessage(DioException e) {
    if (e.response != null) {
      final data = e.response?.data;
      if (data != null) {
        if (data is Map) {
          if (data['message'] != null) return data['message'].toString();
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
        }
        if (data is String && data.isNotEmpty) return data;
      }
      return 'Lỗi hệ thống (${e.response?.statusCode}). Vui lòng thử lại sau.';
    }
    return 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra lại mạng.';
  }
}
