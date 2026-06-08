import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/datasources/auth_local_storage.dart';
import '../../../data/datasources/auth_api_service.dart';
import '../../../data/datasources/user_api_service.dart';
import '../../../data/datasources/subscription_api_service.dart';
import '../auth/login_page.dart';
import 'change_password_page.dart';
import 'edit_profile_page.dart';
import 'subscription_page.dart';
import 'notification_page.dart';
import '../../../data/datasources/signalr_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _localStorage = GetIt.I<AuthLocalStorage>();
  final _userService = GetIt.I<UserApiService>();

  Map<String, dynamic>? _profileData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _userService.getMyProfile();
      try {
        await GetIt.I<SubscriptionApiService>().syncSubscriptionStatus();
      } catch (subErr) {
        print('Lỗi đồng bộ gói dịch vụ: $subErr');
      }
      setState(() {
        _profileData = profile;
      });
    } catch (e) {
      print('Lỗi tải thông tin cá nhân: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _goToEditProfile() async {
    if (_profileData == null) return;
    
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfilePage(initialProfile: _profileData!),
      ),
    );

    if (updated == true) {
      _fetchProfileData(); // Tải lại dữ liệu mới nhất
    }
  }

  Future<void> _deactivateAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Vô hiệu hóa tài khoản?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Hành động này sẽ vô hiệu hóa tài khoản của bạn trên hệ thống V-Closet. Bạn sẽ không thể đăng nhập bằng tài khoản này nữa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Đồng ý vô hiệu hóa'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final msg = await _userService.deactivateAccount();
      await SignalRService().disconnect();
      await GetIt.I<AuthApiService>().logout(); // Xoá token cục bộ

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Thông báo'),
            content: Text(msg),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
                  );
                },
                child: const Text('Đồng ý'),
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
    // Dự phòng khi chưa tải được API thì lấy thông tin lưu cục bộ
    final displayName = _profileData?['displayName']?.toString() ?? _localStorage.getUserName() ?? 'Người dùng';
    final email = _profileData?['email']?.toString() ?? _localStorage.getUserEmail() ?? '';
    final avatarUrl = _profileData?['avatarUrl']?.toString() ?? _localStorage.getUserAvatar();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _fetchProfileData,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    if (Navigator.canPop(context))
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 10, 20, 0),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              const Text(
                                'Hồ sơ cá nhân',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 34,
                                  backgroundColor: AppColors.accent,
                                  backgroundImage: avatarUrl != null && avatarUrl.startsWith('http')
                                      ? NetworkImage(avatarUrl) as ImageProvider
                                      : const AssetImage('assets/images/avatar1.png'),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        email,
                                        style: const TextStyle(color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: IconButton(
                                    onPressed: _goToEditProfile,
                                    icon: const Icon(
                                      Icons.settings_outlined,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _localStorage.getSubscriptionType() == 'free'
                              ? Colors.white
                              : const Color(0xFFFCF8F2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _localStorage.getSubscriptionType() == 'free'
                                ? AppColors.primary.withOpacity(0.08)
                                : const Color(0xFFD4AF37).withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(
                                        _localStorage.getSubscriptionType() == 'free'
                                            ? Icons.account_circle_outlined
                                            : Icons.stars_rounded,
                                        color: _localStorage.getSubscriptionType() == 'free'
                                            ? AppColors.primaryLight
                                            : const Color(0xFFD4AF37),
                                        size: 24,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _localStorage.getSubscriptionType() == 'free'
                                              ? 'Tài khoản miễn phí (FREE)'
                                              : 'Thành viên PREMIUM PRO',
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: _localStorage.getSubscriptionType() == 'free'
                                                ? AppColors.primary
                                                : const Color(0xFF996515),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const SubscriptionPage()),
                                    ).then((_) => setState(() {}));
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    _localStorage.getSubscriptionType() == 'free'
                                        ? 'Nâng cấp ngay'
                                        : 'Quản lý gói',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _localStorage.getSubscriptionType() == 'free'
                                          ? AppColors.primaryLight
                                          : const Color(0xFF996515),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24, thickness: 0.8),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Lượt xóa nền',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.photo_filter_rounded, size: 16, color: AppColors.primaryLight),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${_localStorage.getBgRemovalCredits()} lượt',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 1.5,
                                  height: 36,
                                  color: AppColors.primary.withOpacity(0.08),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Thử đồ AI',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.primaryLight),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${_localStorage.getTryOnCredits()} lượt',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tùy chọn',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _menuTile(
                              Icons.edit_note_rounded,
                              'Chỉnh sửa hồ sơ cá nhân',
                              onTap: _goToEditProfile,
                            ),
                            _menuTile(
                              Icons.lock_reset_rounded,
                              'Đổi mật khẩu',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const ChangePasswordPage()),
                                );
                              },
                            ),
                            _menuTile(
                              Icons.favorite_border_rounded,
                              'Danh sách yêu thích',
                            ),
                            _menuTile(Icons.shopping_bag_outlined, 'Đơn hàng của tôi'),
                            _menuTile(
                              Icons.workspace_premium_rounded,
                              'Gói Premium & Nạp Credits',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const SubscriptionPage()),
                                ).then((_) => setState(() {}));
                              },
                            ),
                            _menuTile(
                              Icons.notifications_outlined,
                              'Thông báo',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const NotificationPage()),
                                );
                              },
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Hỗ trợ & Bảo mật',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary),
                            ),
                            const SizedBox(height: 10),
                            _menuTile(Icons.help_outline_rounded, 'Trung tâm trợ giúp'),
                            _menuTile(
                              Icons.policy_outlined,
                              'Chính sách bảo mật',
                              onTap: () => _launchUrl('https://api.vcloset.vn/privacy.html'),
                            ),
                            _menuTile(
                              Icons.description_outlined,
                              'Điều khoản dịch vụ',
                              onTap: () => _launchUrl('https://api.vcloset.vn/terms.html'),
                            ),
                            _menuTile(
                              Icons.no_accounts_rounded,
                              'Vô hiệu hóa tài khoản',
                              onTap: _deactivateAccount,
                            ),
                            const SizedBox(height: 26),
                            OutlinedButton.icon(
                              onPressed: () async {
                                // Hiển thị loading dialog
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => const Center(
                                    child: CircularProgressIndicator(color: AppColors.primary),
                                  ),
                                );
                                
                                await SignalRService().disconnect();
                                await GetIt.I<AuthApiService>().logout();
                                
                                if (context.mounted) {
                                  Navigator.of(context).pop(); // Đóng loading dialog
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(builder: (_) => const LoginPage()),
                                    (route) => false,
                                  );
                                }
                              },
                              icon: const Icon(Icons.logout_rounded),
                              label: const Text('Đăng xuất'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                              ),
                            ),
                            const SizedBox(height: 120),
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

  Widget _menuTile(IconData icon, String title, {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.primary,
        ),
        onTap: onTap,
      ),
    );
  }
}
