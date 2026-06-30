import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/datasources/auth_local_storage.dart';
import '../../../data/datasources/signalr_service.dart';
import '../../../data/datasources/wardrobe_api_service.dart';
import '../../../data/datasources/outfit_api_service.dart';
import '../../../data/datasources/gemini_api_service.dart';
import '../../../data/datasources/notification_api_service.dart';
import '../../../data/datasources/user_api_service.dart';
import '../../../domain/entities/clothing_item.dart';
import '../profile/subscription_page.dart';
import '../profile/survey_page.dart';
import '../profile/notification_page.dart';
import '../profile/personal_color_detail_page.dart';
import '../../../data/datasources/subscription_api_service.dart';
import '../camera/color_harmony_checker_page.dart';
import '../profile/style_dna_chat_page.dart';

class HomePage extends StatefulWidget {
  final VoidCallback? onMenuPressed;
  final void Function(int index)? onNavigateTo;
  const HomePage({super.key, this.onMenuPressed, this.onNavigateTo});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _localStorage = GetIt.I<AuthLocalStorage>();
  final _wardrobeApi = GetIt.I<WardrobeApiService>();
  final _outfitApi = GetIt.I<OutfitApiService>();
  final _signalR = SignalRService();

  List<ClothingItem> _recentItems = [];
  bool _isLoadingItems = true;
  List<Map<String, dynamic>> _recentOutfits = [];
  bool _isLoadingOutfits = true;
  int _unreadCount = 0;
  StreamSubscription<int>? _unreadSub;

  double? _temperature;
  String _weatherDescription = 'Trời mát mẻ';
  IconData _weatherIcon = Icons.wb_cloudy_rounded;
  String? _aiStylistAdvice;
  bool _isLoadingAiAdvice = false;

  @override
  void initState() {
    super.initState();
    _loadRecentItems();
    _loadRecentOutfits();
    _fetchWeatherAndLocation();
    _loadInitialUnreadCount();
    // Lắng nghe badge thông báo từ SignalR
    _unreadSub = _signalR.onUnreadCountChanged.listen((count) {
      if (mounted) setState(() => _unreadCount = count);
    });
  }

  Future<void> _loadInitialUnreadCount() async {
    try {
      final count = await GetIt.I<NotificationApiService>().getUnreadCount();
      if (mounted) {
        setState(() {
          _unreadCount = count;
        });
      }
    } catch (e) {
      debugPrint('Lỗi tải số thông báo chưa đọc ban đầu: $e');
    }
  }

  @override
  void dispose() {
    _unreadSub?.cancel();
    super.dispose();
  }

  Future<void> _loadRecentItems() async {
    setState(() => _isLoadingItems = true);
    try {
      final items = await _wardrobeApi.getItems();
      if (mounted) {
        setState(() {
          // Lấy tối đa 6 item mới nhất
          _recentItems = items.take(6).toList();
          _isLoadingItems = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingItems = false);
    }
  }

  Future<void> _loadRecentOutfits() async {
    if (mounted) setState(() => _isLoadingOutfits = true);
    try {
      final outfits = await _outfitApi.getUserOutfits();
      if (mounted) {
        setState(() {
          _recentOutfits = outfits.take(6).toList();
          _isLoadingOutfits = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingOutfits = false);
    }
  }

  Future<void> _fetchWeatherAndLocation() async {
    double lat = 21.0285;
    double lon = 105.8542;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 8),
          );
          lat = position.latitude;
          lon = position.longitude;
        }
      }
    } catch (e) {
      debugPrint('Không lấy được GPS (sử dụng tọa độ mặc định): $e');
    }

