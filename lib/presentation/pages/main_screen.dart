import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'home/home_page.dart';
import 'closet/wardrobe_page.dart';
import 'camera/camera_page.dart';
import 'outfit/outfit_page.dart';
import 'profile/profile_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const WardrobePage(),
    const CameraPage(),
    const OutfitPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFAF6),
        border: Border(top: BorderSide(color: AppColors.primary.withOpacity(0.08))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.people, 'Cộng đồng', 0),
          _buildNavItem(Icons.grid_view, 'Tủ đồ', 1),
          _buildNavItem(Icons.camera_alt, 'Chụp ảnh', 2),
          _buildNavItem(Icons.checkroom, 'Phối đồ', 3),
          _buildNavItem(Icons.person, 'Cá nhân', 4),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive)
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            ),
          const SizedBox(height: 4),
          Icon(icon, color: isActive ? AppColors.primary : const Color(0xFF8B7355), size: 24),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? AppColors.primary : const Color(0xFF8B7355),
            ),
          ),
        ],
      ),
    );
  }
}
