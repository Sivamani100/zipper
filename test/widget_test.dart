import 'package:flutter_test/flutter_test.dart';
import 'package:zipgame/main.dart';

void main() {
  testWidgets('Zip Game Home Load Test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const LinkedInZipApp());

    // Verify that our game home screen loads and shows the reset button.
    expect(find.text('Reset'), findsOneWidget);
  });
}