    try {
      final dio = Dio();
      final response = await dio.get(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: {
          'latitude': lat,
          'longitude': lon,
          'current': 'temperature_2m,weather_code',
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final current = response.data['current'];
        final temp = double.tryParse(current['temperature_2m'].toString());
        final weatherCode =
            int.tryParse(current['weather_code'].toString()) ?? 0;

        String desc = 'Trời mát mẻ';
        IconData icon = Icons.wb_cloudy_rounded;

        if (weatherCode == 0) {
          desc = 'Trời trong xanh';
          icon = Icons.wb_sunny_rounded;
        } else if (weatherCode >= 1 && weatherCode <= 3) {
          desc = 'Ít mây, nắng ấm';
          icon = Icons.wb_sunny_rounded;
        } else if (weatherCode >= 45 && weatherCode <= 48) {
          desc = 'Có sương mù';
          icon = Icons.filter_drama_rounded;
        } else if (weatherCode >= 51 && weatherCode <= 55) {
          desc = 'Có mưa phùn';
          icon = Icons.umbrella_rounded;
        } else if (weatherCode >= 61 && weatherCode <= 65) {
          desc = 'Có mưa rào';
          icon = Icons.umbrella_rounded;
        } else if (weatherCode >= 80 && weatherCode <= 82) {
          desc = 'Mưa giông';
          icon = Icons.thunderstorm_rounded;
        } else if (weatherCode >= 95) {
          desc = 'Có sấm sét';
          icon = Icons.thunderstorm_rounded;
        }

        if (mounted) {
          setState(() {
            _temperature = temp;
            _weatherDescription = desc;
            _weatherIcon = icon;
          });
        }
      }
    } catch (e) {
      debugPrint('Lỗi tải thời tiết từ API: $e');
      if (mounted) {
        setState(() {
          _temperature = 28.0;
          _weatherDescription = 'Trời mát mẻ';
          _weatherIcon = Icons.wb_sunny_rounded;
        });
      }
    } finally {
      // Không tự động gọi AI - chờ user nhấn nút
    }
  }

  Future<void> _fetchAiStylistAdvice() async {
    final temp = _temperature;
    if (temp == null) return;
    if (_isLoadingAiAdvice) return;

    setState(() => _isLoadingAiAdvice = true);

    final desc = _weatherDescription;
    final displayName = _localStorage.getDisplayName() ?? 'ban';

    // Style DNA Profile
    final hasStyleDna = _localStorage.getHasCompletedStyleQuiz();
    final skinTone = hasStyleDna ? _localStorage.getSkinToneLabel() : null;
    final bodyType = hasStyleDna ? _localStorage.getBodyTypeLabel() : null;
    final stylePref = hasStyleDna ? _localStorage.getStylePref() : null;
    final suggestedColors = hasStyleDna
        ? _localStorage.getSuggestedColors()
        : null;

    // Tu do thuc te (Week 3)
    final wardrobeNames = _recentItems.isNotEmpty
        ? _recentItems.map((item) => item.name).toList()
        : <String>[];

    // Gender from profile
    String gender = 'Unisex';
    try {
      final userApiService = GetIt.I<UserApiService>();
      final profile = await userApiService.getMyProfile();
      gender = profile['Gender'] ?? profile['gender'] ?? 'Unisex';
    } catch (e) {
      debugPrint('Khong lay duoc gioi tinh: $e');
    }

    try {
      final geminiService = GetIt.I<GeminiApiService>();
      final advice = await geminiService.generateAdvice(
        temperature: temp,
        weatherDescription: desc,
        userDisplayName: displayName,
        gender: gender,
        skinTone: skinTone,
        bodyType: bodyType,
        stylePref: stylePref,
        suggestedColors: suggestedColors,
        wardrobeItemNames: wardrobeNames.isNotEmpty ? wardrobeNames : null,
      );

      if (advice != null && advice.isNotEmpty && mounted) {
        setState(() {
          _aiStylistAdvice = advice;
          _isLoadingAiAdvice = false;
        });
      } else if (mounted) {
        setState(() => _isLoadingAiAdvice = false);
      }
    } catch (e) {
      debugPrint('Loi khi lay tu van Gemini: $e');
      if (mounted) setState(() => _isLoadingAiAdvice = false);
    }
  }

