import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Service quản lý Google AdMob Rewarded Video Ads
/// - Dùng test ID trong quá trình dev
/// - Thay bằng ID thật khi publish lên Play Store
class AdService {
  // Singleton
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // ── Ad Unit IDs ──────────────────────────────────────────────────
  // TODO: Thay bằng ID thật từ AdMob khi publish
  static const String _testRewardedAdId =
      'ca-app-pub-3940256099942544/5224354917';

  // ID thật — để trống, sẽ điền sau khi có từ AdMob console
  static const String _realRewardedAdId = '';

  static String get rewardedAdUnitId {
    // Dùng ID thật nếu đã có, không thì dùng test
    if (_realRewardedAdId.isNotEmpty) return _realRewardedAdId;
    return _testRewardedAdId;
  }

  // ── State ────────────────────────────────────────────────────────
  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;
  bool _isLoading = false;

  bool get isAdLoaded => _isAdLoaded;

  // ── Initialize ───────────────────────────────────────────────────
  /// Gọi trong main() trước runApp()
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
    debugPrint('AdMob: Initialized');
  }

  // ── Load Rewarded Ad ─────────────────────────────────────────────
  /// Tải trước quảng cáo để phát ngay khi user bấm "Xem quảng cáo"
  Future<void> loadRewardedAd() async {
    if (_isLoading || _isAdLoaded) return;
    _isLoading = true;

    await RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isAdLoaded = true;
          _isLoading = false;
          debugPrint('AdMob: Rewarded ad loaded');

          // Khi ad bị đóng → tự load lại để sẵn sàng cho lần sau
          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
              _isAdLoaded = false;
              loadRewardedAd(); // load lại
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _rewardedAd = null;
              _isAdLoaded = false;
              debugPrint('AdMob: Failed to show ad: $error');
              loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          _isAdLoaded = false;
          debugPrint('AdMob: Failed to load rewarded ad: $error');
        },
      ),
    );
  }

  // ── Show Rewarded Ad ─────────────────────────────────────────────
  /// Phát quảng cáo. [onRewarded] gọi khi user xem đủ → nhận thưởng.
  /// [onFailed] gọi khi ad chưa sẵn sàng.
  Future<void> showRewardedAd({
    required void Function(RewardItem reward) onRewarded,
    void Function()? onFailed,
  }) async {
    if (!_isAdLoaded || _rewardedAd == null) {
      debugPrint('AdMob: Ad not ready, loading...');
      onFailed?.call();
      // Load lại để lần sau có sẵn
      await loadRewardedAd();
      return;
    }

    await _rewardedAd!.show(
      onUserEarnedReward: (_, reward) {
        debugPrint('AdMob: User earned reward — ${reward.amount} ${reward.type}');
        onRewarded(reward);
      },
    );
  }

  // ── Dispose ──────────────────────────────────────────────────────
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isAdLoaded = false;
  }
}
