import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitir_yemek_mobile/config/theme.dart';
import 'package:bitir_yemek_mobile/shared/widgets/app_dialog.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    List<bool> results, {
    double scale = 1,
    Size size = const Size(390, 844),
    String confirmLabel = 'Kaldır',
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                results.add(
                  await AppDialog.confirm(
                    context,
                    title: 'Favorilerden kaldır',
                    message: 'Mahalle Fırını favorilerinizden kaldırılsın mı?',
                    confirmLabel: confirmLabel,
                  ),
                );
              },
              child: const Text('Aç'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'cancel, close, barrier and back never confirm; action confirms once',
    (tester) async {
      final results = <bool>[];
      await mount(tester, results);
      Future<void> open() async {
        await tester.tap(find.text('Aç'));
        await tester.pumpAndSettle();
      }

      await open();
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      await open();
      await tester.tap(find.byTooltip('Kapat'));
      await tester.pumpAndSettle();
      await open();
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      await open();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(results, [false, false, false, false]);
      await open();
      await tester.tap(find.text('Kaldır'));
      await tester.pumpAndSettle();
      expect(results, [false, false, false, false, true]);
    },
  );

  testWidgets('large text and short screens keep long actions reachable', (
    tester,
  ) async {
    final results = <bool>[];
    await mount(
      tester,
      results,
      scale: 2,
      size: const Size(320, 480),
      confirmLabel: 'Favorilerden kaldır',
    );
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final confirm = find.widgetWithText(TextButton, 'Favorilerden kaldır');
    await tester.ensureVisible(confirm);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(results, [true]);
    expect(tester.takeException(), isNull);
  });
}