  String _getSuggestedTop() {
    final text = (_aiStylistAdvice ?? '').toLowerCase();
    if (text.contains('áo thun') || text.contains('áo phông')) {
      return 'Áo thun';
    } else if (text.contains('áo sơ mi')) {
      return 'Áo sơ mi';
    } else if (text.contains('áo khoác') ||
        text.contains('áo phao') ||
        text.contains('áo gió') ||
        text.contains('jacket')) {
      return 'Áo khoác';
    } else if (text.contains('áo polo') || text.contains('áo cổ bẻ')) {
      return 'Áo polo';
    } else if (text.contains('áo len')) {
      return 'Áo len';
    } else if (text.contains('áo hoodie')) {
      return 'Áo hoodie';
    } else if (text.contains('áo croptop')) {
      return 'Áo croptop';
    }
    // Fallback dựa trên nhiệt độ
    if (_temperature != null && _temperature! > 30) {
      return 'Áo thun';
    } else if (_temperature != null && _temperature! < 20) {
      return 'Áo khoác';
    } else {
      return 'Áo sơ mi';
    }
  }

  String _getSuggestedBottom() {
    final text = (_aiStylistAdvice ?? '').toLowerCase();
    if (text.contains('quần short') ||
        text.contains('quần đùi') ||
        text.contains('quần lửng')) {
      return 'Quần short';
    } else if (text.contains('quần dài') ||
        text.contains('quần tây') ||
        text.contains('quần kaki') ||
        text.contains('quần bò') ||
        text.contains('quần jeans')) {
      return 'Quần dài';
    } else if (text.contains('chân váy') ||
        text.contains('váy ngắn') ||
        text.contains('váy xòe') ||
        text.contains('váy')) {
      return 'Chân váy';
    } else if (text.contains('đầm')) {
      return 'Đầm';
    }
    // Fallback dựa trên nhiệt độ
    if (_temperature != null && _temperature! > 30) {
      return 'Quần short';
    } else {
      return 'Quần dài';
    }
  }

