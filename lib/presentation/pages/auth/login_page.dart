import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/app_routes.dart';
import '../../../data/datasources/auth_api_service.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';
import '../profile/change_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _authService = GetIt.I<AuthApiService>();
  
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: '3533462823-2k0gvs8nl5urrqj4rdbkhrdjnrkci8ip.apps.googleusercontent.com',
  );

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền đầy đủ Email và Mật khẩu.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _authService.login(email, password);
      final role = (response['Role'] ?? response['role']) as String? ?? 'Customer';
      final isOnboarding =
          (response['IsOnboardingCompleted'] ?? response['isOnboardingCompleted']) as bool? ?? false;
      if (mounted) {
        if (role.toLowerCase() != 'customer' || isOnboarding) {
          AppRoutes.goToMain(context);
        } else {
          AppRoutes.goToOnboarding(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _googleLogin() async {
    setState(() => _isLoading = true);
    try {
      // Bắt đầu luồng đăng nhập Google
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // Người dùng hủy đăng nhập
        return;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Không lấy được ID Token từ tài khoản Google của bạn.');
      }

      // Gửi Token lên API Backend
      final response = await _authService.googleLogin(idToken);
      final role = (response['Role'] ?? response['role']) as String? ?? 'Customer';
      final isOnboarding =
          (response['IsOnboardingCompleted'] ?? response['isOnboardingCompleted']) as bool? ?? false;
      final isPasswordSet =
          (response['IsPasswordSet'] ?? response['isPasswordSet']) as bool? ?? true;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đăng nhập bằng tài khoản Google thành công!'),
            backgroundColor: Color(0xFF27AE60),
          ),
        );
        if (!isPasswordSet) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ChangePasswordPage()),
          );
        } else if (role.toLowerCase() != 'customer' || isOnboarding) {
          AppRoutes.goToMain(context);
        } else {
          AppRoutes.goToOnboarding(context);
        }
      }
    } catch (e) {
      print('Lỗi đăng nhập Google: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Lỗi đăng nhập Google', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Text(
              'Xảy ra lỗi khi xác thực: ${e.toString().replaceAll('Exception: ', '')}\n\n'
              'Lưu ý: Để chạy thực tế tính năng đăng nhập Google, bạn cần đăng ký SHA-1 fingerprint của ứng dụng trên Firebase Console và cấu hình tệp google-services.json chính xác. Bạn có thể sử dụng tài khoản/mật khẩu để đăng nhập thông thường.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen = screenSize.height < 740 || screenSize.width < 360;

    final double logoSize = isSmallScreen ? 80.0 : 100.0;
    final double spacingTiny = isSmallScreen ? 4.0 : 8.0;
    final double spacingSmall = isSmallScreen ? 8.0 : 12.0;
    final double spacingMedium = isSmallScreen ? 12.0 : 16.0;
    final double spacingLarge = isSmallScreen ? 14.0 : 20.0;
    final double titleFontSize = isSmallScreen ? 24.0 : 28.0;
    final double cardPadding = isSmallScreen ? 14.0 : 20.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 16.0 : 24.0,
                    vertical: isSmallScreen ? 12.0 : 20.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: spacingSmall),
                      FadeInDown(
                        duration: const Duration(milliseconds: 700),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/images/logo.png',
                            height: logoSize,
                            width: logoSize,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      SizedBox(height: spacingSmall),
                      Text(
                        'V-CLOSET',
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(height: spacingMedium),
                      FadeInDown(
                        delay: const Duration(milliseconds: 120),
                        child: Column(
                          children: [
                            Text(
                              'Chào mừng trở lại',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 20.0 : 24.0,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            SizedBox(height: spacingTiny / 2),
                            Text(
                              'Đăng nhập để tiếp tục hành trình thời trang của bạn',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 13.0 : 15.0,
                                color: AppColors.primary.withValues(alpha: 0.7),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: spacingLarge),
                      FadeInUp(
                        delay: const Duration(milliseconds: 220),
                        child: Container(
                          padding: EdgeInsets.all(cardPadding),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 18,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Địa chỉ Email',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 13.0 : 14.0,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              SizedBox(height: spacingTiny),
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  hintText: 'Nhập email của bạn',
                                  prefixIcon: const Icon(
                                    Icons.email_rounded,
                                    color: Color(0xFFD4A373),
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
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Mật khẩu',
                                    style: TextStyle(
                                        fontSize: isSmallScreen ? 13.0 : 14.0,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const ForgotPasswordPage(),
                                        ),
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      'Quên mật khẩu?',
                                      style: TextStyle(fontSize: isSmallScreen ? 12.0 : 14.0),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: spacingTiny),
                              TextField(
                                controller: _passwordController,
                                obscureText: !_isPasswordVisible,
                                decoration: InputDecoration(
                                  hintText: '••••••••',
                                  prefixIcon: const Icon(
                                    Icons.lock_rounded,
                                    color: Color(0xFFD4A373),
                                  ),
                                  fillColor: const Color(0xFFFAF9F6),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: isSmallScreen 
                                      ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                                      : const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isPasswordVisible
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isPasswordVisible = !_isPasswordVisible;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              SizedBox(height: spacingLarge),
                              ElevatedButton(
                                onPressed: _login,
                                style: ElevatedButton.styleFrom(
                                  padding: isSmallScreen 
                                      ? const EdgeInsets.symmetric(vertical: 12)
                                      : const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('Đăng nhập', style: TextStyle(fontSize: isSmallScreen ? 15.0 : 16.0)),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward_rounded, size: 18),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: spacingLarge),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: const Color(0xFFDCCBB5).withValues(alpha: 0.6),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'HOẶC TIẾP TỤC VỚI',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 10.0 : 12.0,
                                fontWeight: FontWeight.bold,
                                color: const Color(0x664A3728),
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: const Color(0xFFDCCBB5).withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: spacingSmall),
                      // Nút đăng nhập Google full width, bỏ hoàn toàn nút Apple
                      _socialButton(
                        label: 'Đăng nhập bằng Google',
                        icon: FontAwesomeIcons.google,
                        onTap: _googleLogin,
                        isSmallScreen: isSmallScreen,
                      ),
                      SizedBox(height: spacingLarge),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Chưa có tài khoản? ',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13.0 : 15.0,
                              color: AppColors.primary.withValues(alpha: 0.65),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RegisterPage(),
                                ),
                              );
                            },
                            child: Text(
                              'Đăng ký ngay',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 13.0 : 15.0,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _socialButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isSmallScreen,
  }) {
    return Container(
      width: double.infinity,
      height: isSmallScreen ? 46 : 54,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(icon, size: isSmallScreen ? 18 : 20, color: const Color(0xFFDB4437)),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: isSmallScreen ? 14.0 : 15.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
