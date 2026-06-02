import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_closet_mobile/main.dart';
import 'package:v_closet_mobile/data/datasources/auth_local_storage.dart';
import 'package:v_closet_mobile/data/datasources/auth_api_service.dart';
import 'package:v_closet_mobile/data/datasources/api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  setUp(() async {
    GetIt.I.reset();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    dotenv.testLoad(fileInput: 'API_URL=http://localhost\nDEBUG_MODE=true');
    
    final dio = Dio();
    final apiService = ApiService(dio);
    final localStorage = AuthLocalStorage(prefs);
    final authApiService = AuthApiService(apiService, localStorage);
    
    GetIt.I.registerSingleton<AuthLocalStorage>(localStorage);
    GetIt.I.registerSingleton<AuthApiService>(authApiService);
  });

  testWidgets('App load smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const VClosetApp(hasSession: false, isOnboardingCompleted: false, isPasswordSet: true));
    await tester.pumpAndSettle();

    // Verify that our app shows the welcome text
    expect(find.text('V-CLOSET'), findsOneWidget);
  });
}