  Future<void> _refreshData() async {
    await Future.wait([
      _loadRecentItems(),
      _loadRecentOutfits(),
      _fetchWeatherAndLocation(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _localStorage.getDisplayName() ?? 'bạn';
    final hasActivePremium = _localStorage.getHasActivePremium();
    final itemCount = _localStorage.getWardrobeItemCount();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Header ──────────────────────────────────
                      _header(displayName),
                      const SizedBox(height: 24),

                      // ── Banner Premium (chỉ hiện khi FREE) ─────
                      if (!hasActivePremium) ...[
                        _premiumBanner(),
                        const SizedBox(height: 24),
                      ],

                      // ── Banner Khảo Sát (Chỉ hiện khi chưa hoàn thành) ──
                      if (!_localStorage.getHasCompletedSurvey()) ...[
                        _surveyBanner(),
                        const SizedBox(height: 24),
                      ],

                      // ── Quick Actions ───────────────────────────
                      _quickActions(),
                      const SizedBox(height: 28),

                      // ── Tủ đồ của tôi ──────────────────────────
                      _sectionHeader(
                        'Tủ đồ của tôi',
                        subtitle: itemCount > 0 ? '$itemCount món đồ' : null,
                        onViewAll: () => widget.onNavigateTo?.call(1),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),

              // ── Grid quần áo gần nhất ─────────────────────────
              _buildWardrobeSliver(),

              // ── Trang phục của tôi ─────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sectionHeader(
                        'Trang phục của tôi',
                        onViewAll: () => widget.onNavigateTo?.call(1),
                      ),
                      const SizedBox(height: 14),
                      _buildRecentOutfits(),
                    ],
                  ),
                ),
              ),

              // ── AI Stylist Recommendation ──────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sectionHeader('Gợi ý phối đồ hôm nay'),
                      const SizedBox(height: 14),
                      _aiStylistRecommendation(),
                    ],
                  ),
                ),
              ),

              // ── Fashion Tips & Trends ──────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 28, 0, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _sectionHeader('Khám phá xu hướng'),
                      ),
                      const SizedBox(height: 14),
                      _fashionTipsCarousel(),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Header
  // ─────────────────────────────────────────────────────────────────
  Widget _header(String displayName) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Chào buổi sáng'
        : hour < 18
        ? 'Chào buổi chiều'
        : 'Chào buổi tối';

    return Row(
      children: [
        GestureDetector(
          onTap: () {
            final scaffold = Scaffold.maybeOf(context);
            if (scaffold != null && scaffold.hasDrawer) {
              scaffold.openDrawer();
            } else {
              widget.onMenuPressed?.call();
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.07),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(
                Icons.menu_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting,',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.primary.withOpacity(0.55),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        // Bell icon với badge SignalR
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.07),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationPage(),
                    ),
                  ).then((_) => _loadInitialUnreadCount());
                },
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
            ),
            if (_unreadCount > 0)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE45B62),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _unreadCount > 9 ? '9+' : '$_unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Premium Banner (chỉ hiện với user FREE)
  // ─────────────────────────────────────────────────────────────────
  Widget _premiumBanner() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SubscriptionPage()),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFD4AF37), Color(0xFFF0C96A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD4AF37).withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.white,
              size: 36,
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nâng cấp PREMIUM',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Thử đồ AI không giới hạn · Xóa nền tự động · Không quảng cáo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'Xem ngay',
                style: TextStyle(
                  color: Color(0xFF996515),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _surveyBanner() {
    return GestureDetector(
      onTap: () async {
        final surveyUrl = _localStorage.getSurveyUrl();
        final completed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => SurveyPage(surveyUrl: surveyUrl),
          ),
        );

        if (completed == true) {
          // Bắt đầu loading nhận thưởng
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );

          try {
            await GetIt.I<SubscriptionApiService>().claimAdReward('survey');
            if (mounted) {
              Navigator.pop(context); // Close loading dialog
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    '🎉 Cảm ơn bạn! Đã cộng 3 lượt thử đồ AI miễn phí.',
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              // Trigger load lại toàn bộ màn hình Home để ẩn banner đi
              _refreshData();
            }
          } catch (e) {
            if (mounted) {
              Navigator.pop(context); // Close loading dialog
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Không thể nhận phần thưởng: ${e.toString().replaceAll('Exception: ', '')}',
                  ),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8E94F2), Color(0xFFB19FFB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8E94F2).withOpacity(0.3),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.assignment_turned_in_rounded,
              color: Colors.white,
              size: 36,
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🎁 Quà tặng 3 lượt thử đồ',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Làm khảo sát ý kiến nhận ngay +3 lượt thử đồ AI miễn phí!',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'Làm ngay',
                style: TextStyle(
                  color: Color(0xFF7462F9),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Quick Actions
  // ─────────────────────────────────────────────────────────────────
  Widget _quickActions() {
    final actions = [
      _QuickAction(
        icon: Icons.door_sliding_rounded,
        label: 'Tủ đồ',
        color: AppColors.primary,
        onTap: () => widget.onNavigateTo?.call(1),
      ),
      _QuickAction(
        icon: Icons.auto_awesome_rounded,
        label: 'Studio AI',
        color: const Color(0xFF7B5EA7),
        onTap: () => widget.onNavigateTo?.call(4),
      ),
      _QuickAction(
        icon: Icons.shopping_bag_rounded,
        label: 'Cửa hàng',
        color: const Color(0xFF2E9E6E),
        onTap: () => widget.onNavigateTo?.call(5),
      ),
      _QuickAction(
        icon: Icons.palette_rounded,
        label: 'Hợp màu',
        color: const Color(0xFFE5A93B),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ColorHarmonyCheckerPage()),
          );
          if (result is Map && context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PersonalColorDetailPage(
                  isFromScan: true,
                  scannedSkinTone: result['skinTone']?.toString(),
                  scannedColorPref: result['colorPref']?.toString(),
                ),
              ),
            );
          }
        },
      ),
      _QuickAction(
        icon: Icons.forum_rounded,
        label: 'Chat AI',
        color: const Color(0xFF8E94F2),
        onTap: () async {
          final hasQuiz = _localStorage.getHasCompletedStyleQuiz();
          if (!hasQuiz) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Row(
                  children: const [
                    Icon(Icons.forum_rounded, color: AppColors.primary),
                    SizedBox(width: 10),
                    Text(
                      'Chưa có Phong cách',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                content: const Text(
                  'Bạn vui lòng thực hiện Định hình Phong cách cá nhân trước để AI Stylist có đầy đủ thông số hình thể và tông da để tư vấn chuẩn xác nhất nhé.',
                  style: TextStyle(fontSize: 14, height: 1.4),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Hủy',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onNavigateTo?.call(
                        3,
                      ); // Chuyển sang tab Phong cách (DNA Quiz)
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Làm ngay',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
            return;
          }

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );

          try {
            final userApiService = GetIt.I<UserApiService>();
            final profile = await userApiService.getMyProfile();
            if (mounted) {
              Navigator.pop(context);
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StyleDnaChatPage(profileData: profile),
                ),
              );
              if (result == 'go_to_studio' && mounted) {
                widget.onNavigateTo?.call(
                  4,
                ); // Chuyển sang tab Studio (Index 4)
              }
            }
          } catch (e) {
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Không thể tải thông tin hồ sơ để bắt đầu chat.',
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        },
      ),
    ];

    return Row(
      children: actions.map((a) {
        return Expanded(
          child: GestureDetector(
            onTap: a.onTap,
            child: Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: a.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: a.color.withOpacity(0.18),
                    width: 1.2,
                  ),
                ),
                child: Icon(a.icon, color: a.color, size: 26),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Section header
  // ─────────────────────────────────────────────────────────────────
  Widget _sectionHeader(
    String title, {
    String? subtitle,
    VoidCallback? onViewAll,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary.withOpacity(0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            child: const Text(
              'Xem tất cả',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryLight,
              ),
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Wardrobe sliver grid (dữ liệu thật từ API)
  // ─────────────────────────────────────────────────────────────────
  Widget _buildWardrobeSliver() {
    if (_isLoadingItems) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }

    if (_recentItems.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: _emptyWardrobe(),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = _recentItems[index];
          return _wardrobeCard(item);
        }, childCount: _recentItems.length),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.78,
        ),
      ),
    );
  }

  Widget _wardrobeCard(ClothingItem item) {
    return GestureDetector(
      onTap: () => widget.onNavigateTo?.call(1),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: item.imageUrl.isNotEmpty
                    ? Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: AppColors.secondary,
                          child: const Icon(
                            Icons.checkroom_rounded,
                            color: AppColors.primary,
                            size: 28,
                          ),
                        ),
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: AppColors.secondary.withOpacity(0.4),
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: AppColors.primary,
                              ),
                            ),
                          );
                        },
                      )
                    : Container(
                        color: AppColors.secondary,
                        child: const Icon(
                          Icons.checkroom_rounded,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyWardrobe() {
    return GestureDetector(
      onTap: () => widget.onNavigateTo?.call(1),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.primary.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.checkroom_outlined,
              size: 52,
              color: AppColors.primary.withOpacity(0.25),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tủ đồ còn trống',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Thêm quần áo đầu tiên của bạn vào tủ đồ số để bắt đầu phối đồ với AI',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.primary.withOpacity(0.5),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Thêm món đồ ngay',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Trang phục của tôi (Danh sách outfits phối sẵn)
  // ─────────────────────────────────────────────────────────────────
  Widget _buildRecentOutfits() {
    if (_isLoadingOutfits) {
      return const SizedBox(
        height: 160,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_recentOutfits.isEmpty) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.08)),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.style_outlined,
                color: AppColors.primary.withOpacity(0.25),
                size: 36,
              ),
              const SizedBox(height: 8),
              Text(
                'Chưa có trang phục phối sẵn nào',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _recentOutfits.length,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final outfit = _recentOutfits[index];
          final String title =
              outfit['Title']?.toString() ??
              outfit['title']?.toString() ??
              'Trang phục';
          final String? snapshotUrl =
              outfit['CanvasSnapshotUrl']?.toString() ??
              outfit['canvasSnapshotUrl']?.toString() ??
              outfit['snapshotUrl']?.toString();

          return GestureDetector(
            onTap: () {
              widget.onNavigateTo?.call(1);
            },
            child: Container(
              width: 130,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Container(
                        color: const Color(0xFFF8F9FA),
                        child: snapshotUrl == null || snapshotUrl.isEmpty
                            ? const Icon(
                                Icons.style_rounded,
                                color: AppColors.primary,
                                size: 36,
                              )
                            : Image.network(
                                snapshotUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                      Icons.broken_image_outlined,
                                      color: AppColors.primary,
                                      size: 36,
                                    ),
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // AI Stylist Recommendation (Thiết kế gradient đồng bộ với Logo mới)
  // ─────────────────────────────────────────────────────────────────
  Widget _aiStylistRecommendation() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF4A69BB),
            Color(0xFFF3B085),
          ], // Đồng bộ với logo xanh lam - cam đào
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A69BB).withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'AI Stylist khuyên dùng',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_weatherIcon, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _temperature != null
                              ? '${_temperature!.toStringAsFixed(1)}°C · $_weatherDescription'
                              : 'Đang lấy thời tiết...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── Advice area (lazy-load) ────────────────────────────────────────
          if (_isLoadingAiAdvice)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'AI Stylist đang phân tích trang phục...',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            )
          else if (_aiStylistAdvice != null && _aiStylistAdvice!.isNotEmpty)
            Text(
              _aiStylistAdvice!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.4,
              ),
            )
          else
            GestureDetector(
              onTap: _fetchAiStylistAdvice,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Nhận lời khuyên AI hôm nay ✨',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _suggestedItemBubble(
                      _getSuggestedTop(),
                      Icons.checkroom_rounded,
                    ),
                    const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    _suggestedItemBubble(
                      _getSuggestedBottom(),
                      Icons.checkroom_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => widget.onNavigateTo?.call(4), // Sang AI Studio
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF4A69BB),
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Mặc thử',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 14),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _suggestedItemBubble(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Fashion Tips Carousel (Khám phá xu hướng)
  // ─────────────────────────────────────────────────────────────────
  Widget _fashionTipsCarousel() {
    final tips = [
      {
        'title': '5 Cách Phối Đồ Với Áo Vest Đỏ Lịch Lãm',
        'category': 'Xu Hướng',
        'readTime': '3 phút đọc',
        'color': const Color(0xFFE45B62),
        'icon': Icons.lightbulb_outline_rounded,
      },
      {
        'title': 'Chăm Sóc & Bảo Quản Sợi Vải Bền Màu Hơn',
        'category': 'Mẹo Hay',
        'readTime': '2 phút đọc',
        'color': const Color(0xFF2E9E6E),
        'icon': Icons.spa_rounded,
      },
      {
        'title': 'Quy Tắc Phối Màu Quần Áo Cơ Bản Ai Cũng Có Thể Thử',
        'category': 'Căn Bản',
        'readTime': '4 phút đọc',
        'color': const Color(0xFF7B5EA7),
        'icon': Icons.palette_outlined,
      },
    ];

    return SizedBox(
      height: 160,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: tips.map((tip) {
            final categoryColor = tip['color'] as Color;
            return Container(
              width: 260,
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(color: AppColors.primary.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: categoryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          tip['category'] as String,
                          style: TextStyle(
                            color: categoryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        tip['readTime'] as String,
                        style: TextStyle(
                          color: AppColors.primary.withOpacity(0.4),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tip['title'] as String,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: categoryColor.withOpacity(0.1),
                        child: Icon(
                          tip['icon'] as IconData,
                          color: categoryColor,
                          size: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Đọc chi tiết',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryLight,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.primaryLight,
                        size: 12,
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}
