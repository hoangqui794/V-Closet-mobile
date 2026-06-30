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
  static const String _kHasAcceptedTerms = 'has_accepted_terms_v2';
  static const String _kSurveyUrl = 'survey_url';
  static const String _kHasCompletedSurvey = 'has_completed_survey';

  // ── Style DNA Quiz ───────────────────────────────────────────────
  static const String _kHasCompletedStyleQuiz = 'has_completed_style_quiz';
  static const String _kSkinTone =
      'style_skin_tone'; // sang / trung_binh / ngam / toi
  static const String _kBodyType =
      'style_body_type'; // nho_nhan / trung_binh / cao_rao / day_dan
  static const String _kStylePref =
      'style_pref'; // casual / cong_so / streetwear / thanh_lich / sporty
  static const String _kColorPref =
      'style_color_pref'; // pastel / trung_tinh / toi_mau / mau_noi

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
  bool isOnboardingCompleted() =>
      _prefs.getBool(_kIsOnboardingCompleted) ?? false;
  bool isPasswordSet() => _prefs.getBool(_kIsPasswordSet) ?? true;
  int getWardrobeItemCount() => _prefs.getInt(_kWardrobeItemCount) ?? 0;
  bool getHasCompletedSurvey() => _prefs.getBool(_kHasCompletedSurvey) ?? false;
  Future<void> saveHasCompletedSurvey(bool value) async =>
      await _prefs.setBool(_kHasCompletedSurvey, value);

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
    await _prefs.remove(_kHasAcceptedTerms);
    await _prefs.remove(_kHasCompletedSurvey);
    await _prefs.remove(_kHasCompletedStyleQuiz);
    await _prefs.remove(_kSkinTone);
    await _prefs.remove(_kBodyType);
    await _prefs.remove(_kStylePref);
    await _prefs.remove(_kColorPref);
  }

  bool hasSession() {
    return getAccessToken() != null;
  }

  bool hasAcceptedTerms() => _prefs.getBool(_kHasAcceptedTerms) ?? false;

  Future<void> saveHasAcceptedTerms(bool value) async {
    await _prefs.setBool(_kHasAcceptedTerms, value);
  }

  String getSubscriptionType() =>
      _prefs.getString(_kSubscriptionType) ?? 'free';
  int getBgRemovalCredits() => _prefs.getInt(_kBgRemovalCredits) ?? 1;
  int getTryOnCredits() => _prefs.getInt(_kTryOnCredits) ?? 1;
  bool getHasActivePremium() => _prefs.getBool(_kHasActivePremium) ?? false;
  int getOutfitCount() => _prefs.getInt(_kOutfitCount) ?? 0;
  int? getOutfitLimit() => _prefs.getInt(_kOutfitLimit);

  Future<void> saveHasActivePremium(bool value) async {
    await _prefs.setBool(_kHasActivePremium, value);
  }

  Future<void> saveSubscription(
    String type,
    int bgCredits,
    int tryonCredits,
  ) async {
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

  String getSurveyUrl() {
    return _prefs.getString(_kSurveyUrl) ??
        'https://forms.gle/YOUR_GOOGLE_FORM_LINK';
  }

  Future<void> saveSurveyUrl(String url) async {
    await _prefs.setString(_kSurveyUrl, url);
  }

  // ── Style DNA Quiz ───────────────────────────────────────────────
  bool getHasCompletedStyleQuiz() =>
      _prefs.getBool(_kHasCompletedStyleQuiz) ?? false;
  Future<void> saveHasCompletedStyleQuiz(bool value) async =>
      await _prefs.setBool(_kHasCompletedStyleQuiz, value);

  String? getSkinTone() => _prefs.getString(_kSkinTone);
  String? getBodyType() => _prefs.getString(_kBodyType);
  String? getStylePref() => _prefs.getString(_kStylePref);
  String? getColorPref() => _prefs.getString(_kColorPref);

  Future<void> saveStyleDna({
    required String skinTone,
    required String bodyType,
    required String stylePref,
    required String colorPref,
  }) async {
    await _prefs.setString(_kSkinTone, skinTone);
    await _prefs.setString(_kBodyType, bodyType);
    await _prefs.setString(_kStylePref, stylePref);
    await _prefs.setString(_kColorPref, colorPref);
    await _prefs.setBool(_kHasCompletedStyleQuiz, true);
  }

  /// Trả về mô tả màu da phù hợp để dùng trong prompt AI
  String getSkinToneLabel() {
    switch (getSkinTone()) {
      case 'sang':
        return 'da sáng (fair skin)';
      case 'trung_binh':
        return 'da trung bình (medium skin)';
      case 'ngam':
        return 'da ngăm (olive/tan skin)';
      case 'toi':
        return 'da tối (deep/dark skin)';
      default:
        return 'da trung bình';
    }
  }

  /// Trả về mô tả vóc người để dùng trong prompt AI
  String getBodyTypeLabel() {
    switch (getBodyType()) {
      case 'nho_nhan':
        return 'vóc người nhỏ nhắn/petite';
      case 'trung_binh':
        return 'vóc người trung bình';
      case 'cao_rao':
        return 'vóc người cao ráo';
      case 'day_dan':
        return 'vóc người đầy đặn/curvy';
      default:
        return 'vóc người trung bình';
    }
  }

  /// Trả về màu sắc gợi ý tôn da dựa trên skin tone
  String getSuggestedColors() {
    switch (getSkinTone()) {
      case 'sang':
        return 'màu pastel nhạt, màu navy, burgundy, forest green';
      case 'trung_binh':
        return 'màu earth tone, olive, dusty rose, camel';
      case 'ngam':
        return 'màu trắng, đỏ đất, cam ấm, vàng mù tạt, cobalt blue';
      case 'toi':
        return 'màu trắng sáng, vàng kim, đỏ tươi, electric blue, màu metallic';
      default:
        return 'màu trung tính';
    }
  }
}
