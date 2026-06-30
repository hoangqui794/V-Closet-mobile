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
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

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
    serverClientId:
        '3533462823-2k0gvs8nl5urrqj4rdbkhrdjnrkci8ip.apps.googleusercontent.com',
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
        const SnackBar(
          content: Text('Vui lòng điền đầy đủ Email và Mật khẩu.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _authService.login(email, password);
      final role =
          (response['Role'] ?? response['role']) as String? ?? 'Customer';
      final isOnboarding =
          (response['IsOnboardingCompleted'] ??
                  response['isOnboardingCompleted'])
              as bool? ??
          false;
      if (mounted) {
        if (role.toLowerCase() != 'customer' || isOnboarding) {
          AppRoutes.goToMain(context);
        } else {
          AppRoutes.goToOnboarding(context);
        }
      }
    } catch (e) {
      if (mounted) {
        final errorStr = e.toString().replaceAll('Exception: ', '');
        if (errorStr.contains('Tài khoản đã bị khoá')) {
          _showReactivationDialog(email);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorStr), backgroundColor: AppColors.error),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showReactivationDialog(String initialEmail) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          backgroundColor: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_clock_outlined,
                    color: AppColors.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Thông báo',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Tài khoản của bạn đang bị tạm ngưng. Bạn có muốn gửi yêu cầu mở lại không?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: AppColors.onBackground,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppColors.accent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Hủy',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // Đóng popup xác nhận
                          _showEmailInputForReactivation(
                            initialEmail,
                          ); // Hiện popup nhập email
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Tiếp tục',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEmailInputForReactivation(String initialEmail) {
    final emailForReactivationController = TextEditingController(
      text: initialEmail,
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool dialogLoading = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              backgroundColor: AppColors.surface,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mail_outline_rounded,
                          color: AppColors.primary,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Khôi phục tài khoản',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Nhập email của bạn để gửi yêu cầu khôi phục tài khoản:',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: emailForReactivationController,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !dialogLoading,
                        decoration: InputDecoration(
                          labelText: 'Địa chỉ Email',
                          hintText: 'Nhập email của bạn',
                          prefixIcon: const Icon(Icons.email_outlined),
                          filled: true,
                          fillColor: AppColors.background.withOpacity(0.3),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: AppColors.primary.withOpacity(0.15),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: AppColors.primary.withOpacity(0.15),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Email không được để trống';
                          }
                          final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                          if (!emailRegex.hasMatch(value.trim())) {
                            return 'Email không đúng định dạng';
                          }
                          return null;
                        },
                      ),
                      if (dialogLoading) ...[
                        const SizedBox(height: 20),
                        const SizedBox(
                          height: 3,
                          child: LinearProgressIndicator(
                            color: AppColors.primary,
                            backgroundColor: AppColors.background,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: dialogLoading
                                  ? null
                                  : () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                side: const BorderSide(color: AppColors.accent),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Hủy',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: dialogLoading
                                  ? null
                                  : () async {
                                      if (formKey.currentState!.validate()) {
                                        setDialogState(
                                          () => dialogLoading = true,
                                        );
                                        try {
                                          final msg = await _authService
                                              .requestReactivation(
                                                emailForReactivationController
                                                    .text
                                                    .trim(),
                                              );
                                          if (context.mounted) {
                                            Navigator.pop(
                                              context,
                                            ); // Đóng Dialog
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(msg),
                                                backgroundColor: const Color(
                                                  0xFF27AE60,
                                                ),
                                              ),
                                            );
                                          }
                                        } catch (err) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  err.toString().replaceAll(
                                                    'Exception: ',
                                                    '',
                                                  ),
                                                ),
                                                backgroundColor:
                                                    AppColors.error,
                                              ),
                                            );
                                          }
                                        } finally {
                                          setDialogState(
                                            () => dialogLoading = false,
                                          );
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                backgroundColor: AppColors.primary,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Tiếp tục',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _googleLogin() async {
    setState(() => _isLoading = true);
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return;
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Không lấy được ID Token từ tài khoản Google của bạn.');
      }

      final response = await _authService.googleLogin(idToken);
      final role =
          (response['Role'] ?? response['role']) as String? ?? 'Customer';
      final isOnboarding =
          (response['IsOnboardingCompleted'] ??
                  response['isOnboardingCompleted'])
              as bool? ??
          false;
      final isPasswordSet =
          (response['IsPasswordSet'] ?? response['isPasswordSet']) as bool? ??
          true;

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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Lỗi đăng nhập Google',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $urlString');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể mở liên kết: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen =
        screenSize.height < 740 || screenSize.width < 360;

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
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
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
                                color: AppColors.primary.withOpacity(0.7),
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
                                color: Colors.black.withOpacity(0.03),
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
                                    color: AppColors.accent,
                                  ),
                                  fillColor: AppColors.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: isSmallScreen
                                      ? const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        )
                                      : const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 16,
                                        ),
                                ),
                              ),
                              SizedBox(height: spacingSmall),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Mật khẩu',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 13.0 : 14.0,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const ForgotPasswordPage(),
                                        ),
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      'Quên mật khẩu?',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 12.0 : 14.0,
                                      ),
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
                                    color: AppColors.accent,
                                  ),
                                  fillColor: AppColors.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: isSmallScreen
                                      ? const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        )
                                      : const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 16,
                                        ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isPasswordVisible
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isPasswordVisible =
                                            !_isPasswordVisible;
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
                                      : const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Đăng nhập',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 15.0 : 16.0,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 18,
                                    ),
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
                              color: AppColors.secondary.withOpacity(0.6),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'HOẶC TIẾP TỤC VỚI',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 10.0 : 12.0,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textMuted,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: AppColors.secondary.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: spacingSmall),
                      _socialButton(
                        label: 'Đăng nhập bằng Google',
                        icon: FontAwesomeIcons.google,
                        onTap: _googleLogin,
                        isSmallScreen: isSmallScreen,
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: isSmallScreen ? 11.0 : 12.0,
                              color: AppColors.textMuted,
                              height: 1.4,
                            ),
                            children: [
                              const TextSpan(
                                text: 'Bằng việc tiếp tục, bạn đồng ý với ',
                              ),
                              TextSpan(
                                text: 'Điều khoản Dịch vụ',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => _launchUrl(
                                    'https://api.vcloset.vn/terms.html',
                                  ),
                              ),
                              const TextSpan(text: ' và '),
                              TextSpan(
                                text: 'Chính sách bảo mật',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => _launchUrl(
                                    'https://api.vcloset.vn/privacy.html',
                                  ),
                              ),
                              const TextSpan(text: ' của V-Closet.'),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: spacingLarge),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Chưa có tài khoản? ',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13.0 : 15.0,
                              color: AppColors.primary.withOpacity(0.65),
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
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              icon,
              size: isSmallScreen ? 18 : 20,
              color: const Color(0xFFDB4437),
            ),
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
