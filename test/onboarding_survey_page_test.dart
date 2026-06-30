import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_closet_mobile/core/theme/app_theme.dart';
import 'package:v_closet_mobile/data/datasources/auth_local_storage.dart';
import 'package:v_closet_mobile/data/datasources/user_api_service.dart';
import 'package:v_closet_mobile/presentation/pages/profile/style_dna_quiz_page.dart';
import 'package:dio/dio.dart';
import 'package:v_closet_mobile/data/datasources/api_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  setUp(() async {
    GetIt.I.reset();
    SharedPreferences.setMockInitialValues({
      'access_token': 'mock_token',
      'user_name': 'Test User',
      'is_onboarding_completed': false,
    });
    final prefs = await SharedPreferences.getInstance();

    // Load mock .env data
    dotenv.testLoad(fileInput: 'API_URL=http://localhost\nDEBUG_MODE=true');

    final dio = Dio();
    final apiService = ApiService(dio);
    final localStorage = AuthLocalStorage(prefs);
    final userApiService = UserApiService(apiService);

    GetIt.I.registerSingleton<AuthLocalStorage>(localStorage);
    GetIt.I.registerSingleton<UserApiService>(userApiService);
  });

  testWidgets('StyleDnaQuizPage onboarding renders and does not crash', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const StyleDnaQuizPage(isOnboarding: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chào mừng bạn!'), findsOneWidget);
  });
}
