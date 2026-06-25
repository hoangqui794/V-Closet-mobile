import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'core/theme/app_theme.dart';
import 'core/app_routes.dart';
import 'injection_container.dart' as di;
import 'data/datasources/auth_local_storage.dart';
import 'data/datasources/ad_service.dart';
import 'presentation/pages/auth/login_page.dart';
import 'presentation/pages/profile/style_dna_quiz_page.dart';
import 'presentation/pages/main_screen.dart';
import 'presentation/pages/profile/change_password_page.dart';
import 'services/in_app_update_service.dart';

import 'dart:io';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cấu hình Edge-to-Edge cho Android 15+: thanh status/navigation bar trong suốt
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('=== CUSTOM ERROR HANDLER ===');
    debugPrint('Exception: ${details.exception}');
    debugPrint('Stacktrace:\n${details.stack}');
    debugPrint('============================');
  };
  HttpOverrides.global = MyHttpOverrides();
  await di.init();

  // Khởi tạo AdMob và tải trước các quảng cáo
  await AdService.initialize();
  final adService = AdService();
  adService.loadRewardedAd();
  adService.loadInterstitialAd();

  final hasSession = GetIt.I<AuthLocalStorage>().hasSession();
  final isOnboardingCompleted = GetIt.I<AuthLocalStorage>().isOnboardingCompleted();
  final userRole = GetIt.I<AuthLocalStorage>().getUserRole() ?? 'Customer';
  final isPasswordSet = GetIt.I<AuthLocalStorage>().isPasswordSet();

  debugPrint('=== DEBUG APP STATE AT START ===');
  debugPrint('hasSession: $hasSession');
  debugPrint('isOnboardingCompleted (local): $isOnboardingCompleted');
  debugPrint('userRole: $userRole');
  debugPrint('isPasswordSet: $isPasswordSet');
  debugPrint('================================');

  runApp(ProviderScope(
    child: VClosetApp(
      hasSession: hasSession,
      isOnboardingCompleted: userRole.toLowerCase() != 'customer' || isOnboardingCompleted,
      isPasswordSet: isPasswordSet,
    ),
  ));
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class VClosetApp extends StatefulWidget {
  final bool hasSession;
  final bool isOnboardingCompleted;
  final bool isPasswordSet;
  const VClosetApp({
    super.key,
    required this.hasSession,
    required this.isOnboardingCompleted,
    required this.isPasswordSet,
  });

  @override
  State<VClosetApp> createState() => _VClosetAppState();
}

class _VClosetAppState extends State<VClosetApp> {
  @override
  void initState() {
    super.initState();
    // Kiểm tra và bắt buộc cập nhật ngay khi app khởi động
    WidgetsBinding.instance.addPostFrameCallback((_) {
      InAppUpdateService.checkForUpdate();
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget initialScreen;
    if (!widget.hasSession) {
      initialScreen = const LoginPage();
    } else if (!widget.isPasswordSet) {
      initialScreen = const ChangePasswordPage();
    } else if (widget.isOnboardingCompleted) {
      initialScreen = const MainScreen();
    } else {
      initialScreen = const StyleDnaQuizPage(isOnboarding: true);
    }

    return MaterialApp(
      title: 'V-Closet Mobile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      navigatorKey: navigatorKey,
      // Named routes — mọi trang navigate qua tên, không cần import nhau
      routes: {
        AppRoutes.login:      (_) => const LoginPage(),
        AppRoutes.onboarding: (_) => const StyleDnaQuizPage(isOnboarding: true),
        AppRoutes.main:       (_) => const MainScreen(),
      },
      home: initialScreen,
    );
  }
}
