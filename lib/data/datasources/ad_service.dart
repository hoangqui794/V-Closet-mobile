import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:get_it/get_it.dart';
import 'auth_local_storage.dart';

/// Service quản lý Google AdMob Rewarded Video Ads và Interstitial Ads
/// - Dùng test ID trong quá trình dev
/// - Thay bằng ID thật khi publish lên Play Store
class AdService {
  // Singleton
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // ── Ad Unit IDs ──────────────────────────────────────────────────
  static const String _testRewardedAdId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _realRewardedAdId =
      'ca-app-pub-6907819873317169/1604323339';

  static String get rewardedAdUnitId {
    if (_realRewardedAdId.isNotEmpty) return _realRewardedAdId;
    return _testRewardedAdId;
  }

  static const String _testInterstitialAdId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _realInterstitialAdId =
      'ca-app-pub-6907819873317169/7707531400';

  static String get interstitialAdUnitId {
    if (_realInterstitialAdId.isNotEmpty) return _realInterstitialAdId;
    return _testInterstitialAdId;
  }

  // ── State ────────────────────────────────────────────────────────
  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;
  bool _isLoading = false;

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoaded = false;
  bool _isInterstitialLoading = false;

  bool get isAdLoaded => _isAdLoaded;
  bool get isInterstitialAdLoaded => _isInterstitialAdLoaded;

  // ── Initialize ───────────────────────────────────────────────────
  /// Gọi trong main() trước runApp()
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
    
    // Đăng ký các thiết bị thử nghiệm để load quảng cáo test của Google
    // giúp bypass lỗi "Account not approved yet" (Code 3) khi tài khoản AdMob đang chờ duyệt
    final configuration = RequestConfiguration(
      testDeviceIds: [
        'B65DACFD868E84A1902AA27A9C480257',
        '33BE2251611A5B4D2CC4E42B5684E0F4',
        'B65DACFD-868E-84A1-902A-A27A9C480257',
        '33BE2251-611A-5B4D-2CC4-E42B5684E0F4',
      ],
    );
    await MobileAds.instance.updateRequestConfiguration(configuration);
    
    debugPrint('AdMob: Initialized with test devices: ${configuration.testDeviceIds}');
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

  // ── Load Interstitial Ad ──────────────────────────────────────────
  Future<void> loadInterstitialAd() async {
    if (_isInterstitialLoading || _isInterstitialAdLoaded) return;
    _isInterstitialLoading = true;

    await InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoaded = true;
          _isInterstitialLoading = false;
          debugPrint('AdMob: Interstitial ad loaded');

          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              _isInterstitialAdLoaded = false;
              loadInterstitialAd(); // Load again
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
              _isInterstitialAdLoaded = false;
              debugPrint('AdMob: Failed to show interstitial: $error');
              loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isInterstitialLoading = false;
          _isInterstitialAdLoaded = false;
          debugPrint('AdMob: Failed to load interstitial ad: $error');
        },
      ),
    );
  }

  // ── Show Interstitial Ad ──────────────────────────────────────────
  Future<void> showInterstitialAd({
    required VoidCallback onDismissed,
  }) async {
    // Chỉ hiển thị quảng cáo cho tài khoản FREE
    if (GetIt.I.isRegistered<AuthLocalStorage>()) {
      final localStorage = GetIt.I<AuthLocalStorage>();
      final hasActivePremium = localStorage.getHasActivePremium();
      if (hasActivePremium) {
        debugPrint('AdMob: User is Premium. Skip showing interstitial ad.');
        onDismissed();
        return;
      }
    }

    if (!_isInterstitialAdLoaded || _interstitialAd == null) {
      debugPrint('AdMob: Interstitial ad not ready, loading...');
      onDismissed();
      await loadInterstitialAd();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _isInterstitialAdLoaded = false;
        onDismissed();
        loadInterstitialAd(); // Load again
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _isInterstitialAdLoaded = false;
        onDismissed();
        loadInterstitialAd();
      },
    );

    await _interstitialAd!.show();
  }

  // ── Dispose ──────────────────────────────────────────────────────
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isAdLoaded = false;

    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialAdLoaded = false;
  }
}
