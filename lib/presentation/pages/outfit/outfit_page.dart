import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class OutfitPage extends StatelessWidget {
  const OutfitPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        title: const Text('PHỐI ĐỒ', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5, fontSize: 20)),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.checkroom, size: 80, color: AppColors.primary.withOpacity(0.2)),
            const SizedBox(height: 16),
            const Text(
              'Gợi ý phối đồ AI',
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
