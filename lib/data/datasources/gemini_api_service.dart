import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiApiService {
  final Dio _dio = Dio();

  /// Gọi Gemini API để sinh câu khuyên dùng phối đồ dựa trên thời tiết và tên khách hàng.
  /// Trả về câu khuyên bằng tiếng Việt hoặc null nếu xảy ra lỗi hoặc thiếu API key.
  Future<String?> generateAdvice({
    required double temperature,
    required String weatherDescription,
    required String userDisplayName,
  }) async {
    final apiKey = dotenv.maybeGet('GEMINI_API_KEY');
    if (apiKey == null || apiKey.isEmpty || apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      debugPrint('[GeminiApiService] Gemini API Key chưa được cấu hình.');
      return null;
    }

    try {
      final prompt = '''
Bạn là một chuyên gia tư vấn thời trang (AI Stylist) của ứng dụng tủ đồ thông minh V-Closet.
Hãy viết một câu tư vấn, khuyên dùng phối đồ thời trang hôm nay cho khách hàng tên là "$userDisplayName".

Thông tin thời tiết hiện tại:
- Nhiệt độ thực tế: ${temperature.toStringAsFixed(1)}°C
- Trạng thái thời tiết: $weatherDescription

Yêu cầu câu trả lời:
1. Thân thiện, tự nhiên, và mang tính chất thời trang, cá nhân hóa. Ngắn gọn (tối đa 2-3 câu ngắn).
2. Phù hợp tuyệt đối với thời tiết hôm nay:
   - Nếu nhiệt độ > 30°C: Thời tiết nóng bức, khuyên mặc các trang phục mỏng nhẹ, mát mẻ, năng động (ví dụ: áo thun, quần short/short jeans).
   - Nếu nhiệt độ < 20°C: Thời tiết lạnh, khuyên mặc áo khoác giữ ấm bên ngoài (ví dụ: áo khoác, quần dài, jacket).
   - Nếu nhiệt độ từ 20°C - 30°C: Thời tiết mát mẻ, dễ chịu, khuyên mặc trang phục thanh lịch, thoải mái (ví dụ: áo sơ mi, áo polo kết hợp quần dài tây/kaki).
3. Đề xuất cụ thể một bộ trang phục mẫu bằng từ khóa rõ ràng để hệ thống có thể phân tích (ví dụ: khuyên dùng "áo thun phối với quần short", hoặc "áo sơ mi kết hợp quần dài").
4. Trả về câu tư vấn bằng Tiếng Việt. KHÔNG sử dụng định dạng markdown hay bất kỳ ký tự đặc biệt nào (như dấu sao, gạch đầu dòng, dấu ngoặc nhọn).
''';

      final response = await _dio.post(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey',
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
        data: {
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ]
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final candidates = response.data['candidates'] as List<dynamic>;
        if (candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          if (content != null) {
            final parts = content['parts'] as List<dynamic>;
            if (parts.isNotEmpty) {
              final text = parts[0]['text'] as String?;
              if (text != null && text.trim().isNotEmpty) {
                return text.trim();
              }
            }
          }
        }
      }
      debugPrint('[GeminiApiService] Phản hồi API không chứa dữ liệu mong muốn.');
      return null;
    } catch (e) {
      debugPrint('[GeminiApiService] Lỗi khi gọi Gemini API: $e');
      return null;
    }
  }
}
