import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiApiService {
  final Dio _dio = Dio();

  /// Gọi Gemini API để sinh câu khuyên phối đồ được cá nhân hóa hoàn toàn.
  /// Nhận thông tin thời tiết + Style DNA Profile + tủ đồ thực tế của user.
  Future<String?> generateAdvice({
    required double temperature,
    required String weatherDescription,
    required String userDisplayName,
    required String gender,
    // ── Style DNA Profile ──
    String? skinTone,        // e.g. 'da ngăm (olive/tan skin)'
    String? bodyType,        // e.g. 'vóc người nhỏ nhắn/petite'
    String? stylePref,       // e.g. 'casual'
    String? suggestedColors, // e.g. 'màu trắng, đỏ đất, cam ấm'
    // ── Tủ đồ thực tế ──
    List<String>? wardrobeItemNames, // Tên các món đồ trong tủ
  }) async {
    final apiKey = dotenv.maybeGet('GEMINI_API_KEY');
    debugPrint('[GeminiApiService] API Key từ .env: ${apiKey == null ? "NULL" : (apiKey.length > 8 ? "${apiKey.substring(0, 8)}..." : apiKey)}');
    if (apiKey == null || apiKey.isEmpty || apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      debugPrint('[GeminiApiService] Gemini API Key chưa được cấu hình.');
      return null;
    }

    // ── Phần Style Profile ─────────────────────────────────────────
    final hasStyleProfile = skinTone != null || bodyType != null;
    final stylePrefLabel = _stylePrefLabel(stylePref);

    final styleSection = hasStyleProfile
        ? '''

Hồ sơ phong cách cá nhân của khách hàng:
- Tông da: ${skinTone ?? 'trung bình'}
- Vóc người: ${bodyType ?? 'trung bình'}
- Phong cách ưa thích: $stylePrefLabel
- Màu sắc tôn da nhất cho họ: ${suggestedColors ?? 'màu trung tính'}

LƯU Ý: Bạn PHẢI ưu tiên gợi ý các màu phù hợp với tông da và giải thích ngắn gọn tại sao màu đó hợp với họ.
'''
        : '';

    // ── Phần Tủ đồ thực ──────────────────────────────────────────
    final hasWardrobe =
        wardrobeItemNames != null && wardrobeItemNames.isNotEmpty;
    final wardrobeSection = hasWardrobe
        ? '''

Danh sách đồ trong TỦ ĐỒ THỰC TẾ của khách hàng:
${wardrobeItemNames.take(12).map((name) => '- $name').join('\n')}

YÊU CẦU: Nếu có thể, hãy gợi ý cụ thể TÊN MÓN ĐỒ từ danh sách trên thay vì gợi ý chung chung. Ví dụ: "Hôm nay bạn có thể mặc [tên món đồ] của bạn..."
'''
        : '';

    try {
      final prompt = '''
Bạn là một chuyên gia tư vấn thời trang (AI Stylist) của ứng dụng tủ đồ thông minh V-Closet.
Hãy viết một câu tư vấn, khuyên dùng phối đồ thời trang hôm nay cho khách hàng tên là "$userDisplayName".
Khách hàng này có giới tính là: $gender. Bạn phải đưa ra các gợi ý trang phục phù hợp với giới tính này (Ví dụ: đối với Nữ, gợi ý đầm, chân váy, croptop, quần shorts nữ; đối với Nam, gợi ý quần dài tây/kaki, quần short nam, áo polo, sơ mi nam).
$styleSection$wardrobeSection
Thông tin thời tiết hiện tại:
- Nhiệt độ thực tế: ${temperature.toStringAsFixed(1)}°C
- Trạng thái thời tiết: $weatherDescription

Yêu cầu câu trả lời:
1. Thân thiện, tự nhiên, và mang tính chất thời trang, cá nhân hóa. Ngắn gọn (tối đa 2-3 câu ngắn).
2. Phù hợp tuyệt đối với thời tiết và giới tính hôm nay:
   - Nếu nhiệt độ > 30°C: Thời tiết nóng bức, khuyên mặc các trang phục mỏng nhẹ, mát mẻ, năng động.
   - Nếu nhiệt độ < 20°C: Thời tiết lạnh, khuyên mặc áo ấm (ví dụ: áo khoác jacket, áo len, quần dài).
   - Nếu nhiệt độ từ 20°C - 30°C: Thời tiết mát mẻ, dễ chịu, khuyên mặc trang phục thanh lịch, thoải mái.
3. Đề xuất cụ thể một bộ trang phục mẫu bằng từ khóa rõ ràng để hệ thống có thể phân tích (ví dụ: khuyên dùng "áo thun phối với quần short", hoặc "áo sơ mi kết hợp quần dài").
4. Trả về câu tư vấn bằng Tiếng Việt. KHÔNG sử dụng định dạng markdown hay bất kỳ ký tự đặc biệt nào (như dấu sao, gạch đầu dòng, dấu ngoặc nhọn).
''';

      debugPrint('[GeminiApiService] Đang gọi Gemini API (personalized)...');
      final response = await _dio.post(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 12),
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

      debugPrint('[GeminiApiService] Phản hồi nhận được, code: ${response.statusCode}');

      if (response.statusCode == 200 && response.data != null) {
        final candidates = response.data['candidates'] as List<dynamic>;
        if (candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          if (content != null) {
            final parts = content['parts'] as List<dynamic>;
            if (parts.isNotEmpty) {
              final text = parts[0]['text'] as String?;
              if (text != null && text.trim().isNotEmpty) {
                debugPrint('[GeminiApiService] Lời khuyên cá nhân hóa: ${text.trim()}');
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
      if (e is DioException) {
        debugPrint('[GeminiApiService] Chi tiết lỗi mạng: ${e.response?.statusCode} - ${e.response?.data}');
      }
      return null;
    }
  }

  String _stylePrefLabel(String? pref) {
    switch (pref) {
      case 'casual':
        return 'Casual (thoải mái, năng động)';
      case 'cong_so':
        return 'Công sở (thanh lịch, chuyên nghiệp)';
      case 'streetwear':
        return 'Streetwear (cá tính, bold, trendy)';
      case 'thanh_lich':
        return 'Thanh lịch (feminine, duyên dáng)';
      case 'sporty':
        return 'Sporty (năng động, thể thao)';
      default:
        return 'Casual';
    }
  }
}
