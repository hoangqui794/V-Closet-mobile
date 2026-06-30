import 'dart:async';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/datasources/auth_api_service.dart';
import 'login_page.dart';

class ResetPasswordPage extends StatefulWidget {
  final String email;

  const ResetPasswordPage({super.key, required this.email});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authService = GetIt.I<AuthApiService>();

  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirm = false;
  Timer? _timer;
  int _countdown = 0;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _startTimer(); // Bắt đầu đếm ngược 60s ngay khi vào trang để tránh gửi dồn dập
  }

  @override
  void dispose() {
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
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

  Future<void> _resendOtp() async {
    if (_countdown > 0 || _isResending) return;
    setState(() => _isResending = true);
    try {
      final msg = await _authService.forgotPassword(widget.email);
      _startTimer();
      if (mounted) {
        _showSnackbar(msg);
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar(
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _resetPassword() async {
    final otpCode = _otpController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (otpCode.isEmpty) {
      _showSnackbar('Vui lòng nhập mã OTP.');
      return;
    }
    if (password.length < 6) {
      _showSnackbar('Mật khẩu mới phải có tối thiểu 6 ký tự.');
      return;
    }
    if (password != confirm) {
      _showSnackbar('Xác nhận mật khẩu mới không khớp.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final msg = await _authService.resetPassword(
        email: widget.email,
        otpCode: otpCode,
        newPassword: password,
      );
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Thành công',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(msg.replaceAll('Exception: ', '')),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                },
                child: const Text('Đăng nhập'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar(
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
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

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen =
        screenSize.height < 740 || screenSize.width < 360;

    final double spacingTiny = isSmallScreen ? 4.0 : 8.0;
    final double spacingMedium = isSmallScreen ? 12.0 : 16.0;
    final double titleFontSize = isSmallScreen ? 20.0 : 24.0;
    final double cardPadding = isSmallScreen ? 14.0 : 20.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Đặt lại mật khẩu'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.primary,
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
              FadeInDown(
                child: Text(
                  'Tạo mật khẩu mới',
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              SizedBox(height: spacingTiny / 2),
              FadeInDown(
                delay: const Duration(milliseconds: 100),
                child: Text(
                  'Nhập mã OTP đã nhận qua email và đặt lại mật khẩu mới cho tài khoản ${widget.email}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.primary.withOpacity(0.7),
                    fontSize: isSmallScreen ? 13.0 : 14.0,
                  ),
                ),
              ),
              SizedBox(height: spacingMedium),
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
                    children: [
                      TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Mã xác thực OTP',
                          hintText: 'Nhập mã OTP',
                          prefixIcon: const Icon(Icons.security_rounded),
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
                      SizedBox(height: spacingTiny),
                      TextField(
                        controller: _passwordController,
                        obscureText: !_showPassword,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu mới',
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
                      SizedBox(height: spacingTiny),
                      TextField(
                        controller: _confirmController,
                        obscureText: !_showConfirm,
                        decoration: InputDecoration(
                          labelText: 'Xác nhận mật khẩu mới',
                          hintText: 'Nhập lại mật khẩu mới',
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
                      SizedBox(height: spacingMedium),
                      if (_isLoading)
                        const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      else ...[
                        ElevatedButton(
                          onPressed: _resetPassword,
                          style: ElevatedButton.styleFrom(
                            padding: isSmallScreen
                                ? const EdgeInsets.symmetric(vertical: 12)
                                : const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            'Đặt lại mật khẩu',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 15.0 : 16.0,
                            ),
                          ),
                        ),
                        SizedBox(height: spacingMedium),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Không nhận được mã? ',
                              style: TextStyle(
                                color: AppColors.primary.withOpacity(0.6),
                                fontSize: isSmallScreen ? 13.0 : 14.0,
                              ),
                            ),
                            _countdown > 0
                                ? Text(
                                    'Gửi lại sau (${_countdown}s)',
                                    style: TextStyle(
                                      color: AppColors.primary.withOpacity(0.5),
                                      fontWeight: FontWeight.bold,
                                      fontSize: isSmallScreen ? 13.0 : 14.0,
                                    ),
                                  )
                                : _isResending
                                ? SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  )
                                : GestureDetector(
                                    onTap: _resendOtp,
                                    child: Text(
                                      'Gửi lại ngay',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                        fontSize: isSmallScreen ? 13.0 : 14.0,
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      ],
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
