import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class WardrobePage extends StatelessWidget {
  const WardrobePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        title: const Text('TỦ ĐỒ', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5, fontSize: 20)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: () {},
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grid_view, size: 80, color: AppColors.primary.withOpacity(0.2)),
            const SizedBox(height: 16),
            const Text(
              'Tủ đồ của bạn',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tính năng đang được phát triển',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.primary.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
