import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/app_routes.dart';
import '../../../data/datasources/auth_api_service.dart';
import '../../../data/datasources/auth_local_storage.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authService = GetIt.I<AuthApiService>();
  final _localStorage = GetIt.I<AuthLocalStorage>();

  bool _isLoading = false;
  bool _showOldPassword = false;
  bool _showNewPassword = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final hasPassword = _localStorage.isPasswordSet();
    final oldPassword = hasPassword ? _oldPasswordController.text.trim() : '';
    final newPassword = _newPasswordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (hasPassword && oldPassword.isEmpty) {
      _showSnackbar('Vui lòng nhập mật khẩu cũ.');
      return;
    }
    if (newPassword.length < 6) {
      _showSnackbar('Mật khẩu mới phải có tối thiểu 6 ký tự.');
      return;
    }
    if (hasPassword && newPassword == oldPassword) {
      _showSnackbar('Mật khẩu mới không được trùng với mật khẩu cũ.');
      return;
    }
    if (newPassword != confirm) {
      _showSnackbar('Xác nhận mật khẩu mới không khớp.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final msg = await _authService.changePassword(oldPassword, newPassword);
      await _localStorage.setPasswordSet(true);
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Thành công', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Text(msg.replaceAll('Exception: ', '')),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Đóng dialog
                  final role = _localStorage.getUserRole() ?? 'Customer';
                  final isOnboarding = _localStorage.isOnboardingCompleted();
                  
                  if (!hasPassword) {
                    if (role.toLowerCase() != 'customer' || isOnboarding) {
                      AppRoutes.goToMain(context);
                    } else {
                      AppRoutes.goToOnboarding(context);
                    }
                  } else {
                    Navigator.of(context).pop(); // Quay lại màn Profile
                  }
                },
                child: const Text('Đồng ý'),
              ),
            ],
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

  @override
  Widget build(BuildContext context) {
    final hasPassword = _localStorage.isPasswordSet();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(hasPassword ? 'Đổi mật khẩu' : 'Tạo mật khẩu'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.primary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              FadeInDown(
                child: Text(
                  hasPassword ? 'Thay đổi mật khẩu' : 'Thiết lập mật khẩu',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              FadeInDown(
                delay: const Duration(milliseconds: 100),
                child: Text(
                  hasPassword
                      ? 'Vui lòng nhập mật khẩu hiện tại và mật khẩu mới để cập nhật bảo mật tài khoản của bạn.'
                      : 'Tài khoản của bạn chưa có mật khẩu ứng dụng. Vui lòng thiết lập mật khẩu mới.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.primary.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FadeInUp(
                delay: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.all(22),
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
                    children: [
                      if (hasPassword) ...[
                        TextField(
                          controller: _oldPasswordController,
                          obscureText: !_showOldPassword,
                          decoration: InputDecoration(
                            labelText: 'Mật khẩu hiện tại',
                            hintText: 'Nhập mật khẩu cũ',
                            prefixIcon: const Icon(Icons.lock_rounded),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() => _showOldPassword = !_showOldPassword);
                              },
                              icon: Icon(
                                _showOldPassword
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                              ),
                            ),
                            fillColor: const Color(0xFFFAF9F6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: _newPasswordController,
                        obscureText: !_showNewPassword,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu mới',
                          hintText: 'Tối thiểu 6 ký tự',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() => _showNewPassword = !_showNewPassword);
                            },
                            icon: Icon(
                              _showNewPassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                            ),
                          ),
                          fillColor: const Color(0xFFFAF9F6),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
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
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_isLoading)
                        const Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        )
                      else
                        ElevatedButton(
                          onPressed: _changePassword,
                          child: const Text('Cập nhật mật khẩu'),
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
