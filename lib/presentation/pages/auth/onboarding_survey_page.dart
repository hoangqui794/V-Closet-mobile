import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/app_routes.dart';
import '../../../data/datasources/user_api_service.dart';
import '../../../data/datasources/auth_local_storage.dart';

class OnboardingSurveyPage extends StatefulWidget {
  const OnboardingSurveyPage({super.key});

  @override
  State<OnboardingSurveyPage> createState() => _OnboardingSurveyPageState();
}

class _OnboardingSurveyPageState extends State<OnboardingSurveyPage> {
  final _userApiService = GetIt.I<UserApiService>();
  final _localStorage = GetIt.I<AuthLocalStorage>();

  int _currentStep = 0;
  bool _isLoading = false;

  // Survey Data Fields
  String _gender = 'Male'; // Male, Female, Other
  double _height = 165.0; // cm
  double _weight = 55.0; // kg
  DateTime _dob = DateTime(2000, 1, 1);
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  String _selectedCountry = 'Việt Nam';
  final _displayNameController = TextEditingController();
  String _lifestyle = 'Casual'; // Casual, Sporty, Formal, Elegant, Minimalist, Streetwear
  String _eyeColor = 'Brown'; // Black, Brown, Blue, Green, Grey
  String _hair = 'Black'; // Black, Brown, Blonde, Red, Platinum, Other

  // Countries translation/flag list
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

  // Feature translation maps
  static const Map<String, String> _lifestyleMap = {
    'Casual': 'Thường ngày',
    'Sporty': 'Thể thao',
    'Formal': 'Trang trọng',
    'Elegant': 'Lịch lãm',
    'Minimalist': 'Tối giản',
    'Streetwear': 'Đường phố',
  };

  static const Map<String, String> _eyeColorMap = {
    'Black': 'Đen',
    'Brown': 'Nâu',
    'Blue': 'Xanh dương',
    'Green': 'Xanh lá',
    'Grey': 'Xám',
  };

  static const Map<String, String> _hairMap = {
    'Black': 'Đen',
    'Brown': 'Nâu',
    'Blonde': 'Vàng',
    'Red': 'Đỏ',
    'Platinum': 'Bạch kim',
    'Other': 'Khác',
  };

  @override
  void initState() {
    super.initState();
    _displayNameController.text = _localStorage.getUserName() ?? '';
    _checkUserSession();
  }

  Future<void> _checkUserSession() async {
    final token = _localStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      _redirectToLogin();
      return;
    }

