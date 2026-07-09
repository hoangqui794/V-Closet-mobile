import 'package:flutter/material.dart';

/// ════════════════════════════════════════════════════════════════════════════
/// ĐỂ ĐỔI TOÀN BỘ MÀU SẮC APP — CHỈ CẦN SỬA 2 DÒNG NÀY:
/// ════════════════════════════════════════════════════════════════════════════
class AppColors {
  // ─── 🎨 2 NGUỒN MÀU GỐC (chỉ cần đổi ở đây) ─────────────────────────────────────────
  static const Color _brand     = Color(0xFF4A4E69); // Màu chính (Dusty Grape)
  static const Color _brandDark = Color(0xFF33364D); // Màu chính tối (Primary Dark)

  // ─── UI BACKGROUNDS & ACCENTS ─────────────────────────────────────────
  /// Dùng làm NỀN: nút bấm, header, tab, indicator, badge nền
  static const Color primary      = _brand;
  static const Color primaryLight = Color(0xFF6B6F8A); // Màu chính nhạt (Primary Light)
  static const Color primaryDark  = _brandDark;
  static const Color accent       = Color(0xFF9A8C98); // Màu điểm nhấn (Accent - Lilac Ash)
  static const Color aiGradientStart = Color(0xFF9A8C98);
  static const Color aiGradientEnd   = Color(0xFFF3B085);

  // ─── TEXT COLORS ────────────────────────────────────────────────────
  static const Color brandText    = _brandDark; // Dùng cho chữ thương hiệu, tiêu đề, link

  // ─── BACKGROUNDS / SURFACES ────────────────────────────────────────
  static const Color background   = Color(0xFFF2E9E4); // Màu nền (Background)
  static const Color surface      = Color(0xFFFAF6F4); // Bề mặt (Surface)
  static const Color surfaceTint  = Color(0xFFF2E9E4); // Màu nền section nhẹ
  static const Color muted        = Color(0xFFDDD5D0); // Màu nhạt/Muted
  static const Color error        = Color(0xFFDC2626); // Đỏ lỗi
  static const Color notificationIcon = Color(0xFF4A4E69);
  static const Color notificationIconBg = Color(0xFFFAF6F4);
  static const Color notificationAction = Color(0xFF4A4E69);

  // ─── ON-COLORS (chữ TRÊN các màu nền tương ứng) ──────────────────────
  static const Color onPrimary    = Color(0xFFF2E9E4); // Chữ trên nền chính
  static const Color onBackground = Color(0xFF4A4E69); // Chữ trên nền
  static const Color onSurface    = Color(0xFF4A4E69); // Chữ trên bề mặt

  // ─── SECONDARY / MUTED ───────────────────────────────────────────
  static const Color secondary    = Color(0xFFC9ADA7); // Màu phụ (Secondary - Almond Silk)
  static const Color textMuted    = Color(0xFF9A8C98); // Chữ phụ (Text Muted)
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
