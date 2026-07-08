import 'dart:async';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/app_routes.dart';
import '../../../data/datasources/auth_api_service.dart';

class VerifyOtpPage extends StatefulWidget {
  final String email;

  const VerifyOtpPage({super.key, required this.email});

  @override
  State<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends State<VerifyOtpPage> {
  final _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final _authService = GetIt.I<AuthApiService>();
  bool _isLoading = false;

  // Timer resend OTP
  Timer? _timer;
  int _countdown = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _focusNode.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _countdown = 60;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown == 0) {
        setState(() {
          _canResend = true;
        });
        _timer?.cancel();
      } else {
        setState(() {
          _countdown--;
        });
      }
    });
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đúng 6 chữ số mã OTP.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _authService.verifyOtp(widget.email, code);
      final role =
          (response['Role'] ?? response['role']) as String? ?? 'Customer';
      final isOnboarding =
          (response['IsOnboardingCompleted'] ??
                  response['isOnboardingCompleted'])
              as bool? ??
          false;
      if (mounted) {
        // Hiển thị thông báo thành công
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Xác thực thành công',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text(
              'Chào mừng bạn đến với V-Closet! Tài khoản của bạn đã được kích hoạt.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  if (role.toLowerCase() != 'customer' || isOnboarding) {
                    AppRoutes.goToMain(context);
                  } else {
                    AppRoutes.goToOnboarding(context);
                  }
                },
                child: const Text('Bắt đầu ngay'),
              ),
            ],
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

  Future<void> _resendOtp() async {
    if (!_canResend || _isLoading) return;

    setState(() => _isLoading = true);
    try {
      final msg = await _authService.resendOtp(widget.email);
      _startTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg.replaceAll('Exception: ', ''))),
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

    // Tính toán kích thước của từng ô nhập OTP để không bao giờ bị tràn chiều ngang
    final double totalPadding =
        (isSmallScreen ? 16.0 : 24.0) * 2 + (isSmallScreen ? 16.0 : 24.0) * 2;
    final double cellWidth = ((screenSize.width - totalPadding - 16) / 6).clamp(
      32.0,
      48.0,
    );
    final double cellHeight = isSmallScreen ? 44.0 : 52.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Xác thực tài khoản'),
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
                  Icons.mark_email_read_outlined,
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
                      'Nhập mã xác thực',
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandText,
                      ),
                    ),
                    SizedBox(height: spacingTiny),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: isSmallScreen ? 13.0 : 15.0,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                        children: [
                          const TextSpan(
                            text:
                                'Chúng tôi đã gửi mã OTP gồm 6 chữ số đến email của bạn tại ',
                          ),
                          TextSpan(
                            text: widget.email,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.brandText,
                            ),
                          ),
                          const TextSpan(
                            text: '. Vui lòng nhập mã để kích hoạt tài khoản.',
                          ),
                        ],
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
                    children: [
                      GestureDetector(
                        onTap: () {
                          _focusNode.requestFocus();
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Opacity(
                              opacity: 0,
                              child: TextField(
                                controller: _otpController,
                                focusNode: _focusNode,
                                autofocus: true,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                onChanged: (val) {
                                  if (val.length == 6) {
                                    _verifyOtp();
                                  }
                                  setState(() {});
                                },
                                decoration: const InputDecoration(
                                  counterText: "",
                                ),
                              ),
                            ),
                            IgnorePointer(
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: List.generate(6, (index) {
                                  final text = _otpController.text;
                                  String char = "";
                                  if (text.length > index) {
                                    char = text[index];
                                  }
                                  final isFocused = text.length == index;

                                  return Container(
                                    width: cellWidth,
                                    height: cellHeight,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFAF9F6),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isFocused
                                            ? AppColors.primaryLight
                                            : Colors.black.withOpacity(0.05),
                                        width: isFocused ? 2 : 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        char,
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 18.0 : 22.0,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.brandText,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 20.0 : 30.0),
                      if (_isLoading)
                        const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.brandText,
                          ),
                        )
                      else
                        ElevatedButton(
                          onPressed: _verifyOtp,
                          style: ElevatedButton.styleFrom(
                            padding: isSmallScreen
                                ? const EdgeInsets.symmetric(vertical: 12)
                                : const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Xác thực tài khoản',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 15.0 : 16.0,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.verified_rounded, size: 18),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: isSmallScreen ? 20.0 : 30.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Không nhận được mã? ',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: isSmallScreen ? 13.0 : 15.0,
                    ),
                  ),
                  _canResend
                      ? (_isLoading
                            ? Text(
                                'Đang gửi...',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: isSmallScreen ? 13.0 : 15.0,
                                ),
                              )
                            : GestureDetector(
                                onTap: _resendOtp,
                                child: Text(
                                  'Gửi lại ngay',
                                  style: TextStyle(
                                    color: AppColors.brandText,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                    fontSize: isSmallScreen ? 13.0 : 15.0,
                                  ),
                                ),
                              ))
                      : Text(
                          'Gửi lại sau (${_countdown}s)',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.bold,
                            fontSize: isSmallScreen ? 13.0 : 15.0,
                          ),
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
