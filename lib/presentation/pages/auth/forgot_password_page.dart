import 'dart:async';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/datasources/auth_api_service.dart';
import 'reset_password_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _authService = GetIt.I<AuthApiService>();
  bool _isLoading = false;
  Timer? _timer;
  int _countdown = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _countdown = 60;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown == 0) {
        setState(() {
          _timer?.cancel();
        });
      } else {
        setState(() {
          _countdown--;
        });
      }
    });
  }

  Future<void> _submitEmail() async {
    if (_countdown > 0) return;

    final email = _emailController.text.trim();
    if (email.isEmpty ||
        !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập định dạng Email hợp lệ.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final msg = await _authService.forgotPassword(email);
      _startTimer(); // Bắt đầu đếm ngược 60s sau khi gửi thành công
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg.replaceAll('Exception: ', ''))),
        );
        // Chuyển sang trang đặt lại mật khẩu mới, truyền email đi kèm
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResetPasswordPage(email: email),
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen =
        screenSize.height < 740 || screenSize.width < 360;

    final double logoSize = isSmallScreen ? 70.0 : 90.0;
    final double spacingTiny = isSmallScreen ? 4.0 : 8.0;
    final double spacingSmall = isSmallScreen ? 8.0 : 12.0;
    final double spacingMedium = isSmallScreen ? 12.0 : 16.0;
    final double spacingLarge = isSmallScreen ? 14.0 : 20.0;
    final double titleFontSize = isSmallScreen ? 20.0 : 24.0;
    final double cardPadding = isSmallScreen ? 14.0 : 20.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quên mật khẩu'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.brandText,
        toolbarHeight: isSmallScreen ? 48 : 56,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
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
                child: Icon(
                  Icons.lock_open_rounded,
                  size: logoSize,
                  color: AppColors.brandText,
                ),
              ),
              SizedBox(height: spacingMedium),
              FadeInDown(
                delay: const Duration(milliseconds: 100),
                child: Column(
                  children: [
                    Text(
                      'Khôi phục mật khẩu',
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandText,
                      ),
                    ),
                    SizedBox(height: spacingTiny),
                    Text(
                      'Nhập email đã đăng ký của bạn. Chúng tôi sẽ gửi mã xác thực OTP để đặt lại mật khẩu mới.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 13.0 : 15.0,
                        color: AppColors.primary.withOpacity(0.7),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: spacingLarge),
              FadeInUp(
                delay: const Duration(milliseconds: 200),
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
                          color: AppColors.brandText,
                        ),
                      ),
                      SizedBox(height: spacingTiny),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'example@email.com',
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
                      SizedBox(height: spacingLarge),
                      if (_isLoading)
                        const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.brandText,
                          ),
                        )
                      else
                        ElevatedButton(
                          onPressed: _countdown > 0 ? null : _submitEmail,
                          style: ElevatedButton.styleFrom(
                            padding: isSmallScreen
                                ? const EdgeInsets.symmetric(vertical: 12)
                                : const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _countdown > 0
                                    ? 'Gửi lại mã (${_countdown}s)'
                                    : 'Gửi mã OTP',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 15.0 : 16.0,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
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
