import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/datasources/auth_local_storage.dart';
import '../../pages/profile/personal_color_detail_page.dart';
import '../../pages/profile/personal_color_profile.dart';
import '../../pages/camera/color_harmony_checker_page.dart';

class StyleDnaCard extends StatelessWidget {
  final String? gender;
  final VoidCallback? onRefresh;
  const StyleDnaCard({super.key, this.gender, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final localStorage = GetIt.I<AuthLocalStorage>();

    // Nếu chưa làm khảo sát, hiển thị banner nhắc nhở
    if (!localStorage.getHasCompletedStyleQuiz()) {
      return const SizedBox.shrink();
    }

    final skinTone = localStorage.getSkinTone() ?? 'trung_binh';
    final bodyType = localStorage.getBodyType() ?? 'trung_binh';
    final personalColorProfile = PersonalColorProfile.resolve(
      skinTone: localStorage.getSkinTone(),
      colorPref: localStorage.getColorPref(),
      stylePref: localStorage.getStylePref(),
    );

    // ── 1. Lấy thông tin màu sắc theo skin tone ─────────────────────
    final Map<String, dynamic> colorData = _getColorPalette(skinTone);
    final String skinToneName = colorData['name'] as String;
    final List<Color> bestColors = colorData['best'] as List<Color>;
    final List<Color> avoidColors = colorData['avoid'] as List<Color>;
    final String skinToneDesc = colorData['desc'] as String;

    // ── 2. Lấy thông tin vóc dáng và kiểu đồ ─────────────────────────
    final Map<String, dynamic> bodyData = _getBodyStyling(bodyType, gender);
    final String bodyTypeName = bodyData['name'] as String;
    final List<String> bestCuts = bodyData['cuts'] as List<String>;
    final String bodyTypeDesc = bodyData['desc'] as String;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.08),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.03),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header với tiêu đề và icon lấp lánh
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Hồ sơ Phong cách của bạn',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Tóm tắt chỉ số cơ bản
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _summaryChip(
                    '🎨 $skinToneName',
                    AppColors.primary.withOpacity(0.06),
                  ),
                  _summaryChip(
                    '🌈 ${personalColorProfile.title}',
                    AppColors.secondary.withOpacity(0.55),
                  ),
                  _summaryChip(
                    '👤 $bodyTypeName',
                    AppColors.primary.withOpacity(0.06),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PersonalColorDetailPage(),
                    ),
                  );

                  if (result == 'retake') {
                    if (context.mounted) {
                      final checkResult = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ColorHarmonyCheckerPage(),
                        ),
                      );

                      if (checkResult is Map) {
                        if (context.mounted) {
                          final saveResult = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PersonalColorDetailPage(
                                isFromScan: true,
                                scannedSkinTone: checkResult['skinTone']?.toString(),
                                scannedColorPref: checkResult['colorPref']?.toString(),
                              ),
                            ),
                          );

                          if (saveResult == 'saved') {
                            if (onRefresh != null) {
                              onRefresh!();
                            }
                          }
                        }
                      }
                    }
                  } else if (result == 'saved') {
                    if (onRefresh != null) {
                      onRefresh!();
                    }
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: personalColorProfile.bestColors
                                .take(3)
                                .map((swatch) => swatch.color)
                                .toList(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              personalColorProfile.title,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Xem đặc điểm, màu hợp, chất liệu vải và màu nên tránh',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.primary.withOpacity(0.55),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, thickness: 0.8),
              const SizedBox(height: 16),

              // Nhóm 1: Bảng màu tôn da
              const Text(
                'Bảng màu tôn da nhất (Best Colors) ✨',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                skinToneDesc,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primary.withOpacity(0.6),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: bestColors.map((color) => _colorBox(color)).toList(),
              ),
              const SizedBox(height: 20),

              // Nhóm 2: Màu sắc nên tránh
              const Text(
                'Màu sắc dìm tone da nên tránh (Avoid Colors) ⚠️',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: avoidColors.map((color) => _colorBox(color)).toList(),
              ),
              const SizedBox(height: 22),
              const Divider(height: 1, thickness: 0.8),
              const SizedBox(height: 16),

              // Nhóm 3: Kiểu dáng và form đồ khuyên mặc
              const Text(
                'Kiểu dáng trang phục khuyên chọn 📐',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                bodyTypeDesc,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primary.withOpacity(0.6),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: bestCuts.map((cut) => _cutChip(cut)).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryChip(String label, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _colorBox(Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: color == Colors.white
              ? AppColors.primary.withOpacity(0.2)
              : Colors.transparent,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }

  Widget _cutChip(String cut) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.1), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: Colors.green,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            cut,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getColorPalette(String skinTone) {
    switch (skinTone) {
      case 'sang':
        return {
          'name': 'Da sáng',
          'desc':
              'Tone da trắng hồng thích hợp với các sắc độ lạnh, màu ngọc đậm bão hòa cao để làm nổi bật làn da.',
          'best': [
            const Color(0xFF1A237E), // Navy Blue
            const Color(0xFF1B5E20), // Forest Green
            const Color(0xFF800020), // Burgundy
            const Color(0xFFFCE4EC), // Pastel Pink
          ],
          'avoid': [
            const Color(0xFFFFF9C4), // Vàng nhạt nhợt
            const Color(0xFFFAF2EB), // Màu be quá nhạt dìm da
          ],
        };
      case 'ngam':
        return {
          'name': 'Da ngăm',
          'desc':
              'Tone da bánh mật/olive khỏe khoắn thích hợp các gam màu ấm nóng, trung tính ấm hoặc màu cobalt rực rỡ.',
          'best': [
            const Color(0xFFD4AF37), // Warm Gold
            const Color(0xFFE67E22), // Warm Orange
            const Color(0xFF0047AB), // Cobalt Blue
            Colors.white, // Pure White tôn da cực mạnh
          ],
          'avoid': [
            const Color(0xFFCCFF00), // Neon sáng chói dìm da
            const Color(0xFFECEFF1), // Màu xám xịt làm xỉn da
          ],
        };
      case 'toi':
        return {
          'name': 'Da tối',
          'desc':
              'Tone da ngăm đậm/ebony nổi bật nhất khi kết hợp với các gam màu rực rỡ, ánh kim loại lấp lánh hoặc màu trắng sáng.',
          'best': [
            const Color(0xFFFFD700), // Vivid Gold
            const Color(0xFFFF2400), // Scarlet Red
            const Color(0xFF0066CC), // Electric Blue
            Colors.white,
          ],
          'avoid': [
            const Color(0xFF5D4037), // Màu nâu xỉn lẫn vào da
            const Color(0xFFFFEBEE), // Hồng pastel nhạt nhợt
          ],
        };
      case 'trung_binh':
      default:
        return {
          'name': 'Da trung bình',
          'desc':
              'Tone da vàng ấm đặc trưng Châu Á phù hợp nhất với các gam màu đất ấm áp, màu pastel dịu nhẹ hoặc màu ấm.',
          'best': [
            const Color(0xFF556B2F), // Olive Green
            const Color(0xFFC0392B), // Terracotta
            const Color(0xFFC19A6B), // Camel
            const Color(0xFFE5A93B), // Mustard Yellow
          ],
          'avoid': [
            const Color(0xFFF3E5F5), // Tím pastel dìm da
            const Color(0xFFB0BEC5), // Xám lạnh làm da nhợt nhạt
          ],
        };
    }
  }

  Map<String, dynamic> _getBodyStyling(String bodyType, String? gender) {
    final isMale = gender?.toLowerCase() == 'male';
    final isFemale = gender?.toLowerCase() == 'female';

    if (isMale) {
      switch (bodyType) {
        case 'nho_nhan':
          return {
            'name': 'Dáng hình chữ nhật',
            'desc':
                'Thân hình thanh mảnh, vai và hông có chiều rộng xấp xỉ bằng nhau. Hãy ưu tiên các trang phục tạo phom ngực và vai trông rộng hơn.',
            'cuts': [
              'Áo blazer đệm vai',
              'Áo thun kẻ ngang',
              'Mặc phối nhiều lớp (Layer)',
              'Quần jeans ống đứng',
            ],
          };
        case 'day_dan':
          return {
            'name': 'Dáng hình Oval / Đầy đặn',
            'desc':
                'Thân hình tròn trịa, đầy đặn ở phần bụng. Hãy ưu tiên trang phục đứng dáng, tối giản và có đường may thẳng đứng để tạo cảm giác thon gọn.',
            'cuts': [
              'Áo cổ chữ V nam',
              'Áo sơ mi vải đứng dáng',
              'Quần suông tối màu',
              'Áo thun màu trơn tối giản',
            ],
          };
        case 'cao_rao':
          return {
            'name': 'Dáng cao ráo',
            'desc':
                'Thân hình cao ráo thanh mảnh. Bạn rất hợp để mặc phối layer hoặc diện các dáng áo khoác dài thời thượng.',
            'cuts': [
              'Áo khoác dáng dài',
              'Phối đồ nhiều lớp (Layer)',
              'Quần jeans ống suông rộng',
              'Áo thun cổ tròn',
            ],
          };
        case 'trung_binh':
        default:
          return {
            'name': 'Dáng hình tam giác ngược (V-Taper)',
            'desc':
                'Thân hình cân đối, vai rộng ngực nở và hông nhỏ săn chắc. Hãy lựa chọn các thiết kế làm nổi bật phom dáng thể thao khỏe khoắn.',
            'cuts': [
              'Áo thun ôm vừa vặn (Slim)',
              'Áo sơ mi regular-fit',
              'Quần tây ống đứng',
              'Áo khoác Bomber năng động',
            ],
          };
      }
    } else if (isFemale) {
      switch (bodyType) {
        case 'nho_nhan':
          return {
            'name': 'Vóc người Nhỏ nhắn (Petite)',
            'desc':
                'Thân hình thanh mảnh có chiều cao hơi khiêm tốn. Hãy ưu tiên các trang phục hack chiều cao, tạo cảm giác đôi chân dài hơn.',
            'cuts': [
              'Áo croptop dáng lửng',
              'Quần cạp cao ống đứng',
              'Chân váy chữ A cạp cao',
              'Họa tiết sọc dọc',
            ],
          };
        case 'cao_rao': // Quả lê
          return {
            'name': 'Dáng người Quả lê',
            'desc':
                'Vai và ngực nhỏ gọn, tập trung đầy đặn ở hông và đùi. Ưu tiên nhấn mạnh phần thân trên để tạo sự cân đối tổng thể.',
            'cuts': [
              'Áo trễ vai điệu đà',
              'Chân váy xòe chữ A',
              'Áo cổ thuyền/cổ bèo',
              'Quần ống rộng đứng dáng',
            ],
          };
        case 'day_dan': // Quả táo
          return {
            'name': 'Dáng người Quả táo / Tròn trịa',
            'desc':
                'Đầy đặn ở phần thân trên, vai ngực nở và bụng đầy đặn, chân thon. Hãy chọn thiết kế tạo điểm nhấn eo nhẹ để cân bằng tỉ lệ.',
            'cuts': [
              'Áo cổ chữ V thoáng',
              'Váy quấn (Wrap dress)',
              'Quần suông ống đứng',
              'Chất liệu vải đứng phom',
            ],
          };
        case 'trung_binh':
        default:
          return {
            'name': 'Dáng người Đồng hồ cát',
            'desc':
                'Thân hình cân đối quyến rũ với vòng eo thon gọn rõ nét. Hãy tự tin chọn các thiết kế tôn lên đường cong tự nhiên này.',
            'cuts': [
              'Đầm/áo ôm sát body',
              'Đầm chiết eo rõ rệt',
              'Quần jeans ôm cạp cao',
              'Áo cổ chữ V trẻ trung',
            ],
          };
      }
    } else {
      // Unisex / Giới tính khác / Chưa chọn
      switch (bodyType) {
        case 'nho_nhan':
          return {
            'name': 'Vóc người Nhỏ nhắn',
            'desc':
                'Thân hình thanh mảnh có chiều cao hơi khiêm tốn. Hãy ưu tiên các trang phục hack chiều cao kéo dài chân.',
            'cuts': [
              'Áo lửng thời trang',
              'Quần ống đứng cạp cao',
              'Trang phục sọc dọc',
              'Đóng thùng gọn gàng',
            ],
          };
        case 'cao_rao':
          return {
            'name': 'Vóc người Cao ráo',
            'desc':
                'Thân hình có chiều cao nổi bật. Hãy thoải mái phối layer hoặc mặc quần ống rộng thời thượng.',
            'cuts': [
              'Quần ống rộng thời trang',
              'Áo khoác dáng dài',
              'Mặc layer nhiều lớp',
              'Quần cạp vừa',
            ],
          };
        case 'day_dan':
          return {
            'name': 'Vóc người Đầy đặn',
            'desc':
                'Thân hình tròn trịa đầy đặn. Hãy ưu tiên các thiết kế đứng dáng để tạo sự cân đối.',
            'cuts': [
              'Áo cổ chữ V tôn dáng',
              'Áo khoác blazer tối giản',
              'Quần suông tối màu',
              'Chất liệu đứng phom',
            ],
          };
        case 'trung_binh':
        default:
          return {
            'name': 'Vóc người Cân đối',
            'desc':
                'Thân hình cân đối dễ mặc mọi kiểu đồ. Hãy tập trung làm nổi bật tỉ lệ vàng của cơ thể.',
            'cuts': [
              'Áo thun regular-fit',
              'Quần jeans ống đứng',
              'Trang phục đóng thùng',
              'Áo khoác bomber',
            ],
          };
      }
    }
  }
}
