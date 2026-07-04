import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../core/theme/app_colors.dart';
import '../../data/datasources/auth_api_service.dart';
import '../../data/datasources/auth_local_storage.dart';
import 'auth/login_page.dart';
import 'camera/camera_page.dart';
import 'closet/closet_page.dart';
import 'home/home_page.dart';
import 'outfit/outfit_page.dart';
import 'profile/profile_page.dart';
import 'profile/subscription_page.dart';
import 'profile/style_dna_quiz_page.dart';
import 'profile/style_dna_page.dart';
import 'dart:async';
import '../../data/datasources/user_api_service.dart';
import 'store/store_page.dart';
import 'profile/notification_page.dart';
import '../../data/datasources/subscription_api_service.dart';
import '../../data/datasources/signalr_service.dart';
import '../../data/datasources/notification_api_service.dart';
import '../widgets/app_tour_overlay.dart';
import 'package:animate_do/animate_do.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _localStorage = GetIt.I<AuthLocalStorage>();
  final List<GlobalKey> _navKeys = List.generate(6, (_) => GlobalKey());
  int _currentIndex = 0;
  StreamSubscription<Map<String, dynamic>>? _notificationSub;
  OverlayEntry? _overlayEntry;
  bool _isRunningNewUserFlow = false;

  @override
  void initState() {
    super.initState();
    _syncSubscription();
    SignalRService().initSignalR();
    _listenNotifications();

    // Kịch bản 3: Tự kiểm tra thông báo chưa đọc khi mở ứng dụng
    _checkGiftSubscriptionFromNotifications();

    // Trigger Style DNA Quiz và hướng dẫn nhanh cho user mới
    WidgetsBinding.instance.addPostFrameCallback((_) => _runNewUserFlow());
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    _overlayEntry?.remove();
    super.dispose();
  }

  // Kịch bản 1: Lắng nghe qua SignalR thời gian thực
  void _listenNotifications() {
    _notificationSub = SignalRService().onNewNotification.listen((
      notification,
    ) {
      if (!mounted) return;
      _syncSubscription(); // Đồng bộ ngay lập tức để có Premium features

      final type =
          notification['type']?.toString() ??
          notification['Type']?.toString() ??
          'System';
      if (type.toLowerCase() == 'subscription') {
        final title =
            notification['title']?.toString() ??
            notification['Title']?.toString() ??
            'Chúc mừng! Bạn đã được tặng gói';
        final body =
            notification['body']?.toString() ??
            notification['Body']?.toString() ??
            '';
        _showGiftSubscriptionDialog(title, body);
      } else {
        _showFloatingNotification(notification);
      }
    });
  }

  // Kịch bản 2: Handler khi bấm từ thông báo đẩy ngoài app (để hệ thống gọi khi click)
  void handlePushNotificationClicked(Map<String, dynamic> payload) {
    if (!mounted) return;
    final type =
        payload['type']?.toString() ?? payload['Type']?.toString() ?? '';
    if (type.toLowerCase() == 'subscription') {
      final title =
          payload['title']?.toString() ??
          payload['Title']?.toString() ??
          'Chúc mừng! Bạn đã được tặng gói';
      final body =
          payload['body']?.toString() ?? payload['Body']?.toString() ?? '';
      _showGiftSubscriptionDialog(title, body);
    }
  }

  // Kịch bản 3: Kiểm tra trong thông báo chưa đọc
  Future<void> _checkGiftSubscriptionFromNotifications() async {
    try {
      final notificationService = GetIt.I<NotificationApiService>();
      final unreadNotifications = await notificationService.getNotifications(
        isRead: false,
      );

      NotificationModel? giftNotification;
      for (final n in unreadNotifications) {
        if (n.type.toLowerCase() == 'subscription') {
          giftNotification = n;
          break;
        }
      }

      if (giftNotification != null) {
        // Hiển thị Dialog chúc mừng
        _showGiftSubscriptionDialog(
          giftNotification.title,
          giftNotification.body,
        );

        // Đánh dấu thông báo là đã đọc
        await notificationService.markAsRead(giftNotification.id);
      }
    } catch (e) {
      debugPrint('Lỗi kiểm tra thông báo quà tặng tại MainScreen: $e');
    }
  }

  // Giao diện Popup chúc mừng tặng gói (Confetti / Hộp quà)
  void _showGiftSubscriptionDialog(String title, String body) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return ElasticIn(
          duration: const Duration(milliseconds: 600),
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Hộp quà nổi bật
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text('🎁', style: TextStyle(fontSize: 48)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Nội dung thông báo / Lời nhắn
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      body,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primary.withOpacity(0.8),
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Nút hành động
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _syncSubscription(); // Cập nhật lại số dư & hạn dùng tức thì
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Tuyệt vời',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showFloatingNotification(Map<String, dynamic> notification) {
    final title =
        notification['title']?.toString() ??
        notification['Title']?.toString() ??
        'Thông báo mới';
    final body =
        notification['body']?.toString() ??
        notification['Body']?.toString() ??
        '';
    final type =
        notification['type']?.toString() ??
        notification['Type']?.toString() ??
        'System';

    _overlayEntry?.remove();
    _overlayEntry = null;

    _overlayEntry = OverlayEntry(
      builder: (context) => _FloatingNotificationBanner(
        title: title,
        body: body,
        type: type,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NotificationPage()),
          );
        },
        onDismiss: () {
          _overlayEntry?.remove();
          _overlayEntry = null;
        },
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Future<void> _syncSubscription() async {
    try {
      await GetIt.I<SubscriptionApiService>().syncSubscriptionStatus();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Lỗi đồng bộ gói dịch vụ tại MainScreen: $e');
    }
  }

  Future<void> _runNewUserFlow() async {
    if (_isRunningNewUserFlow) return;
    _isRunningNewUserFlow = true;
    try {
      await _syncSubscription();
      await _maybeShowStyleQuiz();
      await _migrateGuideStateForExistingUsers();
      await _maybeShowNewUserGuide();
    } finally {
      _isRunningNewUserFlow = false;
    }
  }

  Future<void> _migrateGuideStateForExistingUsers() async {
    if (_localStorage.hasNewUserGuideProgress()) return;

    final hasExistingClosetData =
        _localStorage.getWardrobeItemCount() > 0 ||
        _localStorage.getOutfitCount() > 0;
    if (!hasExistingClosetData) return;

    await _localStorage.markGuidesSeenForExistingUser();
  }

  /// Hiện Style DNA Quiz nếu user chưa làm
  Future<void> _maybeShowStyleQuiz() async {
    if (!mounted) return;

    // Đồng bộ profile từ máy chủ để cập nhật trạng thái Style DNA mới nhất
    try {
      final userApiService = GetIt.I<UserApiService>();
      await userApiService.getMyProfile();
    } catch (e) {
      debugPrint('Lỗi khi tự động tải thông tin cá nhân: $e');
    }

    if (!mounted) return;
    if (_localStorage.getHasCompletedStyleQuiz()) return;
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, _) => StyleDnaQuizPage(
          onCompleted: () {
            Navigator.of(context).pop();
            // Reload home để AI Stylist dùng data mới
            setState(() {});
          },
        ),
        transitionsBuilder: (context, animation, _, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  Future<void> _maybeShowNewUserGuide() async {
    if (!mounted) return;
    final step = _localStorage.getNewUserGuideStep();
    if (step == NewUserGuideStep.completed) return;

    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    if (step == NewUserGuideStep.tryAi) {
      setState(() => _currentIndex = 4);
      return;
    }

    if (step == NewUserGuideStep.addItem ||
        step == NewUserGuideStep.viewCloset ||
        step == NewUserGuideStep.createOutfit ||
        step == NewUserGuideStep.saveOutfit) {
      await _showNewUserCoachTour();
    }
  }

  Future<void> _showNewUserCoachTour() async {
    final steps = [
      if (_currentIndex != 1)
        _NavTourStep(
          navIndex: 1,
          icon: Icons.door_sliding_rounded,
          title: 'Bước 1: Mở Tủ đồ',
          description:
              'Nhấn đúng tab Tủ đồ ở thanh dưới. Sau đó app sẽ chỉ tiếp nút Nhập món đồ để bạn thêm món đầu tiên.',
          primaryLabel: 'Nhấn vùng sáng để mở Tủ đồ',
        ),
    ];

    if (steps.isEmpty) return;

    for (var index = 0; index < steps.length; index++) {
      final step = steps[index];
      if (!mounted) return;

      final result = await AppTourOverlay.showCoachStep(
        context,
        targetKey: _navKeys[step.navIndex],
        stepNumber: 1,
        totalSteps: 6,
        icon: step.icon,
        title: step.title,
        description: step.description,
        primaryLabel: step.primaryLabel,
      );

      if (!mounted) return;
      if (result == AppTourCoachAction.finish) {
        await _localStorage.completeNewUserGuide();
        return;
      }

      setState(() => _currentIndex = step.navIndex);
      await Future.delayed(const Duration(milliseconds: 320));
    }
  }

  // Nav items: index 2 là nút camera đặc biệt ở giữa
  static const List<(IconData, String)> _navItems = [
    (Icons.home_rounded, 'Trang chủ'),
    (Icons.door_sliding_rounded, 'Tủ đồ'),
    (Icons.camera_alt_rounded, 'Camera'),
    (Icons.palette_rounded, 'Phong cách'),
    (Icons.auto_awesome_rounded, 'Studio'),
    (Icons.shopping_bag_rounded, 'Cửa hàng'),
  ];

  late final List<Widget> _pages = [
    HomePage(
      onMenuPressed: _openDrawer,
      onNavigateTo: (index) => setState(() => _currentIndex = index),
    ),
    ClosetPage(
      onMenuPressed: _openDrawer,
      onNavigateTo: (index) => setState(() => _currentIndex = index),
    ),
    CameraPage(onClose: () => _onTapNav(1)),
    StyleDnaPage(
      onMenuPressed: _openDrawer,
      onNavigateTo: (index) => setState(() => _currentIndex = index),
    ),
    OutfitPage(onMenuPressed: _openDrawer),
    StorePage(onMenuPressed: _openDrawer),
  ];

  void _onTapNav(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }

  void _openDrawer() {
    debugPrint(
      'DEBUG: _openDrawer triggered. scaffoldKey.currentState = ${_scaffoldKey.currentState}',
    );
    _scaffoldKey.currentState?.openDrawer();
  }

  void _showCustomAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDark.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(
                color: AppColors.primary.withOpacity(0.08),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App Icon Container
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.door_sliding_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // App Name
                  const Text(
                    'V-Closet',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Version Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Phiên bản 1.0.0',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Description
                  Text(
                    'V-Closet là ứng dụng quản lý tủ đồ thông minh tích hợp công nghệ thử đồ ảo AI vượt trội.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.primary.withOpacity(0.8),
                      fontSize: 13.5,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(height: 1, thickness: 0.8),
                  const SizedBox(height: 16),
                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            showLicensePage(
                              context: context,
                              applicationName: 'V-Closet',
                              applicationVersion: '1.0.0',
                              applicationIcon: const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: Icon(
                                  Icons.door_sliding_rounded,
                                  color: AppColors.primary,
                                  size: 48,
                                ),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.accent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Giấy phép',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Đóng',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hideBottomNav = _currentIndex == 2;

    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      drawer: Drawer(
        backgroundColor: AppColors.background,
        child: Column(
          children: [
            // Drawer Header
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: AppColors.accent,
                backgroundImage:
                    _localStorage.getUserAvatar() != null &&
                        _localStorage.getUserAvatar()!.startsWith('http')
                    ? NetworkImage(_localStorage.getUserAvatar()!)
                          as ImageProvider
                    : const AssetImage('assets/images/avatar1.png'),
              ),
              accountName: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Expanded(
                    child: Text(
                      _localStorage.getUserName() ?? 'V-Closet User',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildSubscriptionBadge(),
                  const SizedBox(width: 16),
                ],
              ),
              accountEmail: Text(
                _localStorage.getUserEmail() ?? 'Tủ đồ ảo thông minh AI',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Menu Items
            ListTile(
              leading: const Icon(Icons.home_rounded, color: AppColors.primary),
              title: const Text(
                'Trang chủ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 0);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.door_sliding_rounded,
                color: AppColors.primary,
              ),
              title: const Text(
                'Tủ đồ cá nhân',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 1);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.palette_rounded,
                color: AppColors.primary,
              ),
              title: const Text(
                'Phong cách cá nhân',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 3);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primary,
              ),
              title: const Text(
                'Studio Phối Đồ AI',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 4);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.shopping_bag_rounded,
                color: AppColors.primary,
              ),
              title: const Text(
                'Cửa hàng',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 5);
              },
            ),
            // Gói Premium — đặt nổi bật để dễ nhìn thấy
            ListTile(
              leading: const Icon(
                Icons.workspace_premium_rounded,
                color: Color(0xFFD4AF37),
              ),
              title: const Text(
                'Gói Premium & Nạp Credits',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF996515),
                ),
              ),
              tileColor: const Color(0xFFFCF8F2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SubscriptionPage(),
                  ),
                ).then((_) => setState(() {}));
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.person_rounded,
                color: AppColors.primary,
              ),
              title: const Text(
                'Hồ sơ cá nhân',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                );
              },
            ),
            const Spacer(),
            const Divider(color: AppColors.accent, thickness: 1),
            ListTile(
              leading: const Icon(
                Icons.info_outline_rounded,
                color: AppColors.primary,
              ),
              title: const Text(
                'Giới thiệu V-Closet',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _showCustomAboutDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.error),
              title: const Text(
                'Đăng xuất',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
              onTap: () async {
                Navigator.pop(context); // Đóng drawer

                // Hiển thị loading dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );

                await SignalRService().disconnect();
                await GetIt.I<AuthApiService>().logout();

                if (context.mounted) {
                  Navigator.of(context).pop(); // Đóng loading dialog
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
                  );
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.02),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: _pages[_currentIndex],
        ),
      ),
      bottomNavigationBar: AnimatedSlide(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        offset: hideBottomNav ? const Offset(0, 1.5) : Offset.zero,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: hideBottomNav ? 0 : 1,
          child: IgnorePointer(
            ignoring: hideBottomNav,
            child: _buildDarkPillNav(),
          ),
        ),
      ),
    );
  }

  // ── Dark Pill Nav Bar ─────────────────────────────────────────────────────

  Widget _buildDarkPillNav() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 14),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withOpacity(0.45),
                blurRadius: 24,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_navItems.length, (index) {
              if (index == 2) return _buildCenterCameraButton(index);
              return _buildNavItem(index);
            }),
          ),
        ),
      ),
    );
  }

  /// Item thường: icon trắng mờ → khi active hiện pill kem + icon nâu + label
  Widget _buildNavItem(int index) {
    final active = _currentIndex == index;
    final (icon, label) = _navItems[index];

    return GestureDetector(
      key: _navKeys[index],
      onTap: () => _onTapNav(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: active
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? AppColors.secondary.withOpacity(0.90)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: active
                  ? AppColors.primaryDark
                  : Colors.white.withOpacity(0.60),
              size: active ? 18 : 20,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: active
                  ? Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  /// Nút camera giữa: tròn nổi lên trên, gradient, border trắng mờ
  Widget _buildCenterCameraButton(int index) {
    final active = _currentIndex == index;

    return GestureDetector(
      key: _navKeys[index],
      onTap: () => _onTapNav(index),
      child: Transform.translate(
        offset: const Offset(0, -10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: active
                  ? [AppColors.primaryLight, AppColors.primary]
                  : [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withOpacity(active ? 0.35 : 0.20),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(active ? 0.45 : 0.28),
                blurRadius: active ? 20 : 12,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.camera_alt_rounded,
            color: Colors.white.withOpacity(active ? 1.0 : 0.85),
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionBadge() {
    final isPremium = _localStorage.getHasActivePremium();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPremium
            ? const Color(0xFFD4AF37)
            : Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPremium ? const Color(0xFFFFD700) : Colors.white24,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPremium ? Icons.stars_rounded : Icons.account_circle_outlined,
            color: isPremium ? Colors.white : Colors.white70,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            isPremium ? 'PREMIUM' : 'FREE',
            style: TextStyle(
              color: isPremium ? Colors.white : Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTourStep {
  final int navIndex;
  final IconData icon;
  final String title;
  final String description;
  final String primaryLabel;

  const _NavTourStep({
    required this.navIndex,
    required this.icon,
    required this.title,
    required this.description,
    required this.primaryLabel,
  });
}

class _FloatingNotificationBanner extends StatefulWidget {
  final String title;
  final String body;
  final String type;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _FloatingNotificationBanner({
    required this.title,
    required this.body,
    required this.type,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_FloatingNotificationBanner> createState() =>
      _FloatingNotificationBannerState();
}

class _FloatingNotificationBannerState
    extends State<_FloatingNotificationBanner> {
  bool _isVisible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _isVisible = true);
      }
    });

    _timer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _isVisible = false);
        Future.delayed(const Duration(milliseconds: 300), () {
          widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    IconData icon = Icons.notifications_active_rounded;
    Color iconColor = AppColors.primaryLight;
    Color iconBgColor = AppColors.primary.withOpacity(0.06);

    if (widget.type.toLowerCase() == 'payment') {
      icon = Icons.account_balance_wallet_rounded;
      iconColor = const Color(0xFFD4AF37);
      iconBgColor = const Color(0xFFFCF8F2);
    }

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      top: _isVisible ? topPadding + 10 : -120,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () {
            setState(() => _isVisible = false);
            widget.onTap();
            Future.delayed(const Duration(milliseconds: 300), () {
              widget.onDismiss();
            });
          },
          onPanUpdate: (details) {
            if (details.delta.dy < -5) {
              setState(() => _isVisible = false);
              Future.delayed(const Duration(milliseconds: 300), () {
                widget.onDismiss();
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: AppColors.primary.withOpacity(0.08),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.primary.withOpacity(0.7),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.drag_handle_rounded,
                  color: AppColors.primary.withOpacity(0.2),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