    try {
      final profile = await _userApiService.getMyProfile();
      final isOnboarding = (profile['IsOnboardingCompleted'] ?? profile['isOnboardingCompleted']) as bool? ?? false;
      if (isOnboarding) {
        await _localStorage.setOnboardingCompleted(true);
        await _localStorage.saveUser(
          userId: profile['UserId'] ?? profile['userId'] ?? _localStorage.getUserId() ?? 0,
          email: profile['Email'] ?? profile['email'] ?? _localStorage.getUserEmail() ?? '',
          displayName: profile['DisplayName'] ?? profile['displayName'] ?? _localStorage.getUserName() ?? '',
          role: profile['Role'] ?? profile['role'] ?? _localStorage.getUserRole() ?? 'Customer',
          avatarUrl: profile['AvatarUrl'] ?? profile['avatarUrl'] ?? _localStorage.getUserAvatar(),
          isOnboardingCompleted: true,
        );
        if (mounted) {
          AppRoutes.goToMain(context);
        }
      }
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('401') || errorMsg.toLowerCase().contains('unauthorized')) {
        _redirectToLogin();
      }
    }
  }

  void _redirectToLogin() async {
    await _localStorage.clearSession();
    if (mounted) {
      _showError('Phiên làm việc đã hết hạn. Vui lòng đăng nhập lại.');
      AppRoutes.goToLogin(context);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentStep < 4) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _prevPage() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  Future<void> _submitSurvey() async {
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();
    final country = _selectedCountry.trim();
    final name = _displayNameController.text.trim();

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
    if (country.isEmpty) {
      _showError('Vui lòng chọn Quốc gia.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dobStr = "${_dob.year.toString().padLeft(4, '0')}-${_dob.month.toString().padLeft(2, '0')}-${_dob.day.toString().padLeft(2, '0')}";
      
      // Tự động map dữ liệu Style DNA dựa trên khảo sát đăng ký để tránh hỏi 2 lần
      String stylePref = 'casual';
      if (_lifestyle == 'Sporty') {
        stylePref = 'sporty';
      } else if (_lifestyle == 'Formal') {
        stylePref = 'cong_so';
      } else if (_lifestyle == 'Elegant') {
        stylePref = 'thanh_lich';
      } else if (_lifestyle == 'Streetwear') {
        stylePref = 'streetwear';
      }

      String bodyType = 'trung_binh';
      if (_height < 160.0) {
        bodyType = 'nho_nhan';
      } else if (_height > 165.0) {
        bodyType = 'cao_rao';
      }
      
      final skinTone = 'trung_binh';
      final colorPref = 'trung_tinh';

      await _userApiService.updateMyProfile(
        displayName: name,
        gender: _gender,
        heightCm: _height,
        weightKg: _weight,
        dateOfBirth: dobStr,
        phoneNumber: phone.isNotEmpty ? phone : null,
        address: address.isNotEmpty ? address : null,
        country: country.isNotEmpty ? country : null,
        lifestyle: _lifestyle,
        eyeColor: _eyeColor,
        hair: _hair,
        skinTone: skinTone,
        bodyType: bodyType,
        stylePref: stylePref,
        colorPref: colorPref,
      );

      await _localStorage.saveStyleDna(
        skinTone: skinTone,
        bodyType: bodyType,
        stylePref: stylePref,
        colorPref: colorPref,
      );
      await _localStorage.saveHasCompletedStyleQuiz(true);

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

        // Tự động chuyển hướng về trang đăng nhập nếu phiên làm việc hết hạn (Lỗi 401)
        if (errorMsg.contains('401') || errorMsg.toLowerCase().contains('unauthorized')) {
          await _localStorage.clearSession();
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) AppRoutes.goToLogin(context);
          });
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    try {
      final totalSteps = 5;
      final progress = (_currentStep + 1) / totalSteps;

      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text(
                      'Đang tối ưu hóa tủ đồ của bạn...',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  // Progress indicator
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Khảo sát cá nhân',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary.withOpacity(0.6),
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              'Bước ${_currentStep + 1}/$totalSteps',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: const Color(0xFFEFE6DD),
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Dynamic step rendering using IndexedStack to maintain static widget tree for semantics
                  Expanded(
                    child: IndexedStack(
                      index: _currentStep,
                      children: [
                        _buildGenderStep(),
                        _buildBodySizeStep(),
                        _buildFeaturesStep(),
                        _buildDobStep(),
                        _buildContactStep(),
                      ],
                    ),
                  ),

                  // Footer navigation buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Back Button
                        Opacity(
                          opacity: _currentStep > 0 ? 1.0 : 0.0,
                          child: IgnorePointer(
                            ignoring: _currentStep == 0,
                            child: OutlinedButton(
                              onPressed: _prevPage,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 52),
                                side: const BorderSide(color: Color(0xFFDCCBB5)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.arrow_back_rounded, size: 18),
                                  SizedBox(width: 6),
                                  Text('Quay lại'),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Next or Submit Button
                        ElevatedButton(
                          onPressed: _currentStep == 4 ? _submitSurvey : _nextPage,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 54),
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
                          ),
                          child: Row(
                            children: [
                              Text(_currentStep == 4 ? 'Hoàn tất' : 'Tiếp theo'),
                              const SizedBox(width: 6),
                              Icon(
                                _currentStep == 4
                                    ? Icons.done_all_rounded
                                    : Icons.arrow_forward_rounded,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        ),
      );
    } catch (e, stack) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: SelectableText(
                'LỖI THỰC THI (Onboarding):\n$e\n\nStack:\n$stack',
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
          ),
        ),
      );
    }
  }

  // Step 1: Gender Selection
  Widget _buildGenderStep() {
    final genders = [
      {'value': 'Male', 'label': 'Nam', 'icon': Icons.male_rounded},
      {'value': 'Female', 'label': 'Nữ', 'icon': Icons.female_rounded},
      {'value': 'Other', 'label': 'Khác', 'icon': Icons.transgender_rounded},
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chào mừng bạn!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hãy chọn giới tính của bạn để chúng tôi gợi ý các mẫu trang phục phù hợp nhất.',
              style: TextStyle(fontSize: 15, color: AppColors.textMuted, height: 1.4),
            ),
            const SizedBox(height: 32),
            // Directly map list to avoid listview size issues
            ...genders.map((item) {
              final value = item['value'] as String;
              final isSelected = _gender == value;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _gender = value;
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFFAF2EB) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.black.withOpacity(0.05),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isSelected ? 0.04 : 0.01),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : const Color(0xFFFAF9F6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            item['icon'] as IconData,
                            color: isSelected ? Colors.white : AppColors.primary.withOpacity(0.6),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Text(
                          item['label'] as String,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const Spacer(),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.primary,
                            size: 26,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // Step 2: Body Size Selection (Height & Weight)
  Widget _buildBodySizeStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thể hình & Chỉ số',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Số đo chiều cao và cân nặng giúp hệ thống tạo hình ma-nơ-canh ảo (Mannequin) vừa vặn để bạn thử đồ.',
              style: TextStyle(fontSize: 15, color: AppColors.textMuted, height: 1.4),
            ),
            const SizedBox(height: 30),
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
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ],
                      ),
                      Text(
                        '${_height.round()} cm',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary),
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
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ],
                      ),
                      Text(
                        '${_weight.round()} kg',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary),
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
        ),
      ),
    );
  }

  // Step 3: Date of Birth Selection
  Widget _buildDobStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ngày sinh của bạn',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Chúng tôi kỷ niệm sinh nhật bạn bằng các ưu đãi thời trang và đề xuất phong cách phù hợp với độ tuổi.',
              style: TextStyle(fontSize: 15, color: AppColors.textMuted, height: 1.4),
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
        ),
      ),
    );
  }

  // Step 4: Contact & Personal Info
  Widget _buildContactStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thông tin cá nhân',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cuối cùng, hãy kiểm tra lại biệt danh và cập nhật các thông tin liên lạc của bạn.',
              style: TextStyle(fontSize: 15, color: AppColors.textMuted, height: 1.4),
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
                  // Display Name TextField
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

                  // Phone Number TextField
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

                  // Address TextField
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

                  // Country Selection Section
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12, left: 4),
                      child: Row(
                        children: [
                          Icon(Icons.public_rounded, color: AppColors.primary.withOpacity(0.7), size: 20),
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
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected ? Colors.transparent : const Color(0x1A4A3728),
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
        ),
      ),
    );
  }

  // Step 3: Features Selection (Lifestyle, Eye Color, Hair)
  Widget _buildFeaturesStep() {
    final lifestyles = ['Casual', 'Sporty', 'Formal', 'Elegant', 'Minimalist', 'Streetwear'];
    final eyeColors = ['Black', 'Brown', 'Blue', 'Green', 'Grey'];
    final hairs = ['Black', 'Brown', 'Blonde', 'Red', 'Platinum', 'Other'];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Phong cách & Đặc điểm',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hãy chia sẻ phong cách thời trang và các đặc điểm ngoại hình của bạn để mô hình AI gợi ý phong cách tốt nhất.',
              style: TextStyle(fontSize: 15, color: AppColors.textMuted, height: 1.4),
            ),
            const SizedBox(height: 24),

            // Lifestyle Card
            _buildFeatureSection(
              title: 'Phong cách yêu thích',
              icon: Icons.style_rounded,
              choices: lifestyles,
              selectedValue: _lifestyle,
              translationMap: _lifestyleMap,
              onSelected: (val) {
                setState(() {
                  _lifestyle = val;
                });
              },
            ),
            const SizedBox(height: 20),

            // Eye Color Card
            _buildFeatureSection(
              title: 'Màu mắt',
              icon: Icons.visibility_rounded,
              choices: eyeColors,
              selectedValue: _eyeColor,
              translationMap: _eyeColorMap,
              onSelected: (val) {
                setState(() {
                  _eyeColor = val;
                });
              },
            ),
            const SizedBox(height: 20),

            // Hair Card
            _buildFeatureSection(
              title: 'Màu tóc',
              icon: Icons.face_rounded,
              choices: hairs,
              selectedValue: _hair,
              translationMap: _hairMap,
              onSelected: (val) {
                setState(() {
                  _hair = val;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureSection({
    required String title,
    required IconData icon,
    required List<String> choices,
    required String selectedValue,
    required ValueChanged<String> onSelected,
    Map<String, String>? translationMap,
  }) {
    return Container(
      width: double.infinity,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: choices.map((choice) {
              final isSelected = selectedValue == choice;
              final labelText = translationMap != null ? (translationMap[choice] ?? choice) : choice;
              return ChoiceChip(
                label: Text(labelText),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) onSelected(choice);
                },
                backgroundColor: const Color(0xFFFAF9F6),
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.primary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected ? Colors.transparent : const Color(0x1A4A3728),
                  ),
                ),
                showCheckmark: false,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}


