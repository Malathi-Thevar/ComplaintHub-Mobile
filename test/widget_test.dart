// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:complaint_hub/main.dart';

void main() {
  testWidgets('ComplaintHubApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ComplaintHubApp());

    // Verify that the title text exists.
    expect(find.text('ComplaintHub'), findsOneWidget);

    // Let the splash timer finish and transition to WelcomeScreen
    await tester.pumpAndSettle(const Duration(milliseconds: 3000));
  });
}
