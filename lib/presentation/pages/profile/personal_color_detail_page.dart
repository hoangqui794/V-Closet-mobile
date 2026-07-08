import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/datasources/auth_local_storage.dart';
import '../../../data/datasources/user_api_service.dart';
import '../../widgets/app_tour_overlay.dart';
import 'personal_color_profile.dart';

class PersonalColorDetailPage extends StatefulWidget {
  final bool isFromScan;
  final String? scannedSkinTone;
  final String? scannedColorPref;
  final bool showColorTestGuide;

  const PersonalColorDetailPage({
    super.key,
    this.isFromScan = false,
    this.scannedSkinTone,
    this.scannedColorPref,
    this.showColorTestGuide = false,
  });

  @override
  State<PersonalColorDetailPage> createState() =>
      _PersonalColorDetailPageState();
}

class _PersonalColorDetailPageState extends State<PersonalColorDetailPage> {
  final _localStorage = GetIt.I<AuthLocalStorage>();
  final _userService = GetIt.I<UserApiService>();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _updateColorGuideKey = GlobalKey();
  bool _isSaving = false;
  bool _isShowingColorGuide = false;

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowColorTestGuide();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _maybeShowColorTestGuide() async {
    if (!widget.showColorTestGuide || widget.isFromScan) return;
    if (_isShowingColorGuide) return;

    _isShowingColorGuide = true;
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) {
      _isShowingColorGuide = false;
      return;
    }

    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
      );
      await Future.delayed(const Duration(milliseconds: 180));
    }

    if (!mounted) {
      _isShowingColorGuide = false;
      return;
    }

    final result = await AppTourOverlay.showCoachStep(
      context,
      targetKey: _updateColorGuideKey,
      stepNumber: 2,
      totalSteps: 3,
      icon: Icons.camera_alt_rounded,
      title: 'Mở camera test màu',
      description:
          'Nhấn nút này để chụp khuôn mặt và phân tích lại tone da, undertone, bảng màu hợp với bạn.',
      primaryLabel: 'Nhấn vùng sáng để mở camera',
    );

    _isShowingColorGuide = false;
    if (!mounted) return;
    if (result == AppTourCoachAction.next) {
      _retakeQuiz();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppColors.brandText,
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
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      profile.subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF8D8D94),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 120,
                      height: 120,
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
              const SizedBox(height: 20),
              _sectionCard(
                icon: Icons.info_outline_rounded,
                title: 'Đặc điểm chính',
                content: _paragraph(profile.mainDescription),
              ),
              const SizedBox(height: 12),
              _sectionCard(
                icon: Icons.palette_outlined,
                title: 'Màu sắc phù hợp nhất',
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _colorSwatchRow(profile.bestColors),
                    const SizedBox(height: 8),
                    _paragraph(profile.bestColorDescription),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _sectionCard(
                icon: Icons.checkroom_outlined,
                title: 'Chất liệu vải phù hợp nhất',
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fabricScroller(profile.fabrics),
                    const SizedBox(height: 8),
                    _paragraph(profile.fabricDescription),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _sectionCard(
                icon: Icons.block_flipped,
                title: 'Những màu sắc cần tránh',
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _colorSwatchRow(profile.avoidColors),
                    const SizedBox(height: 8),
                    _paragraph(profile.avoidDescription),
                  ],
                ),
              ),
              const SizedBox(height: 24),
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
                  key: _updateColorGuideKey,
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
                      foregroundColor: AppColors.brandText,
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
          color: AppColors.brandText,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Widget content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.brandText, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF25252B),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          content,
        ],
      ),
    );
  }

  Widget _paragraph(String text) {
    return _ExpandableParagraph(text: text);
  }

  Widget _colorSwatchRow(List<PersonalColorSwatch> colors) {
    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: colors.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final swatch = colors[index];
          return SizedBox(
            width: 50,
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
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
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  swatch.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF686872),
                    fontSize: 9,
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
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: fabrics.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final fabric = fabrics[index];
          return SizedBox(
            width: 130,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
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
                const SizedBox(height: 6),
                Text(
                  fabric.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF25252B),
                    fontSize: 12,
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
                    fontSize: 10,
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

class _ExpandableParagraph extends StatefulWidget {
  final String text;
  const _ExpandableParagraph({required this.text});

  @override
  State<_ExpandableParagraph> createState() => _ExpandableParagraphState();
}

class _ExpandableParagraphState extends State<_ExpandableParagraph> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final bool isLongText = widget.text.length > 80;

    return GestureDetector(
      onTap: isLongText ? () => setState(() => _isExpanded = !_isExpanded) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: Text(
              widget.text,
              maxLines: _isExpanded ? null : 2,
              overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF5A5A62),
                fontSize: 12.0,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (isLongText) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  _isExpanded ? 'Thu gọn' : 'Xem thêm...',
                  style: const TextStyle(
                    color: AppColors.brandText,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Icon(
                  _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.brandText,
                  size: 14,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
