import 'dart:convert';
import 'dart:io';
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
    String? skinTone, // e.g. 'da ngăm (olive/tan skin)'
    String? bodyType, // e.g. 'vóc người nhỏ nhắn/petite'
    String? stylePref, // e.g. 'casual'
    String? suggestedColors, // e.g. 'màu trắng, đỏ đất, cam ấm'
    // ── Tủ đồ thực tế ──
    List<String>? wardrobeItemNames, // Tên các món đồ trong tủ
  }) async {
    final apiKeys = _getApiKeys();
    if (apiKeys.isEmpty) {
      debugPrint('[GeminiApiService] Chưa cấu hình bất kỳ Gemini API Key nào.');
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

    final prompt =
        '''
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

    final List<String> modelsToTry = [
      'gemini-2.5-flash',
      'gemini-3.5-flash',
      'gemini-3.1-flash-lite',
      'gemini-2.5-flash-lite',
    ];

    for (final apiKey in apiKeys) {
      final keyDisplay = apiKey.length > 8
          ? "${apiKey.substring(0, 8)}..."
          : apiKey;
      for (final model in modelsToTry) {
        try {
          debugPrint(
            '[GeminiApiService] Đang gọi Gemini API (personalized) với key: $keyDisplay và model: $model...',
          );
          final response = await _dio.post(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
            options: Options(
              headers: {'Content-Type': 'application/json'},
              sendTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 20),
            ),
            data: {
              'contents': [
                {
                  'parts': [
                    {'text': prompt},
                  ],
                },
              ],
            },
          );

          debugPrint(
            '[GeminiApiService] Phản hồi nhận được từ $model, code: ${response.statusCode}',
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
                    debugPrint(
                      '[GeminiApiService] Lời khuyên cá nhân hóa từ $model: ${text.trim()}',
                    );
                    return text.trim();
                  }
                }
              }
            }
          }
          debugPrint(
            '[GeminiApiService] Phản hồi API của model $model không chứa dữ liệu mong muốn.',
          );
        } catch (e) {
          debugPrint(
            '[GeminiApiService] Lỗi khi gọi Gemini API với key $keyDisplay và model $model: $e',
          );
          if (e is DioException) {
            debugPrint(
              '[GeminiApiService] Chi tiết lỗi mạng: ${e.response?.statusCode} - ${e.response?.data}',
            );
          }
        }
      }
    }

    debugPrint(
      '[GeminiApiService] Tất cả các model đều thất bại khi gọi generateAdvice.',
    );
    return null;
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

  List<String> _getApiKeys() {
    final keys = [
      dotenv.maybeGet('GEMINI_API_KEY'),
      dotenv.maybeGet('GEMINI_API_KEY_1'),
      dotenv.maybeGet('GEMINI_API_KEY_2'),
      dotenv.maybeGet('GEMINI_API_KEY_3'),
    ];
    return keys
        .whereType<String>()
        .where((k) => k.isNotEmpty && k != 'YOUR_GEMINI_API_KEY_HERE')
        .toList();
  }

  /// Phân tích ảnh quần áo bằng Gemini Vision API để tự động nhận diện tên, loại và màu sắc
  Future<Map<String, String>?> analyzeClothingImage(File imageFile) async {
    final apiKeys = _getApiKeys();
    if (apiKeys.isEmpty) {
      debugPrint(
        '[GeminiApiService] Chưa cấu hình bất kỳ Gemini API Key nào cho Vision API.',
      );
      return null;
    }

    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      final ext = imageFile.path.split('.').last.toLowerCase();
      final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';

      final prompt = '''
Hãy phân tích ảnh quần áo này và trả về kết quả dưới dạng JSON có cấu trúc sau:
{
  "name": "tên món đồ cụ thể ngắn gọn bằng Tiếng Việt (ví dụ: Áo thun nam đen, Quần tây xám)",
  "category": "phân loại khớp chính xác một trong các từ sau: Top, Bottom, Dress, Outerwear, Shoes, Bag, Accessory, Other",
  "color": "tên màu sắc chính bằng Tiếng Việt (ví dụ: Đen, Trắng, Xanh Navy, Đỏ Burgundy)"
}
Lưu ý: Chỉ trả về duy nhất chuỗi JSON sạch, không có ký tự markdown như ```json hay ```.
''';

      final List<String> modelsToTry = [
        'gemini-2.5-flash',
        'gemini-3.5-flash',
        'gemini-3.1-flash-lite',
        'gemini-2.5-flash-lite',
      ];

      for (final apiKey in apiKeys) {
        final keyDisplay = apiKey.length > 8
            ? "${apiKey.substring(0, 8)}..."
            : apiKey;
        for (final model in modelsToTry) {
          try {
            debugPrint(
              '[GeminiApiService] Đang phân tích ảnh quần áo qua key: $keyDisplay và model: $model...',
            );
            final response = await _dio.post(
              'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
              options: Options(
                headers: {'Content-Type': 'application/json'},
                sendTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
              ),
              data: {
                'contents': [
                  {
                    'parts': [
                      {'text': prompt},
                      {
                        'inlineData': {
                          'mimeType': mimeType,
                          'data': base64Image,
                        },
                      },
                    ],
                  },
                ],
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
                      String cleanJson = text.trim();
                      if (cleanJson.startsWith('```')) {
                        cleanJson = cleanJson.replaceFirst(
                          RegExp(r'^```(json)?'),
                          '',
                        );
                        cleanJson = cleanJson.replaceFirst(RegExp(r'```$'), '');
                        cleanJson = cleanJson.trim();
                      }
                      final decoded =
                          jsonDecode(cleanJson) as Map<String, dynamic>;
                      return {
                        'name': decoded['name']?.toString() ?? 'Món đồ mới',
                        'category': decoded['category']?.toString() ?? 'Other',
                        'color': decoded['color']?.toString() ?? 'Không rõ',
                      };
                    }
                  }
                }
              }
            }
          } catch (e) {
            debugPrint(
              '[GeminiApiService] Lỗi phân tích ảnh với key $keyDisplay và model $model: $e',
            );
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('[GeminiApiService] Lỗi đọc hoặc xử lý ảnh: $e');
      return null;
    }
  }

  /// Trò chuyện và tư vấn phong cách thời trang cá nhân hóa với Gemini
  Future<String?> chatStyle({
    required List<Map<String, String>>
    messages, // Danh sách [{role: 'user'|'model', text: '...'}]
    required String userDisplayName,
    required String gender,
    String? skinTone,
    String? bodyType,
    String? stylePref,
    String? suggestedColors,
    double? heightCm,
    double? weightKg,
    String? country,
    List<String>? wardrobeItemNames,
  }) async {
    final apiKeys = _getApiKeys();
    if (apiKeys.isEmpty) {
      debugPrint(
        '[GeminiApiService] Chưa cấu hình bất kỳ Gemini API Key nào cho chatStyle.',
      );
      return null;
    }

    final stylePrefLabel = _stylePrefLabel(stylePref);

    final systemInstruction =
        '''
Bạn là một Chuyên Gia Tư Vấn Thời Trang & Phong Cách (AI Stylist) thông minh, thân thiện của ứng dụng V-Closet.
Nhiệm vụ của bạn là hỗ trợ và tư vấn trang phục, màu sắc, phong cách cho khách hàng dựa trên thông tin cá nhân của họ.

Thông tin khách hàng:
- Tên: $userDisplayName
- Giới tính: ${gender.toLowerCase() == 'female' || gender == 'Nữ' || gender.toLowerCase() == 'nu' ? 'Nữ' : 'Nam'}
- Hình thể: ${heightCm != null ? 'Cao ${heightCm.toStringAsFixed(0)} cm' : 'Chưa cập nhật chiều cao'}, ${weightKg != null ? 'Nặng ${weightKg.toStringAsFixed(0)} kg' : 'Chưa cập nhật cân nặng'}
- Địa điểm/Quốc gia: ${country ?? 'Việt Nam'}
- Style DNA:
  * Tông da: ${skinTone ?? 'Trung bình'}
  * Nhóm màu khuyên dùng: ${suggestedColors ?? 'Màu trung tính'}
  * Dáng người: ${bodyType ?? 'Trung bình'}
  * Phong cách ưa thích: $stylePrefLabel

Tủ đồ của họ hiện đang sở hữu các món đồ sau:
${wardrobeItemNames != null && wardrobeItemNames.isNotEmpty ? wardrobeItemNames.take(15).map((name) => '- $name').join('\n') : '(Tủ đồ đang trống)'}

Quy tắc ứng xử và phản hồi:
1. Luôn xưng hô thân mật, lịch sự (Ví dụ: gọi khách hàng bằng tên "$userDisplayName" hoặc xưng "AI Stylist").
2. Đưa ra các gợi ý trang phục cực kỳ chi tiết, phù hợp với:
   - Giới tính của họ (Nam đề xuất vest, sơ mi, quần dài, shorts nam...; Nữ đề xuất đầm, váy, áo croptop, shorts nữ...).
   - Chiều cao & cân nặng của họ (Ví dụ: người thấp nên chọn trang phục sọc dọc, cạp cao; người tròn nên tránh đồ ôm sát; người gầy nên mặc đồ sáng màu, xếp ly).
   - Tông da của họ (gợi ý mặc các nhóm màu tôn da trong "Màu sắc khuyên dùng" và giải thích ngắn gọn lý do).
   - Địa điểm sinh sống (phù hợp với khí hậu khu vực nếu họ hỏi).
3. Khi khách hàng hỏi về trang phục đi các dịp đặc biệt (lễ cưới, đi làm, hẹn hò, tiệc tùng, dạo phố, thể thao) hoặc theo mùa:
   - Hãy thiết kế bộ trang phục cụ thể (ví dụ: phối áo nào với quần/váy nào, chọn phụ kiện gì, đi giày gì).
   - Giải thích tại sao sự kết hợp đó lại tối ưu cho hình thể và tông da của họ.
   - Nếu có thể, hãy ưu tiên khuyên họ kết hợp từ các món đồ có sẵn trong TỦ ĐỒ THỰC TẾ của họ đã được liệt kê ở trên.
4. Trả lời bằng Tiếng Việt trôi chảy, tự nhiên, chuyên nghiệp như một Stylist thực thụ. Tránh viết quá dài dòng, trả lời tập trung vào câu hỏi của khách hàng (khoảng 3-5 câu mỗi phản hồi). Không sử dụng định dạng Markdown quá phức tạp (có thể dùng dấu gạch đầu dòng hoặc in đậm nhẹ nhàng).
''';

    // Chuyển đổi định dạng lịch sử chat sang định dạng của Gemini API
    final List<Map<String, dynamic>> contents = messages.map((msg) {
      return {
        'role': msg['role'] == 'user' ? 'user' : 'model',
        'parts': [
          {'text': msg['text']},
        ],
      };
    }).toList();

    final List<String> modelsToTry = [
      'gemini-2.5-flash',
      'gemini-3.5-flash',
      'gemini-3.1-flash-lite',
      'gemini-2.5-flash-lite',
    ];

    for (final apiKey in apiKeys) {
      final keyDisplay = apiKey.length > 8
          ? "${apiKey.substring(0, 8)}..."
          : apiKey;
      for (final model in modelsToTry) {
        try {
          debugPrint(
            '[GeminiApiService] Đang gọi Gemini Chat API với key: $keyDisplay và model: $model...',
          );
          final response = await _dio.post(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
            options: Options(
              headers: {'Content-Type': 'application/json'},
              sendTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 20),
            ),
            data: {
              'contents': contents,
              'systemInstruction': {
                'parts': [
                  {'text': systemInstruction},
                ],
              },
              'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 1200},
            },
          );

          if (response.statusCode == 200 && response.data != null) {
            final candidates = response.data['candidates'] as List<dynamic>;
            if (candidates.isNotEmpty) {
              final finishReason = candidates[0]['finishReason']?.toString();
              if (finishReason != null && finishReason != 'STOP') {
                debugPrint(
                  '[GeminiApiService] Chat response did not finish cleanly ($finishReason), trying next model/key.',
                );
                continue;
              }
              final content = candidates[0]['content'];
              if (content != null) {
                final parts = content['parts'] as List<dynamic>;
                if (parts.isNotEmpty) {
                  final text = parts
                      .map((part) => part['text'])
                      .whereType<String>()
                      .join('\n')
                      .trim();
                  if (text.isNotEmpty) {
                    if (_looksIncompleteResponse(text)) {
                      debugPrint(
                        '[GeminiApiService] Chat response looks incomplete, trying next model/key: $text',
                      );
                      continue;
                    }
                    debugPrint(
                      '[GeminiApiService] Phản hồi từ model $model thành công với key $keyDisplay.',
                    );
                    return text;
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint(
            '[GeminiApiService] Lỗi gọi Gemini Chat API với key $keyDisplay và model $model: $e',
          );
        }
      }
    }
    return null;
  }

  bool _looksIncompleteResponse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return true;
    if (RegExp(r'[.!?…)"”]$').hasMatch(trimmed)) return false;

    final lower = trimmed.toLowerCase();
    final wordCount = trimmed.split(RegExp(r'\s+')).length;
    const danglingEndings = [
      'diện',
      'mặc',
      'phối',
      'kết hợp',
      'chọn',
      'với',
      'cùng',
      'và',
      'hoặc',
      'như',
      'gồm',
      'là',
      ':',
    ];

    if (wordCount > 8) return true;
    return danglingEndings.any(lower.endsWith);
  }

  /// Nâng cấp tự động đặt tên cho bộ phối đồ bằng AI dựa trên danh mục của các món đồ đi kèm
  Future<String?> generateOutfitName({
    required List<String> clothingNames,
  }) async {
    final apiKeys = _getApiKeys();
    if (apiKeys.isEmpty) return null;

    final prompt =
        '''
Hãy phân tích danh sách các món đồ quần áo sau đây và đề xuất 1 tên gọi chung cực kỳ ngắn gọn (chỉ từ 3 đến 5 từ), trẻ trung và mang tính thời trang bằng Tiếng Việt cho bộ phối đồ (outfit) này.
Danh sách các món đồ:
${clothingNames.map((name) => '- $name').join('\n')}

Ví dụ tên đề xuất: 
- Năng động dạo phố mùa hè
- Thu đông ấm áp lịch lãm
- Công sở thanh lịch năng động
- Tiệc tối sang trọng quyến rũ
- Thể thao khỏe khoắn tự tin

Lưu ý: Chỉ trả về duy nhất chuỗi văn bản chứa tên bộ phối đồ được đề xuất, KHÔNG sử dụng ký tự đặc biệt, dấu ngoặc hay markdown.
''';

    final List<String> modelsToTry = [
      'gemini-2.5-flash',
      'gemini-3.5-flash',
      'gemini-3.1-flash-lite',
      'gemini-2.5-flash-lite',
    ];

    for (final apiKey in apiKeys) {
      final keyDisplay = apiKey.length > 8
          ? "${apiKey.substring(0, 8)}..."
          : apiKey;
      for (final model in modelsToTry) {
        try {
          debugPrint(
            '[GeminiApiService] Đang sinh tên outfit với model $model...',
          );
          final response = await _dio.post(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
            options: Options(
              headers: {'Content-Type': 'application/json'},
              sendTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
            ),
            data: {
              'contents': [
                {
                  'parts': [
                    {'text': prompt},
                  ],
                },
              ],
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
                    debugPrint(
                      '[GeminiApiService] Tên outfit được sinh ra: ${text.trim()}',
                    );
                    return text.trim();
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint(
            '[GeminiApiService] Lỗi sinh tên outfit với key $keyDisplay và model $model: $e',
          );
        }
      }
    }
    return null;
  }
}
