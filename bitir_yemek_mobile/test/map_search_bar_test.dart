import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitir_yemek_mobile/config/theme.dart';
import 'package:bitir_yemek_mobile/features/map/presentation/widgets/map_search_bar.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'map search stays borderless on focus and clears at text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = TextEditingController();
        final changes = <String>[];
        var locationTaps = 0;
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
              body: Padding(
                padding: const EdgeInsets.all(20),
                child: MapSearchBar(
                  controller: controller,
                  onChanged: changes.add,
                  onLocationTap: () => locationTaps++,
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byType(TextField));
        await tester.enterText(find.byType(TextField), 'Mola');
        await tester.pumpAndSettle();
        final decoration = tester
            .widget<InputDecorator>(find.byType(InputDecorator))
            .decoration;
        expect(decoration.focusedBorder, InputBorder.none);
        expect(decoration.enabledBorder, InputBorder.none);
        expect(decoration.filled, false);
        expect(changes, ['Mola']);
        expect(find.byTooltip('Aramayı temizle'), findsOneWidget);
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .focusNode
              .hasFocus,
          false,
        );
        await tester.tap(find.byTooltip('Aramayı temizle'));
        await tester.pumpAndSettle();
        expect(controller.text, isEmpty);
        expect(changes, ['Mola', '']);
        expect(find.byTooltip('Aramayı temizle'), findsNothing);
        // The clear affordance also tracks changes made outside the parent build.
        controller.text = 'Fırın';
        await tester.pump();
        expect(find.byTooltip('Aramayı temizle'), findsOneWidget);
        await tester.tap(find.byTooltip('Arama ayarları'));
        expect(locationTaps, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );
  }
}
