import 'package:flutter/material.dart';

class AppColors {
  // Primary colors (~Dusty Grape)
  static const Color primary = Color(0xFF4A4E69);
  static const Color primaryLight = Color(0xFF6B6F8A);
  static const Color primaryDark = Color(0xFF33364D);

  // Secondary/Accent colors (~Lilac Ash & Almond Silk)
  static const Color accent = Color(0xFF9A8C98);
  static const Color secondary = Color(
    0xFFC9ADA7,
  ); // Almond Silk (New: 0xFFDCD6F7)
  static const Color muted = Color(
    0xFFDDD5D0,
  ); // Soft warm grey-beige (New: 0xFFE5E0FF)

  // Neutral colors (~Seashell)
  static const Color background = Color(
    0xFFF2E9E4,
  ); // Seashell background (New: 0xFFF8F4FF)
  static const Color surface = Color(
    0xFFFAF6F4,
  ); // White with hint of warm beige (New: 0xFFFDFBFF)
  static const Color error = Color(0xFFC0392B);

  // Text colors
  static const Color onPrimary = Color(0xFFF2E9E4); // (New: 0xFFF8F4FF)
  static const Color onBackground = Color(0xFF4A4E69);
  static const Color onSurface = Color(0xFF4A4E69);
  static const Color textMuted = Color(0xFF9A8C98); // Lilac Ash
}
