import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// Service kiem tra va bat buoc cap nhat app qua Google Play Store.
///
/// Cach hoat dong:
/// - Goi [checkForUpdate] khi app khoi dong.
/// - Neu co ban moi tren Play Store → hien man hinh cap nhat ngay lap tuc
///   (Immediate Mode) – nguoi dung khong the bo qua.
/// - Play Store se tu tai va cai ban moi, app restart tu dong.
///
/// Chi hoat dong khi:
///   1. App da duoc publish tren Google Play.
///   2. Thiet bi dang nhap dung tai khoan Google va co Google Play Services.
class InAppUpdateService {
  /// Kiem tra cap nhat va hien man hinh bat buoc neu co ban moi.
  static Future<void> checkForUpdate() async {
    if (kIsWeb) return;

    try {
      final AppUpdateInfo info = await InAppUpdate.checkForUpdate();

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        // IMMEDIATE MODE – Bat buoc cap nhat, khong the bo qua
        // Play Store se tu tai ban moi va cai dat.
        // App se tu restart sau khi cai xong.
        final AppUpdateResult result = await InAppUpdate.performImmediateUpdate();

        if (result != AppUpdateResult.success) {
          debugPrint('[InAppUpdate] Cap nhat khong hoan thanh: $result');
        }
      } else {
        debugPrint('[InAppUpdate] Khong co ban cap nhat moi.');
      }
    } catch (e) {
      debugPrint('[InAppUpdate] Loi kiem tra cap nhat: $e');
    }
  }

  /// FLEXIBLE MODE – Cho phep tai nen, khong bat buoc ngay.
  static Future<void> startFlexibleUpdate() async {
    if (kIsWeb) return;

    try {
      final AppUpdateInfo info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        await InAppUpdate.startFlexibleUpdate();
      }
    } catch (e) {
      debugPrint('[InAppUpdate] Loi flexible update: $e');
    }
  }

  /// Ap dung ban da tai nen (dung kem voi [startFlexibleUpdate]).
  static Future<void> completeFlexibleUpdate() async {
    if (kIsWeb) return;

    try {
      await InAppUpdate.completeFlexibleUpdate();
    } catch (e) {
      debugPrint('[InAppUpdate] Loi hoan tat flexible update: $e');
    }
  }
}
