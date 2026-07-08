import 'package:flutter/material.dart';

/// ════════════════════════════════════════════════════════════════════════════
/// ĐỂ ĐỔI TOÀN BỘ MÀU SẮC APP — CHỈ CẦN SỬA 2 DÒNG NÀY:
/// ════════════════════════════════════════════════════════════════════════════
class AppColors {
  // ─── 🎨 2 NGUỒN MÀU GỐC (chỉ cần đổi ở đây) ─────────────────────────────────────────
  static const Color _brand     = Color(0xFF2C3050); // Màu chủ đạo
  static const Color _brandDark = Color(0xFF2C3050); // Tối hơn Dusty Grape — chữ đậm

  // ─── UI BACKGROUNDS & ACCENTS ─────────────────────────────────────────
  /// Dùng làm NỀN: nút bấm, header, tab, indicator, badge nền
  static const Color primary      = _brand;
  static const Color primaryLight = Color(0xFF9A8C98); // Màu phụ — chip, highlight
  static const Color primaryDark  = Color(0xFF2C3050); // Tím đen — shadow, pressed
  static const Color accent       = Color(0xFFC9ADA7); // 🍑 Almond Silk — điểm nhấn ấm
  static const Color aiGradientStart = Color(0xFF9A8C98);
  static const Color aiGradientEnd   = Color(0xFFF3B085);

  // ─── TEXT COLORS ────────────────────────────────────────────────────
  /// Dusty Grape đủ tối: contrast ~8:1 trên nền trắng ✔️ WCAG AA
  static const Color brandText    = _brandDark; // Dùng cho chữ thương hiệu, tiêu đề, link

  // ─── BACKGROUNDS / SURFACES ────────────────────────────────────────
  static const Color background   = Color(0xFFFFFFFF); // Nền app chính
  static const Color surface      = Color(0xFFFFFFFF); // Nền thẻ/card
  static const Color surfaceTint  = Color(0xFFF2E9E4); // 🧶 Seashell — nền section nhẹ
  static const Color muted        = Color(0xFFF2E9E4); // Seashell — nền disabled/skeleton
  static const Color error        = Color(0xFFDC2626); // Đỏ lỗi
  static const Color notificationIcon = Color(0xFF2C3050);
  static const Color notificationIconBg = Color(0xFFF2E9E4);
  static const Color notificationAction = Color(0xFF2C3050);

  // ─── ON-COLORS (chữ TRÊN các màu nền tương ứng) ──────────────────────
  static const Color onPrimary    = Color(0xFFFFFFFF); // Chữ trắng trên nền Dusty Grape
  static const Color onBackground = Color(0xFF1C1B1E); // Chữ gần đen cho body text
  static const Color onSurface    = Color(0xFF1C1B1E); // Chữ trên card

  // ─── SECONDARY / MUTED ───────────────────────────────────────────
  static const Color secondary    = Color(0xFF9A8C98); // Màu phụ
  static const Color textMuted    = Color(0xFF6B7280); // Chú thích, placeholder
  static const Color borderLight  = Color(0xFFE8DDD8); // Viền tôn Almond Silk nhạt
}

/// ════════════════════════════════════════════════════════════════════════════
/// HƯỚNG DẪN SỬ DỤNG:
///
///  🎨 Màu NỀN (nút, gradient, indicator):  AppColors.primary
///  📝 Màu CHỮ thương hiệu (tiêu đề, link): AppColors.brandText
///  📄 Màu chữ nội dung thường:             AppColors.onBackground
///  💬 Màu chữ phụ/mờ:                     AppColors.textMuted
///
///  ✅ Để đổi toàn bộ màu app:
///     → Đổi giá trị hex của `_brand`     (màu tươi/sáng hơn)
///     → Đổi giá trị hex của `_brandDark` (màu đậm hơn)
///     → Hot Restart → xong!
/// ════════════════════════════════════════════════════════════════════════════
