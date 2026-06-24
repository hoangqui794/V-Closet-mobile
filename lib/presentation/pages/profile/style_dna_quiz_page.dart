import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/datasources/auth_local_storage.dart';
import '../../../data/datasources/user_api_service.dart';

class StyleDnaQuizPage extends StatefulWidget {
  /// Gọi khi user hoàn thành quiz
  final VoidCallback onCompleted;

  const StyleDnaQuizPage({super.key, required this.onCompleted});

  @override
  State<StyleDnaQuizPage> createState() => _StyleDnaQuizPageState();
}

class _StyleDnaQuizPageState extends State<StyleDnaQuizPage>
    with TickerProviderStateMixin {
  final _localStorage = GetIt.I<AuthLocalStorage>();

  int _currentStep = 0;
  bool _isSaving = false;

  // Answers
  String? _skinTone;
  String? _bodyType;
  String? _stylePref;
  String? _colorPref;

  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  // ── Quiz data ────────────────────────────────────────────────────
  final List<_QuizStep> _steps = [
    _QuizStep(
      emoji: '🎨',
      title: 'Tone da của bạn?',
      subtitle: 'Giúp chúng tôi gợi ý màu sắc tôn da nhất cho bạn',
      options: [
        _QuizOption(
          value: 'sang',
          label: 'Da sáng',
          desc: 'Trắng hồng, ít sắc tố',
          color: const Color(0xFFF5E6D3),
          textColor: const Color(0xFF8B6914),
          emoji: '🤍',
        ),
        _QuizOption(
          value: 'trung_binh',
          label: 'Da trung bình',
          desc: 'Vàng ấm, bánh mật',
          color: const Color(0xFFD4A96A),
          textColor: Colors.white,
          emoji: '🧡',
        ),
        _QuizOption(
          value: 'ngam',
          label: 'Da ngăm',
          desc: 'Olive, nâu nhẹ',
          color: const Color(0xFFA0784A),
          textColor: Colors.white,
          emoji: '🤎',
        ),
        _QuizOption(
          value: 'toi',
          label: 'Da tối',
          desc: 'Nâu đậm, ebony',
          color: const Color(0xFF5D3A1A),
          textColor: Colors.white,
          emoji: '🖤',
        ),
      ],
    ),
    _QuizStep(
      emoji: '👤',
      title: 'Vóc người của bạn?',
      subtitle: 'Để gợi ý kiểu dáng phù hợp nhất với bạn',
      options: [
        _QuizOption(
          value: 'nho_nhan',
          label: 'Nhỏ nhắn',
          desc: 'Petite, chiều cao < 1m60',
          color: const Color(0xFFE8D5F5),
          textColor: const Color(0xFF6B35A0),
          emoji: '🌸',
        ),
        _QuizOption(
          value: 'trung_binh',
          label: 'Trung bình',
          desc: 'Cân đối, dễ mặc mọi kiểu',
          color: const Color(0xFFD5E8F5),
          textColor: const Color(0xFF2B6B9A),
          emoji: '⚖️',
        ),
        _QuizOption(
          value: 'cao_rao',
          label: 'Cao ráo',
          desc: 'Chiều cao > 1m65, thanh mảnh',
          color: const Color(0xFFD5F5E8),
          textColor: const Color(0xFF2B9A6B),
          emoji: '🌿',
        ),
        _QuizOption(
          value: 'day_dan',
          label: 'Đầy đặn',
          desc: 'Curvy, đường cong nổi bật',
          color: const Color(0xFFF5D5E8),
          textColor: const Color(0xFF9A2B6B),
          emoji: '💝',
        ),
      ],
    ),
    _QuizStep(
      emoji: '✨',
      title: 'Phong cách ưa thích?',
      subtitle: 'Chọn phong cách thường ngày bạn muốn mặc nhất',
      options: [
        _QuizOption(
          value: 'casual',
          label: 'Casual',
          desc: 'Thoải mái, năng động, hàng ngày',
          color: const Color(0xFFE3F2FD),
          textColor: const Color(0xFF1565C0),
          emoji: '👟',
        ),
        _QuizOption(
          value: 'cong_so',
          label: 'Công sở',
          desc: 'Thanh lịch, chuyên nghiệp',
          color: const Color(0xFFE8EAF6),
          textColor: const Color(0xFF283593),
          emoji: '💼',
        ),
        _QuizOption(
          value: 'streetwear',
          label: 'Streetwear',
          desc: 'Cá tính, bold, trendy',
          color: const Color(0xFFFCE4EC),
          textColor: const Color(0xFFAD1457),
          emoji: '🔥',
        ),
        _QuizOption(
          value: 'thanh_lich',
          label: 'Thanh lịch',
          desc: 'Feminine, duyên dáng, nhẹ nhàng',
          color: const Color(0xFFF3E5F5),
          textColor: const Color(0xFF6A1B9A),
          emoji: '🌷',
        ),
        _QuizOption(
          value: 'sporty',
          label: 'Sporty',
          desc: 'Năng động, thể thao, khỏe khoắn',
          color: const Color(0xFFE8F5E9),
          textColor: const Color(0xFF2E7D32),
          emoji: '⚡',
        ),
      ],
    ),
    _QuizStep(
      emoji: '🎨',
      title: 'Bảng màu yêu thích?',
      subtitle: 'Màu sắc nào bạn thường chọn khi đi mua đồ?',
      options: [
        _QuizOption(
          value: 'pastel',
          label: 'Pastel nhẹ',
          desc: 'Hồng, tím nhạt, baby blue, mint',
          color: const Color(0xFFFCE4EC),
          textColor: const Color(0xFF880E4F),
          emoji: '🌸',
        ),
        _QuizOption(
          value: 'trung_tinh',
          label: 'Trung tính',
          desc: 'Be, kem, xám, camel, nâu',
          color: const Color(0xFFF5F0E8),
          textColor: const Color(0xFF5D4037),
          emoji: '🤍',
        ),
        _QuizOption(
          value: 'toi_mau',
          label: 'Tối màu',
          desc: 'Đen, navy, charcoal, deep green',
          color: const Color(0xFF2D2D2D),
          textColor: Colors.white,
          emoji: '🖤',
        ),
        _QuizOption(
          value: 'mau_noi',
          label: 'Màu nổi',
          desc: 'Đỏ, vàng, cam, cobalt, neon',
          color: const LinearGradient(
            colors: [Color(0xFFFF6B6B), Color(0xFFFFE66D), Color(0xFF4ECDC4)],
          ),
          textColor: Colors.white,
          emoji: '🌈',
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);

    _slideController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _nextStep() async {
    if (_currentStep < _steps.length - 1) {
      await _slideController.reverse();
      setState(() => _currentStep++);
      _slideController.forward();
    } else {
      await _saveAndFinish();
    }
  }

  void _prevStep() async {
    if (_currentStep > 0) {
      await _slideController.reverse();
      setState(() => _currentStep--);
      _slideController.forward();
    }
  }

  Future<void> _saveAndFinish() async {
    setState(() => _isSaving = true);
    final skinTone = _skinTone ?? 'trung_binh';
    final bodyType = _bodyType ?? 'trung_binh';
    final stylePref = _stylePref ?? 'casual';
    final colorPref = _colorPref ?? 'trung_tinh';

    await _localStorage.saveStyleDna(
      skinTone: skinTone,
      bodyType: bodyType,
      stylePref: stylePref,
      colorPref: colorPref,
    );

    // Đồng bộ Style DNA lên máy chủ nếu người dùng đã đăng nhập
    try {
      if (_localStorage.hasSession()) {
        final userApiService = GetIt.I<UserApiService>();
        await userApiService.updateMyProfile(
          skinTone: skinTone,
          bodyType: bodyType,
          stylePref: stylePref,
          colorPref: colorPref,
        );
      }
    } catch (e) {
      debugPrint('Lỗi khi đồng bộ Style DNA lên máy chủ: $e');
    }

    if (mounted) {
      widget.onCompleted();
    }
  }

  String? get _currentAnswer {
    switch (_currentStep) {
      case 0: return _skinTone;
      case 1: return _bodyType;
      case 2: return _stylePref;
      case 3: return _colorPref;
      default: return null;
    }
  }

  void _setAnswer(String value) {
    setState(() {
      switch (_currentStep) {
        case 0: _skinTone = value; break;
        case 1: _bodyType = value; break;
        case 2: _stylePref = value; break;
        case 3: _colorPref = value; break;
      }
    });
  }

  bool get _canProceed => _currentAnswer != null;

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final isLastStep = _currentStep == _steps.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4FF),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    GestureDetector(
                      onTap: _prevStep,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            color: AppColors.primary, size: 20),
                      ),
                    )
                  else
                    const SizedBox(width: 40),
                  const Spacer(),
                  Text(
                    '${_currentStep + 1} / ${_steps.length}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary.withOpacity(0.5),
                    ),
                  ),
                  const Spacer(),
                  // Skip button
                  GestureDetector(
                    onTap: () async {
                      await _localStorage.saveHasCompletedStyleQuiz(true);
                      widget.onCompleted();
                    },
                    child: Text(
                      'Bỏ qua',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primary.withOpacity(0.4),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Progress bar ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / _steps.length,
                  backgroundColor: AppColors.primary.withOpacity(0.08),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 6,
                ),
              ),
            ),

            // ── Question area ─────────────────────────────────────────
            Expanded(
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Emoji + Title
                        Text(
                          step.emoji,
                          style: const TextStyle(fontSize: 52),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          step.title,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          step.subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.primary.withOpacity(0.55),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Options
                        ...step.options.map((opt) => _buildOptionCard(opt)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Bottom CTA ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _canProceed && !_isSaving ? _nextStep : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.25),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: _canProceed ? 4 : 0,
                    shadowColor: AppColors.primary.withOpacity(0.4),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isLastStep ? '🎉  Hoàn thành!' : 'Tiếp theo',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            if (!isLastStep) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded,
                                  color: Colors.white, size: 18),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard(_QuizOption opt) {
    final isSelected = _currentAnswer == opt.value;

    return GestureDetector(
      onTap: () => _setAnswer(opt.value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : AppColors.primary.withOpacity(0.1),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Color swatch / emoji
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: opt.color is LinearGradient
                    ? opt.color as LinearGradient
                    : null,
                color: opt.color is Color ? opt.color as Color : null,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  opt.emoji,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    opt.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    opt.desc,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? Colors.white.withOpacity(0.8)
                          : AppColors.primary.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? Colors.white : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? Colors.white
                      : AppColors.primary.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Icon(Icons.check_rounded,
                      size: 14, color: AppColors.primary)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data models ──────────────────────────────────────────────────────────────

class _QuizStep {
  final String emoji;
  final String title;
  final String subtitle;
  final List<_QuizOption> options;

  const _QuizStep({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.options,
  });
}

class _QuizOption {
  final String value;
  final String label;
  final String desc;
  final dynamic color; // Color or LinearGradient
  final Color textColor;
  final String emoji;

  const _QuizOption({
    required this.value,
    required this.label,
    required this.desc,
    required this.color,
    required this.textColor,
    required this.emoji,
  });
}
