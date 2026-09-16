import 'package:flutter_test/flutter_test.dart';

import 'package:bitir_yemek_mobile/main.dart';
import 'package:bitir_yemek_mobile/features/splash/presentation/pages/splash_page.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MainApp());
    await tester.pump();

    // The opening scene renders the brand as artwork, not a Text widget.
    expect(find.byType(SplashPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
