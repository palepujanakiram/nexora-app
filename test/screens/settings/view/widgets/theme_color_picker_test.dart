import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/app_settings.dart';
import 'package:nexora_app/screens/settings/view/widgets/theme_color_picker.dart';

void main() {
  testWidgets('shows every colour, checks the selected one and reports taps', (tester) async {
    final picked = <ThemeColor>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ThemeColorPicker(selected: ThemeColor.blue, onSelected: picked.add)),
    ));

    expect(find.byType(InkWell), findsNWidgets(ThemeColor.values.length));
    for (final c in ThemeColor.values) {
      expect(find.byTooltip(c.label), findsOneWidget);
    }
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.descendant(of: find.byTooltip('Blue'), matching: find.byIcon(Icons.check)), findsOneWidget);

    final blue = tester.widget<AnimatedContainer>(
        find.descendant(of: find.byTooltip('Blue'), matching: find.byType(AnimatedContainer)));
    final decoration = blue.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFF1565C0));
    expect((decoration.border! as Border).top.color, isNot(Colors.transparent));

    final teal = tester.widget<AnimatedContainer>(
        find.descendant(of: find.byTooltip('Teal'), matching: find.byType(AnimatedContainer)));
    expect(((teal.decoration! as BoxDecoration).border! as Border).top.color, Colors.transparent);

    expect(tester.getSemantics(find.bySemanticsLabel('Blue theme')), isSemantics(isSelected: true, isButton: true));
    expect(tester.getSemantics(find.bySemanticsLabel('Teal theme')), isSemantics(isSelected: false));

    await tester.tap(find.byTooltip('Teal'));
    expect(picked, [ThemeColor.teal]);
  });
}
