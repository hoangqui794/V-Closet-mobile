import 'package:flutter/material.dart';

class AppColors {
  // --- 10% ACTION (Nút bấm, điểm nhấn) ---
  static const Color primary = Color(0xFF0F172A); // Navy sâu làm màu chính cho chữ và điểm nhấn chính
  static const Color primaryLight = Color(0xFF87CEEB); // Sky Blue làm màu sáng/accent chính
  static const Color primaryDark = Color(0xFF020617); // Navy siêu tối cho nền thanh điều hướng (Bottom Bar)
  static const Color accent = Color(0xFF87CEEB); // Sky Blue làm accent

  // --- 60% SPACE (Không gian nền) ---
  static const Color background = Color(0xFFFFFFFF); // Trắng tinh khiết làm nền chính
  static const Color surface = Color(0xFFFFFFFF); // Trắng làm bề mặt thẻ
  static const Color error = Color(0xFFE63946); // Đỏ báo lỗi chuẩn

  // --- 30% CONTENT (Nội dung, Chữ, Icon) ---
  static const Color secondary = Color(0xFF87CEEB); // Sky Blue làm màu phụ (nền active bottom nav pill)
  static const Color muted = Color(0xFFE2E8F0); // Xám xanh mờ (Cool grey) làm viền và màu phụ
  
  // Đảm bảo chữ trên nền nút Sky Blue là Navy Sâu để chống chói
  static const Color onPrimary = Color(0xFFFFFFFF); // Chữ trắng trên nền Navy sâu
  
  // Chữ trên nền trắng
  static const Color onBackground = Color(0xFF0F172A); // Navy Sâu
  static const Color onSurface = Color(0xFF0F172A); // Navy Sâu
  
  // Chữ phụ, viền mờ (Navy sáng hơn một chút)
  static const Color textMuted = Color(0xFF64748B); // Slate Blue
  static const Color borderLight = Color(0xFFE2E8F0); // Viền siêu mờ
}