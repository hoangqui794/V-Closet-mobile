import 'package:shared_preferences/shared_preferences.dart';

class AuthLocalStorage {
  final SharedPreferences _prefs;

  AuthLocalStorage(this._prefs);

  static const String _kAccessToken = 'access_token';
  static const String _kRefreshToken = 'refresh_token';
  static const String _kUserId = 'user_id';
  static const String _kUserEmail = 'user_email';
  static const String _kUserName = 'user_name';
  static const String _kUserAvatar = 'user_avatar';
  static const String _kUserRole = 'user_role';
  static const String _kIsOnboardingCompleted = 'is_onboarding_completed';
  static const String _kIsPasswordSet = 'is_password_set';
  static const String _kSubscriptionType = 'subscription_type';
  static const String _kBgRemovalCredits = 'bg_removal_credits';
  static const String _kTryOnCredits = 'try_on_credits';
  static const String _kHasActivePremium = 'has_active_premium';
  static const String _kWardrobeItemCount = 'wardrobe_item_count';
  static const String _kOutfitCount = 'outfit_count';
  static const String _kOutfitLimit = 'outfit_limit';

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _prefs.setString(_kAccessToken, accessToken);
    await _prefs.setString(_kRefreshToken, refreshToken);
  }

  Future<void> saveUser({
    required int userId,
    required String email,
    required String displayName,
    required String role,
    String? avatarUrl,
    bool isOnboardingCompleted = false,
    bool isPasswordSet = true,
  }) async {
    await _prefs.setInt(_kUserId, userId);
    await _prefs.setString(_kUserEmail, email);
    await _prefs.setString(_kUserName, displayName);
    await _prefs.setString(_kUserRole, role);
    await _prefs.setBool(_kIsOnboardingCompleted, isOnboardingCompleted);
    await _prefs.setBool(_kIsPasswordSet, isPasswordSet);
    if (avatarUrl != null) {
      await _prefs.setString(_kUserAvatar, avatarUrl);
    } else {
      await _prefs.remove(_kUserAvatar);
    }
  }

  String? getAccessToken() => _prefs.getString(_kAccessToken);
  String? getRefreshToken() => _prefs.getString(_kRefreshToken);
  int? getUserId() => _prefs.getInt(_kUserId);
  String? getUserEmail() => _prefs.getString(_kUserEmail);
  String? getUserName() => _prefs.getString(_kUserName);
  /// Alias dùng cho UI hiển thị tên
  String? getDisplayName() => _prefs.getString(_kUserName);
  String? getUserAvatar() => _prefs.getString(_kUserAvatar);
  String? getUserRole() => _prefs.getString(_kUserRole);
  bool isOnboardingCompleted() => _prefs.getBool(_kIsOnboardingCompleted) ?? false;
  bool isPasswordSet() => _prefs.getBool(_kIsPasswordSet) ?? true;
  int getWardrobeItemCount() => _prefs.getInt(_kWardrobeItemCount) ?? 0;

  Future<void> setOnboardingCompleted(bool completed) async {
    await _prefs.setBool(_kIsOnboardingCompleted, completed);
  }

  Future<void> setPasswordSet(bool value) async {
    await _prefs.setBool(_kIsPasswordSet, value);
  }

  Future<void> clearSession() async {
    await _prefs.remove(_kAccessToken);
    await _prefs.remove(_kRefreshToken);
    await _prefs.remove(_kUserId);
    await _prefs.remove(_kUserEmail);
    await _prefs.remove(_kUserName);
    await _prefs.remove(_kUserAvatar);
    await _prefs.remove(_kUserRole);
    await _prefs.remove(_kIsOnboardingCompleted);
    await _prefs.remove(_kIsPasswordSet);
    await _prefs.remove(_kHasActivePremium);
    await _prefs.remove(_kSubscriptionType);
    await _prefs.remove(_kWardrobeItemCount);
    await _prefs.remove(_kBgRemovalCredits);
    await _prefs.remove(_kTryOnCredits);
    await _prefs.remove(_kOutfitCount);
    await _prefs.remove(_kOutfitLimit);
  }

  bool hasSession() {
    return getAccessToken() != null;
  }

  String getSubscriptionType() => _prefs.getString(_kSubscriptionType) ?? 'free';
  int getBgRemovalCredits() => _prefs.getInt(_kBgRemovalCredits) ?? 1;
  int getTryOnCredits() => _prefs.getInt(_kTryOnCredits) ?? 1;
  bool getHasActivePremium() => _prefs.getBool(_kHasActivePremium) ?? false;
  int getOutfitCount() => _prefs.getInt(_kOutfitCount) ?? 0;
  int? getOutfitLimit() => _prefs.getInt(_kOutfitLimit);

  Future<void> saveHasActivePremium(bool value) async {
    await _prefs.setBool(_kHasActivePremium, value);
  }

  Future<void> saveSubscription(String type, int bgCredits, int tryonCredits) async {
    await _prefs.setString(_kSubscriptionType, type);
    await _prefs.setInt(_kBgRemovalCredits, bgCredits);
    await _prefs.setInt(_kTryOnCredits, tryonCredits);
  }

  Future<void> saveWardrobeItemCount(int count) async {
    await _prefs.setInt(_kWardrobeItemCount, count);
  }

  Future<void> saveOutfitCount(int count) async {
    await _prefs.setInt(_kOutfitCount, count);
  }

  Future<void> saveOutfitLimit(int? limit) async {
    if (limit == null) {
      await _prefs.remove(_kOutfitLimit);
    } else {
      await _prefs.setInt(_kOutfitLimit, limit);
    }
  }

  Future<void> updateCredits({int? bgCredits, int? tryonCredits}) async {
    if (bgCredits != null) {
      await _prefs.setInt(_kBgRemovalCredits, bgCredits);
    }
    if (tryonCredits != null) {
      await _prefs.setInt(_kTryOnCredits, tryonCredits);
    }
  }
}
