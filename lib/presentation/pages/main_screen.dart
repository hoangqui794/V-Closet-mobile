import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../core/theme/app_colors.dart';
import '../../data/datasources/auth_api_service.dart';
import '../../data/datasources/auth_local_storage.dart';
import 'auth/login_page.dart';
import 'camera/camera_page.dart';
import 'closet/closet_page.dart';
import 'home/home_page.dart';
import 'outfit/outfit_page.dart';
import 'profile/profile_page.dart';
import 'profile/subscription_page.dart';
import 'store/store_page.dart';
import '../../data/datasources/subscription_api_service.dart';
import '../../data/datasources/signalr_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _localStorage = GetIt.I<AuthLocalStorage>();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _syncSubscription();
    SignalRService().initSignalR();
  }

  Future<void> _syncSubscription() async {
    try {
      await GetIt.I<SubscriptionApiService>().syncSubscriptionStatus();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Lỗi đồng bộ gói dịch vụ tại MainScreen: $e');
    }
  }

  // Nav items: index 2 là nút camera đặc biệt ở giữa
  static const List<(IconData, String)> _navItems = [
    (Icons.home_rounded, 'Trang chủ'),
    (Icons.checkroom_rounded, 'Tủ đồ'),
    (Icons.camera_alt_rounded, 'Camera'),
    (Icons.auto_awesome_rounded, 'Studio'),
    (Icons.shopping_bag_rounded, 'Cửa hàng'),
  ];

  late final List<Widget> _pages = [
    HomePage(
      onMenuPressed: _openDrawer,
      onNavigateTo: (index) => setState(() => _currentIndex = index),
    ),
    ClosetPage(onMenuPressed: _openDrawer),
    CameraPage(onClose: () => _onTapNav(1)),
    OutfitPage(onMenuPressed: _openDrawer),
    StorePage(onMenuPressed: _openDrawer),
  ];

  void _onTapNav(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }

  void _openDrawer() {
    debugPrint('DEBUG: _openDrawer triggered. scaffoldKey.currentState = ${_scaffoldKey.currentState}');
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final hideBottomNav = _currentIndex == 2;

    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      drawer: Drawer(
        backgroundColor: AppColors.background,
        child: Column(
          children: [
            // Drawer Header
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: AppColors.accent,
                backgroundImage: _localStorage.getUserAvatar() != null && _localStorage.getUserAvatar()!.startsWith('http')
                    ? NetworkImage(_localStorage.getUserAvatar()!) as ImageProvider
                    : const AssetImage('assets/images/avatar1.png'),
              ),
              accountName: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Expanded(
                    child: Text(
                      _localStorage.getUserName() ?? 'V-Closet User',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildSubscriptionBadge(),
                  const SizedBox(width: 16),
                ],
              ),
              accountEmail: Text(
                _localStorage.getUserEmail() ?? 'Tủ đồ ảo thông minh AI',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Menu Items
            ListTile(
              leading: const Icon(Icons.home_rounded, color: AppColors.primary),
              title: const Text('Trang chủ', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.checkroom_rounded, color: AppColors.primary),
              title: const Text('Tủ đồ cá nhân', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
              title: const Text('Studio Phối Đồ AI', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 3);
              },
            ),
            ListTile(
              leading: const Icon(Icons.shopping_bag_rounded, color: AppColors.primary),
              title: const Text('Cửa hàng', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 4);
              },
            ),
            // Gói Premium — đặt nổi bật để dễ nhìn thấy
            ListTile(
              leading: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFD4AF37)),
              title: const Text('Gói Premium & Nạp Credits', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF996515))),
              tileColor: const Color(0xFFFCF8F2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SubscriptionPage()),
                ).then((_) => setState(() {}));
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_rounded, color: AppColors.primary),
              title: const Text('Hồ sơ cá nhân', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                );
              },
            ),
            const Spacer(),
            const Divider(color: AppColors.accent, thickness: 1),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded, color: AppColors.primary),
              title: const Text('Giới thiệu V-Closet', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
              onTap: () {
                Navigator.pop(context);
                showAboutDialog(
                  context: context,
                  applicationName: 'V-Closet',
                  applicationVersion: '1.0.0',
                  applicationIcon: const Icon(Icons.checkroom_rounded, color: AppColors.primary, size: 40),
                  children: [
                    const Text('V-Closet là ứng dụng quản lý tủ đồ thông minh tích hợp công nghệ thử đồ ảo AI vượt trội.'),
                  ],
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.error),
              title: const Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
              onTap: () async {
                Navigator.pop(context); // Đóng drawer
                
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
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.02),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: _pages[_currentIndex],
        ),
      ),
      bottomNavigationBar: AnimatedSlide(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        offset: hideBottomNav ? const Offset(0, 1.5) : Offset.zero,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: hideBottomNav ? 0 : 1,
          child: IgnorePointer(
            ignoring: hideBottomNav,
            child: _buildDarkPillNav(),
          ),
        ),
      ),
    );
  }

  // ── Dark Pill Nav Bar ─────────────────────────────────────────────────────

  Widget _buildDarkPillNav() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: BorderRadius.circular(36),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withValues(alpha: 0.45),
                blurRadius: 28,
                spreadRadius: 0,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_navItems.length, (index) {
              if (index == 2) return _buildCenterCameraButton(index);
              return _buildNavItem(index);
            }),
          ),
        ),
      ),
    );
  }

  /// Item thường: icon trắng mờ → khi active hiện pill kem + icon nâu + label
  Widget _buildNavItem(int index) {
    final active = _currentIndex == index;
    final (icon, label) = _navItems[index];

    return GestureDetector(
      onTap: () => _onTapNav(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: active
            ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
            : const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.90)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: active
                  ? AppColors.primaryDark
                  : Colors.white.withValues(alpha: 0.60),
              size: active ? 20 : 22,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: active
                  ? Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  /// Nút camera giữa: tròn nổi lên trên, gradient, border trắng mờ
  Widget _buildCenterCameraButton(int index) {
    final active = _currentIndex == index;

    return GestureDetector(
      onTap: () => _onTapNav(index),
      child: Transform.translate(
        offset: const Offset(0, -14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: active
                  ? [AppColors.primaryLight, AppColors.primary]
                  : [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: active ? 0.35 : 0.20),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: active ? 0.55 : 0.32),
                blurRadius: active ? 24 : 14,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            Icons.camera_alt_rounded,
            color: Colors.white.withValues(alpha: active ? 1.0 : 0.85),
            size: 26,
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionBadge() {
    final isPremium = _localStorage.getHasActivePremium();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPremium
            ? const Color(0xFFD4AF37)
            : Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPremium ? const Color(0xFFFFD700) : Colors.white24,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPremium ? Icons.stars_rounded : Icons.account_circle_outlined,
            color: isPremium ? Colors.white : Colors.white70,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            isPremium ? 'PREMIUM' : 'FREE',
            style: TextStyle(
              color: isPremium ? Colors.white : Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
