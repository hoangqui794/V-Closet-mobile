import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/app_routes.dart';
import '../../../data/datasources/auth_local_storage.dart';
import '../../../data/datasources/user_api_service.dart';

class StyleDnaQuizPage extends StatefulWidget {
  /// True if shown during registration onboarding, false if manually triggered from profile settings.
  final bool isOnboarding;

  /// Callback when quiz completes (optional in onboarding).
  final VoidCallback? onCompleted;

  const StyleDnaQuizPage({
    super.key,
    this.onCompleted,
    this.isOnboarding = false,
  });

  @override
  State<StyleDnaQuizPage> createState() => _StyleDnaQuizPageState();
}

class _StyleDnaQuizPageState extends State<StyleDnaQuizPage>
    with TickerProviderStateMixin {
  final _localStorage = GetIt.I<AuthLocalStorage>();

  int _currentStep = 0;
  bool _isSaving = false;

  // Onboarding survey fields
  String? _gender = 'Male';
  double _height = 165.0;
  double _weight = 55.0;
  DateTime _dob = DateTime(2000, 1, 1);
  final _displayNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  String _selectedCountry = 'Việt Nam';

  // Style DNA quiz fields
  String? _skinTone;
  String? _bodyType;
  String? _stylePref;
  String? _colorPref;

  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  final List<Map<String, String>> _countries = const [
    {'name': 'Việt Nam', 'flag': '🇻🇳'},
    {'name': 'Hàn Quốc', 'flag': '🇰🇷'},
    {'name': 'Nhật Bản', 'flag': '🇯🇵'},
    {'name': 'Mỹ', 'flag': '🇺🇸'},
    {'name': 'Pháp', 'flag': '🇫🇷'},
    {'name': 'Anh', 'flag': '🇬🇧'},
    {'name': 'Ý', 'flag': '🇮🇹'},
    {'name': 'Đức', 'flag': '🇩🇪'},
    {'name': 'Singapore', 'flag': '🇸🇬'},
    {'name': 'Úc', 'flag': '🇦🇺'},
  ];

  // ── Style DNA Quiz Steps ──────────────────────────────────────────
  List<_QuizStep> get _dnaSteps {
    return [
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
        options: _getBodyTypeOptions(),
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
  }

  List<_QuizOption> _getBodyTypeOptions() {
    if (_gender == 'Female') {
      return [
        _QuizOption(
          value: 'nho_nhan',
          label: 'Nhỏ nhắn (Petite)',
          desc: 'Thanh mảnh, chiều cao < 1m58',
          color: const Color(0xFFE8D5F5),
          textColor: const Color(0xFF6B35A0),
          emoji: '🌸',
        ),
        _QuizOption(
          value: 'trung_binh',
          label: 'Đồng hồ cát / Cân đối',
          desc: 'Số đo 3 vòng cân đối, quyến rũ',
          color: const Color(0xFFD5E8F5),
          textColor: const Color(0xFF2B6B9A),
          emoji: '⏳',
        ),
        _QuizOption(
          value: 'cao_rao',
          label: 'Quả lê (Dưới đầy đặn)',
          desc: 'Vai nhỏ, tập trung đầy đặn ở hông/đùi',
          color: const Color(0xFFD5F5E8),
          textColor: const Color(0xFF2B9A6B),
          emoji: '🍐',
        ),
        _QuizOption(
          value: 'day_dan',
          label: 'Quả táo / Tròn trịa',
          desc: 'Đầy đặn ở thân trên, vai/ngực nở',
          color: const Color(0xFFF5D5E8),
          textColor: const Color(0xFF9A2B6B),
          emoji: '🍎',
        ),
      ];
    } else if (_gender == 'Male') {
      return [
        _QuizOption(
          value: 'nho_nhan',
          label: 'Hình chữ nhật',
          desc: 'Thân hình thanh mảnh, vai và hông bằng nhau',
          color: const Color(0xFFE8D5F5),
          textColor: const Color(0xFF6B35A0),
          emoji: '📏',
        ),
        _QuizOption(
          value: 'trung_binh',
          label: 'Hình tam giác ngược (V-Taper)',
          desc: 'Vai rộng, ngực nở, hông nhỏ săn chắc',
          color: const Color(0xFFD5E8F5),
          textColor: const Color(0xFF2B6B9A),
          emoji: '📐',
        ),
        _QuizOption(
          value: 'day_dan',
          label: 'Hình Oval / Đầy đặn',
          desc: 'Thân hình tròn trịa, đầy đặn ở phần bụng',
          color: const Color(0xFFF5D5E8),
          textColor: const Color(0xFF9A2B6B),
          emoji: '🏈',
        ),
      ];
    } else {
      return [
        _QuizOption(
          value: 'nho_nhan',
          label: 'Nhỏ nhắn',
          desc: 'Thanh mảnh, chiều cao thấp hơn trung bình',
          color: const Color(0xFFE8D5F5),
          textColor: const Color(0xFF6B35A0),
          emoji: '🌸',
        ),
        _QuizOption(
          value: 'trung_binh',
          label: 'Trung bình / Cân đối',
          desc: 'Thân hình cân đối, dễ phối đồ',
          color: const Color(0xFFD5E8F5),
          textColor: const Color(0xFF2B6B9A),
          emoji: '⚖️',
        ),
        _QuizOption(
          value: 'cao_rao',
          label: 'Cao ráo',
          desc: 'Chiều cao nổi bật, dáng thanh mảnh',
          color: const Color(0xFFD5F5E8),
          textColor: const Color(0xFF2B9A6B),
          emoji: '🌿',
        ),
        _QuizOption(
          value: 'day_dan',
          label: 'Đầy đặn',
          desc: 'Thân hình tròn trịa, đầy đặn',
          color: const Color(0xFFF5D5E8),
          textColor: const Color(0xFF9A2B6B),
          emoji: '💝',
        ),
      ];
    }
  }

  @override
  void initState() {
    super.initState();
    _displayNameController.text = _localStorage.getUserName() ?? '';

    // Load previously saved Style DNA values to pre-select them
    _skinTone = _localStorage.getSkinTone();
    _bodyType = _localStorage.getBodyType();
    _stylePref = _localStorage.getStylePref();
    _colorPref = _localStorage.getColorPref();

    _loadUserProfile();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _slideController.forward();
    _fadeController.forward();
  }

  Future<void> _loadUserProfile() async {
    try {
      final userApiService = GetIt.I<UserApiService>();
      final profile = await userApiService.getMyProfile();
      if (mounted) {
        setState(() {
          final loadedGender = profile['gender'] ?? profile['Gender'];
          if (loadedGender != null) {
            _gender = loadedGender.toString();
          }
          final loadedHeight = profile['heightCm'] ?? profile['HeightCm'];
          if (loadedHeight != null) {
            _height = double.tryParse(loadedHeight.toString()) ?? _height;
          }
          final loadedWeight = profile['weightKg'] ?? profile['WeightKg'];
          if (loadedWeight != null) {
            _weight = double.tryParse(loadedWeight.toString()) ?? _weight;
          }
          final phone = profile['phoneNumber'] ?? profile['PhoneNumber'];
          if (phone != null) {
            _phoneController.text = phone.toString();
          }
          final address = profile['address'] ?? profile['Address'];
          if (address != null) {
            _addressController.text = address.toString();
          }
          final country = profile['country'] ?? profile['Country'];
          if (country != null) {
            _selectedCountry = country.toString();
          }
          final dobStr = profile['dateOfBirth'] ?? profile['DateOfBirth'];
          if (dobStr != null) {
            final parsedDob = DateTime.tryParse(dobStr.toString());
            if (parsedDob != null) {
              _dob = parsedDob;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Lỗi tải profile trong style quiz: $e');
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _displayNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _nextStep() async {
    final totalSteps = widget.isOnboarding ? 8 : 4;

    if (widget.isOnboarding && _currentStep == 3) {
      final name = _displayNameController.text.trim();
      final phone = _phoneController.text.trim();
      final address = _addressController.text.trim();

      if (name.isEmpty) {
        _showError('Vui lòng nhập Biệt danh.');
        return;
      }
      if (phone.isEmpty) {
        _showError('Vui lòng nhập Số điện thoại.');
        return;
      }
      if (address.isEmpty) {
        _showError('Vui lòng nhập Địa chỉ.');
        return;
      }
    }

    if (_currentStep < totalSteps - 1) {
      await _slideController.reverse();
      setState(() => _currentStep++);
      _slideController.forward();
    } else {
      if (widget.isOnboarding) {
        await _saveAndFinishOnboarding();
      } else {
        await _saveAndFinish();
      }
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
      if (widget.onCompleted != null) {
        widget.onCompleted!();
      } else {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _saveAndFinishOnboarding() async {
    setState(() => _isSaving = true);
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();
    final country = _selectedCountry.trim();
    final name = _displayNameController.text.trim();

    try {
      final dobStr =
          "${_dob.year.toString().padLeft(4, '0')}-${_dob.month.toString().padLeft(2, '0')}-${_dob.day.toString().padLeft(2, '0')}";
      final skinToneVal = _skinTone ?? 'trung_binh';
      final bodyTypeVal = _bodyType ?? 'trung_binh';
      final stylePrefVal = _stylePref ?? 'casual';
      final colorPrefVal = _colorPref ?? 'trung_tinh';

      String lifestyleVal = 'Casual';
      if (stylePrefVal == 'casual') {
        lifestyleVal = 'Casual';
      } else if (stylePrefVal == 'sporty') {
        lifestyleVal = 'Sporty';
      } else if (stylePrefVal == 'cong_so') {
        lifestyleVal = 'Formal';
      } else if (stylePrefVal == 'thanh_lich') {
        lifestyleVal = 'Elegant';
      } else if (stylePrefVal == 'streetwear') {
        lifestyleVal = 'Streetwear';
      }

      final userApiService = GetIt.I<UserApiService>();
      await userApiService.updateMyProfile(
        displayName: name,
        gender: _gender,
        heightCm: _height,
        weightKg: _weight,
        dateOfBirth: dobStr,
        phoneNumber: phone.isNotEmpty ? phone : null,
        address: address.isNotEmpty ? address : null,
        country: country.isNotEmpty ? country : null,
        lifestyle: lifestyleVal,
        eyeColor: 'Brown',
        hair: 'Black',
        skinTone: skinToneVal,
        bodyType: bodyTypeVal,
        stylePref: stylePrefVal,
        colorPref: colorPrefVal,
      );

      await _localStorage.saveStyleDna(
        skinTone: skinToneVal,
        bodyType: bodyTypeVal,
        stylePref: stylePrefVal,
        colorPref: colorPrefVal,
      );

      await _localStorage.setOnboardingCompleted(true);
      await _localStorage.saveUser(
        userId: _localStorage.getUserId() ?? 0,
        email: _localStorage.getUserEmail() ?? '',
        displayName: name,
        role: _localStorage.getUserRole() ?? 'Customer',
        avatarUrl: _localStorage.getUserAvatar(),
        isOnboardingCompleted: true,
      );

      if (mounted) {
        AppRoutes.goToMain(context);
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        _showError(errorMsg);

        if (errorMsg.contains('401') ||
            errorMsg.toLowerCase().contains('unauthorized')) {
          await _localStorage.clearSession();
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) AppRoutes.goToLogin(context);
          });
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? get _currentAnswer {
    if (widget.isOnboarding) {
      if (_currentStep < 4) return null;
      final dnaIndex = _currentStep - 4;
      switch (dnaIndex) {
        case 0:
          return _skinTone;
        case 1:
          return _bodyType;
        case 2:
          return _stylePref;
        case 3:
          return _colorPref;
        default:
          return null;
      }
    } else {
      switch (_currentStep) {
        case 0:
          return _skinTone;
        case 1:
          return _bodyType;
        case 2:
          return _stylePref;
        case 3:
          return _colorPref;
        default:
          return null;
      }
    }
  }

  void _setAnswer(String value) {
    setState(() {
      final stepIndex = widget.isOnboarding ? _currentStep - 4 : _currentStep;
      switch (stepIndex) {
        case 0:
          _skinTone = value;
          break;
        case 1:
          _bodyType = value;
          break;
        case 2:
          _stylePref = value;
          break;
        case 3:
          _colorPref = value;
          break;
      }
    });
  }

  bool get _canProceed {
    if (widget.isOnboarding) {
      if (_currentStep == 0) return _gender != null;
      if (_currentStep == 1) return true;
      if (_currentStep == 2) return true;
      if (_currentStep == 3) {
        return _displayNameController.text.trim().isNotEmpty &&
            _phoneController.text.trim().isNotEmpty &&
            _addressController.text.trim().isNotEmpty;
      }
      final dnaIndex = _currentStep - 4;
      if (dnaIndex == 0) return _skinTone != null;
      if (dnaIndex == 1) return _bodyType != null;
      if (dnaIndex == 2) return _stylePref != null;
      if (dnaIndex == 3) return _colorPref != null;
      return false;
    } else {
      if (_currentStep == 0) return _skinTone != null;
      if (_currentStep == 1) return _bodyType != null;
      if (_currentStep == 2) return _stylePref != null;
      if (_currentStep == 3) return _colorPref != null;
      return false;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSteps = widget.isOnboarding ? 8 : 4;
    final isLastStep = _currentStep == totalSteps - 1;

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
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 40),
                  const Spacer(),
                  Text(
                    '${_currentStep + 1} / $totalSteps',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary.withOpacity(0.5),
                    ),
                  ),
                  const Spacer(),
                  // Skip button (only available if not onboarding)
                  if (!widget.isOnboarding)
                    GestureDetector(
                      onTap: () async {
                        await _localStorage.saveHasCompletedStyleQuiz(true);
                        if (widget.onCompleted != null) {
                          widget.onCompleted!();
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      child: Text(
                        'Bỏ qua',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primary.withOpacity(0.4),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 40),
                ],
              ),
            ),

            // ── Progress bar ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / totalSteps,
                  backgroundColor: AppColors.primary.withOpacity(0.08),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                  minHeight: 6,
                ),
              ),
            ),

            // ── Question/Step Content area ───────────────────────────
            Expanded(
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                    child: _buildCurrentStepContent(),
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
                    disabledBackgroundColor: AppColors.primary.withOpacity(
                      0.25,
                    ),
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
                              const Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
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

  Widget _buildCurrentStepContent() {
    if (widget.isOnboarding) {
      switch (_currentStep) {
        case 0:
          return _buildGenderStep();
        case 1:
          return _buildBodySizeStep();
        case 2:
          return _buildDobStep();
        case 3:
          return _buildContactStep();
        default:
          final dnaIndex = _currentStep - 4;
          final step = _dnaSteps[dnaIndex];
          return _buildDnaStepContent(step);
      }
    } else {
      final step = _dnaSteps[_currentStep];
      return _buildDnaStepContent(step);
    }
  }

  Widget _buildGenderStep() {
    final genderOptions = [
      _QuizOption(
        value: 'Male',
        label: 'Nam',
        desc: 'Gợi ý các mẫu trang phục nam',
        color: const Color(0xFFE3F2FD),
        textColor: const Color(0xFF1565C0),
        emoji: '👨',
      ),
      _QuizOption(
        value: 'Female',
        label: 'Nữ',
        desc: 'Gợi ý các mẫu trang phục nữ',
        color: const Color(0xFFFCE4EC),
        textColor: const Color(0xFFAD1457),
        emoji: '👩',
      ),
      _QuizOption(
        value: 'Other',
        label: 'Khác',
        desc: 'Gợi ý các mẫu trang phục phi giới tính',
        color: const Color(0xFFE8EAF6),
        textColor: const Color(0xFF283593),
        emoji: '🧑',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('👋', style: TextStyle(fontSize: 52)),
        const SizedBox(height: 12),
        const Text(
          'Chào mừng bạn!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Hãy chọn giới tính của bạn để chúng tôi gợi ý các mẫu trang phục phù hợp nhất.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.primary.withOpacity(0.55),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        ...genderOptions.map((opt) {
          final isSelected = _gender == opt.value;
          return GestureDetector(
            onTap: () {
              setState(() {
                _gender = opt.value;
              });
            },
            child: _buildSingleOptionCard(opt, isSelected),
          );
        }),
      ],
    );
  }

  Widget _buildBodySizeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('📏', style: TextStyle(fontSize: 52)),
        const SizedBox(height: 12),
        const Text(
          'Thể hình & Chỉ số',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Số đo chiều cao và cân nặng giúp hệ thống tạo hình ma-nơ-canh ảo (Mannequin) vừa vặn để bạn thử đồ.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.primary.withOpacity(0.55),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),

        // Height Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.height_rounded, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text(
                        'Chiều cao',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${_height.round()} cm',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Slider(
                value: _height,
                min: 100,
                max: 220,
                divisions: 120,
                activeColor: AppColors.primary,
                inactiveColor: const Color(0xFFFAF9F6),
                onChanged: (val) {
                  setState(() {
                    _height = val;
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Weight Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.scale_rounded, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text(
                        'Cân nặng',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${_weight.round()} kg',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Slider(
                value: _weight,
                min: 30,
                max: 150,
                divisions: 120,
                activeColor: AppColors.primary,
                inactiveColor: const Color(0xFFFAF9F6),
                onChanged: (val) {
                  setState(() {
                    _weight = val;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDobStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('🎂', style: TextStyle(fontSize: 52)),
        const SizedBox(height: 12),
        const Text(
          'Ngày sinh của bạn',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Chúng tôi kỷ niệm sinh nhật bạn bằng các ưu đãi thời trang và đề xuất phong cách phù hợp với độ tuổi.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.primary.withOpacity(0.55),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 40),
        Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFAF2EB),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cake_rounded,
                    color: AppColors.primary,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '${_dob.day.toString().padLeft(2, '0')} Tháng ${_dob.month.toString().padLeft(2, '0')}, ${_dob.year}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dob,
                      firstDate: DateTime(1940),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: AppColors.primary,
                              onPrimary: Colors.white,
                              onSurface: AppColors.primary,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setState(() {
                        _dob = picked;
                      });
                    }
                  },
                  icon: const Icon(Icons.date_range_rounded),
                  label: const Text('Chọn ngày sinh'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('📝', style: TextStyle(fontSize: 52)),
        const SizedBox(height: 12),
        const Text(
          'Thông tin cá nhân',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Kiểm tra lại biệt danh và cập nhật các thông tin liên lạc của bạn.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.primary.withOpacity(0.55),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              TextField(
                controller: _displayNameController,
                decoration: InputDecoration(
                  labelText: 'Biệt danh',
                  prefixIcon: const Icon(Icons.person_rounded),
                  fillColor: const Color(0xFFFAF9F6),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Số điện thoại',
                  prefixIcon: const Icon(Icons.phone_rounded),
                  fillColor: const Color(0xFFFAF9F6),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Địa chỉ',
                  prefixIcon: const Icon(Icons.location_on_rounded),
                  fillColor: const Color(0xFFFAF9F6),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12, left: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.public_rounded,
                        color: AppColors.primary.withOpacity(0.7),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Quốc gia',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _countries.map((c) {
                    final name = c['name']!;
                    final flag = c['flag']!;
                    final isSelected = _selectedCountry == name;
                    return ChoiceChip(
                      label: Text('$name $flag'),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedCountry = name;
                          });
                        }
                      },
                      backgroundColor: const Color(0xFFFAF9F6),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.primary,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected
                              ? Colors.transparent
                              : const Color(0x1A4A3728),
                        ),
                      ),
                      showCheckmark: false,
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDnaStepContent(_QuizStep step) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(step.emoji, style: const TextStyle(fontSize: 52)),
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
        ...step.options.map((opt) => _buildOptionCard(opt)),
      ],
    );
  }

  Widget _buildSingleOptionCard(_QuizOption opt, bool isSelected) {
    return AnimatedContainer(
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
              child: Text(opt.emoji, style: const TextStyle(fontSize: 22)),
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
                ? const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: AppColors.primary,
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(_QuizOption opt) {
    final isSelected = _currentAnswer == opt.value;
    return GestureDetector(
      onTap: () => _setAnswer(opt.value),
      child: _buildSingleOptionCard(opt, isSelected),
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
  final dynamic color;
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
