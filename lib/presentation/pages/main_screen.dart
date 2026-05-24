import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'camera/camera_page.dart';
import 'closet/closet_page.dart';
import 'home/home_page.dart';
import 'outfit/outfit_page.dart';
import 'profile/profile_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Nav items: index 2 là nút camera đặc biệt ở giữa
  static const List<(IconData, String)> _navItems = [
    (Icons.home_rounded, 'Trang chủ'),
    (Icons.checkroom_rounded, 'Tủ đồ'),
    (Icons.camera_alt_rounded, 'Camera'),
    (Icons.auto_awesome_rounded, 'Studio'),
    (Icons.person_rounded, 'Hồ sơ'),
  ];

  late final List<Widget> _pages = [
    const HomePage(),
    const ClosetPage(),
    CameraPage(onClose: () => _onTapNav(1)),
    const OutfitPage(),
    const ProfilePage(),
  ];

  void _onTapNav(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final hideBottomNav = _currentIndex == 2;

    return Scaffold(
      extendBody: true,
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
}
