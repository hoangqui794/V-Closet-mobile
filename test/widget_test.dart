import 'package:flutter_test/flutter_test.dart';
import 'package:v_closet_mobile/main.dart';

void main() {
  testWidgets('App load smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Note: In real tests with DI, you might need to mock dependencies
    await tester.pumpWidget(const VClosetApp());

    // Verify that our app shows the welcome text
    expect(find.text('V-Closet Premium'), findsOneWidget);
  });
}
