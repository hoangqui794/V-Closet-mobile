import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/datasources/auth_api_service.dart';
import 'verify_otp_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authService = GetIt.I<AuthApiService>();

  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirm = false;
  bool _agreeToTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (!_agreeToTerms) {
      _showSnackbar('Bạn phải đồng ý với Điều khoản dịch vụ và Chính sách bảo mật.');
      return;
    }

    if (name.isEmpty) {
      _showSnackbar('Vui lòng nhập Họ và tên.');
      return;
    }
    if (email.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showSnackbar('Vui lòng nhập định dạng Email hợp lệ.');
      return;
    }
    if (password.length < 6) {
      _showSnackbar('Mật khẩu phải có tối thiểu 6 ký tự.');
      return;
    }
    if (password != confirm) {
      _showSnackbar('Mật khẩu và Xác nhận mật khẩu không khớp.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final msg = await _authService.register(
        email: email,
        password: password,
        displayName: name,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg.replaceAll('Exception: ', ''))),
        );
        // Đi tới trang xác thực OTP và truyền email đi cùng
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerifyOtpPage(email: email),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar(e.toString().replaceAll('Exception: ', ''), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : null,
      ),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $urlString');
      }
    } catch (e) {
      _showSnackbar('Không thể mở liên kết: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen = screenSize.height < 740 || screenSize.width < 360;

    final double logoSize = isSmallScreen ? 70.0 : 90.0;
    final double spacingTiny = isSmallScreen ? 4.0 : 8.0;
    final double spacingSmall = isSmallScreen ? 8.0 : 12.0;
    final double spacingMedium = isSmallScreen ? 12.0 : 16.0;
    final double titleFontSize = isSmallScreen ? 20.0 : 24.0;
    final double cardPadding = isSmallScreen ? 14.0 : 20.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Đăng ký'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.primary,
        toolbarHeight: isSmallScreen ? 48 : 56,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 16.0 : 24.0,
            vertical: isSmallScreen ? 8.0 : 24.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              FadeInDown(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: logoSize,
                    width: logoSize,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.checkroom_rounded, size: logoSize, color: AppColors.primary);
                    },
                  ),
                ),
              ),
              SizedBox(height: spacingSmall),
              Text(
                'Tạo tài khoản mới',
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: spacingTiny / 2),
              Text(
                'Tham gia V-Closet để quản lý tủ đồ thông minh hơn',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.primary.withOpacity(0.7),
                  fontSize: isSmallScreen ? 13.0 : 14.0,
                ),
              ),
              SizedBox(height: spacingMedium),
              FadeInUp(
                child: Container(
                  padding: EdgeInsets.all(cardPadding),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Họ và tên',
                          hintText: 'Nhập họ tên của bạn',
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                          fillColor: const Color(0xFFFAF9F6),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: isSmallScreen 
                              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                              : const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                      SizedBox(height: spacingTiny),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'example@email.com',
                          prefixIcon: const Icon(Icons.email_outlined),
                          fillColor: const Color(0xFFFAF9F6),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: isSmallScreen 
                              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                              : const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                      SizedBox(height: spacingTiny),
                      TextField(
                        controller: _passwordController,
                        obscureText: !_showPassword,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu',
                          hintText: 'Tối thiểu 6 ký tự',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() => _showPassword = !_showPassword);
                            },
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                            ),
                          ),
                          fillColor: const Color(0xFFFAF9F6),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: isSmallScreen 
                              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                              : const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                      SizedBox(height: spacingTiny),
                      TextField(
                        controller: _confirmController,
                        obscureText: !_showConfirm,
                        decoration: InputDecoration(
                          labelText: 'Xác nhận mật khẩu',
                          hintText: 'Nhập lại mật khẩu',
                          prefixIcon: const Icon(Icons.verified_user_outlined),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() => _showConfirm = !_showConfirm);
                            },
                            icon: Icon(
                              _showConfirm
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                            ),
                          ),
                          fillColor: const Color(0xFFFAF9F6),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: isSmallScreen 
                              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                              : const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                      SizedBox(height: spacingSmall),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Checkbox(
                            value: _agreeToTerms,
                            activeColor: AppColors.primary,
                            onChanged: (val) {
                              setState(() {
                                _agreeToTerms = val ?? false;
                              });
                            },
                          ),
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Text(
                                  'Tôi đồng ý với ',
                                  style: TextStyle(fontSize: 13.0, color: AppColors.textMuted),
                                ),
                                GestureDetector(
                                  onTap: () => _launchUrl('https://api.vcloset.vn/terms.html'),
                                  child: const Text(
                                    'Điều khoản dịch vụ',
                                    style: TextStyle(
                                      fontSize: 13.0,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                                const Text(
                                  ' và ',
                                  style: TextStyle(fontSize: 13.0, color: AppColors.textMuted),
                                ),
                                GestureDetector(
                                  onTap: () => _launchUrl('https://api.vcloset.vn/privacy.html'),
                                  child: const Text(
                                    'Chính sách bảo mật',
                                    style: TextStyle(
                                      fontSize: 13.0,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: spacingMedium),
                      if (_isLoading)
                        const Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        )
                      else
                        ElevatedButton(
                          onPressed: _register,
                          style: ElevatedButton.styleFrom(
                            padding: isSmallScreen 
                                ? const EdgeInsets.symmetric(vertical: 12)
                                : const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text('Tạo tài khoản', style: TextStyle(fontSize: isSmallScreen ? 15.0 : 16.0)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
