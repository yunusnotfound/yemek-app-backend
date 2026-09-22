import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitir_yemek_mobile/config/theme.dart';
import 'package:bitir_yemek_mobile/features/map/presentation/widgets/location_picker_sheet.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'distance settings apply only on confirmation and fit at scale $scale',
      (tester) async {
        tester.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        ({double lat, double lng, double radius})? result;
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
                    result =
                        await showModalBottomSheet<
                          ({double lat, double lng, double radius})
                        >(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (_) => const LocationPickerSheet(
                            initialLat: 41,
                            initialLng: 29,
                            initialRadius: 10,
                          ),
                        );
                  },
                  child: const Text('Ayarları aç'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Ayarları aç'));
        await tester.pumpAndSettle();
        expect(tester.widget<Slider>(find.byType(Slider)).value, 10);
        await tester.ensureVisible(find.byType(Slider));
        await tester.drag(find.byType(Slider), const Offset(40, 0));
        await tester.pumpAndSettle();
        expect(
          tester.widget<Slider>(find.byType(Slider)).value,
          greaterThan(10),
        );
        final preset = find.widgetWithText(ChoiceChip, '25 km');
        await tester.ensureVisible(preset);
        await tester.tap(preset);
        await tester.pumpAndSettle();
        expect(tester.widget<Slider>(find.byType(Slider)).value, 25);
        expect(result, isNull);
        await tester.ensureVisible(find.text('Sonuçları göster'));
        await tester.tap(find.text('Sonuçları göster'));
        await tester.pumpAndSettle();
        expect(result, (lat: 41.0, lng: 29.0, radius: 25.0));
        await tester.tap(find.text('Ayarları aç'));
        await tester.pumpAndSettle();
        expect(tester.widget<Slider>(find.byType(Slider)).value, 10);
        await tester.tap(find.byTooltip('Kapat'));
        await tester.pumpAndSettle();
        expect(result, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
