import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/datasources/auth_local_storage.dart';
import '../../../data/datasources/user_api_service.dart';
import 'personal_color_profile.dart';

class PersonalColorDetailPage extends StatefulWidget {
  final bool isFromScan;
  final String? scannedSkinTone;
  final String? scannedColorPref;

  const PersonalColorDetailPage({
    super.key,
    this.isFromScan = false,
    this.scannedSkinTone,
    this.scannedColorPref,
  });

  @override
  State<PersonalColorDetailPage> createState() =>
      _PersonalColorDetailPageState();
}

class _PersonalColorDetailPageState extends State<PersonalColorDetailPage> {
  final _localStorage = GetIt.I<AuthLocalStorage>();
  final _userService = GetIt.I<UserApiService>();
  bool _isSaving = false;

  PersonalColorProfile get _profile => PersonalColorProfile.resolve(
    skinTone: widget.isFromScan
        ? widget.scannedSkinTone
        : _localStorage.getSkinTone(),
    colorPref: widget.isFromScan
        ? widget.scannedColorPref
        : _localStorage.getColorPref(),
    stylePref: _localStorage.getStylePref(),
  );

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppColors.primary,
                ),
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
              const SizedBox(height: 18),
              Center(
                child: Column(
                  children: [
                    Text(
                      profile.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF24242A),
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      profile.subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF8D8D94),
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 34),
                    SizedBox(
                      width: 156,
                      height: 156,
                      child: CustomPaint(
                        painter: _ColorWheelPainter(profile.wheelColors),
                        child: Center(
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6F2DE),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: profile.traits.map(_traitChip).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 54),
              _sectionTitle('Đặc điểm chính'),
              const SizedBox(height: 12),
              _paragraph(profile.mainDescription),
              const SizedBox(height: 42),
              _sectionTitle('Màu sắc phù hợp nhất'),
              const SizedBox(height: 18),
              _colorSwatchRow(profile.bestColors),
              const SizedBox(height: 16),
              _paragraph(profile.bestColorDescription),
              const SizedBox(height: 42),
              _sectionTitle('Chất liệu vải phù hợp nhất'),
              const SizedBox(height: 18),
              _fabricScroller(profile.fabrics),
              const SizedBox(height: 16),
              _paragraph(profile.fabricDescription),
              const SizedBox(height: 42),
              _sectionTitle('Những màu sắc cần tránh'),
              const SizedBox(height: 18),
              _colorSwatchRow(profile.avoidColors),
              const SizedBox(height: 16),
              _paragraph(profile.avoidDescription),
              const SizedBox(height: 34),
              if (widget.isFromScan) ...[
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: SizedBox(
                        height: 54,
                        child: OutlinedButton(
                          onPressed: _isSaving
                              ? null
                              : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF9A9AA2),
                            side: const BorderSide(
                              color: Color(0xFFDCDCE0),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Hủy bỏ',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 6,
                      child: SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveScanResult,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF242424),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Lưu kết quả',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: _retakeQuiz,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text(
                      'Cập nhật phân tích màu',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(
                        color: AppColors.primary.withOpacity(0.35),
                        width: 1.3,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _traitChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withOpacity(0.08)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF25252B),
        fontSize: 22,
        fontWeight: FontWeight.w900,
        height: 1.1,
      ),
    );
  }

  Widget _paragraph(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF2F2F35),
        fontSize: 16,
        height: 1.28,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _colorSwatchRow(List<PersonalColorSwatch> colors) {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: colors.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final swatch = colors[index];
          return SizedBox(
            width: 62,
            child: Column(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: swatch.color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: swatch.color == Colors.white
                          ? AppColors.primary.withOpacity(0.18)
                          : Colors.transparent,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: swatch.color.withOpacity(0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  swatch.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF686872),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _fabricScroller(List<FabricSuggestion> fabrics) {
    return SizedBox(
      height: 196,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: fabrics.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final fabric = fabrics[index];
          return SizedBox(
            width: 178,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: fabric.imagePath != null
                        ? Image.asset(
                            fabric.imagePath!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          )
                        : CustomPaint(
                            painter: _FabricPreviewPainter(
                              fabric.previewColors,
                              index,
                            ),
                            child: const SizedBox.expand(),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  fabric.name,
                  style: const TextStyle(
                    color: Color(0xFF25252B),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fabric.note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF777781),
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _retakeQuiz() {
    Navigator.pop(context, 'retake');
  }

  Future<void> _saveScanResult() async {
    if (widget.scannedSkinTone == null || widget.scannedColorPref == null) {
      return;
    }
    setState(() => _isSaving = true);

    await _localStorage.saveStyleDna(
      skinTone: widget.scannedSkinTone!,
      bodyType: 'trung_binh',
      stylePref: 'thanh_lich',
      colorPref: widget.scannedColorPref!,
    );

    try {
      if (_localStorage.hasSession()) {
        await _userService.updateMyProfile(
          skinTone: widget.scannedSkinTone!,
          bodyType: 'trung_binh',
          stylePref: 'thanh_lich',
          colorPref: widget.scannedColorPref!,
        );
      }
    } catch (e) {
      debugPrint('Lỗi khi đồng bộ Style DNA: $e');
    }

    if (mounted) {
      Navigator.pop(context, 'saved');
    }
  }
}

class _ColorWheelPainter extends CustomPainter {
  final List<Color> colors;

  const _ColorWheelPainter(this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweep = 2 * math.pi / colors.length;

    for (var i = 0; i < colors.length; i++) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            colors[i].withOpacity(0.62),
            colors[(i + 1) % colors.length],
          ],
        ).createShader(rect);
      canvas.drawArc(rect, -math.pi / 2 + i * sweep, sweep + 0.02, true, paint);
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11
        ..color = const Color(0xFFE7D9B5).withOpacity(0.78),
    );
    canvas.drawCircle(
      center,
      radius - 6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withOpacity(0.75),
    );
    canvas.drawCircle(
      center,
      radius + 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.black.withOpacity(0.04),
    );
  }

  @override
  bool shouldRepaint(covariant _ColorWheelPainter oldDelegate) {
    return oldDelegate.colors != colors;
  }
}

class _FabricPreviewPainter extends CustomPainter {
  final List<Color> colors;
  final int seed;

  const _FabricPreviewPainter(this.colors, this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors.length >= 2
            ? colors
            : [colors.first, colors.first.withOpacity(0.65)],
      ).createShader(rect);
    canvas.drawRect(rect, basePaint);

    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.22)
      ..strokeWidth = 1.1;
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.035)
      ..strokeWidth = 1.4;

    final spacing = seed.isEven ? 12.0 : 9.0;
    for (double x = -size.height; x < size.width + size.height; x += spacing) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        shadowPaint,
      );
      canvas.drawLine(
        Offset(x + 3, size.height),
        Offset(x + size.height + 3, 0),
        linePaint,
      );
    }

    if (seed.isOdd) {
      final wavePaint = Paint()
        ..color = Colors.white.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      for (double y = 14; y < size.height; y += 24) {
        final path = Path()..moveTo(0, y);
        for (double x = 0; x <= size.width; x += 18) {
          path.quadraticBezierTo(x + 9, y + 8, x + 18, y);
        }
        canvas.drawPath(path, wavePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FabricPreviewPainter oldDelegate) {
    return oldDelegate.colors != colors || oldDelegate.seed != seed;
  }
}
