import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'injection_container.dart' as di;
import 'presentation/pages/home/home_page.dart';
import 'presentation/pages/auth/login_page.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init();
  
  runApp(
    const ProviderScope(
      child: VClosetApp(),
    ),
  );
}

class VClosetApp extends StatelessWidget {
  const VClosetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'V-Closet Mobile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      home: const LoginPage(),
    );

  }
}
