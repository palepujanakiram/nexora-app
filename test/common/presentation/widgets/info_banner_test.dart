import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/presentation/widgets/info_banner.dart';

void main() {
  testWidgets('shows the text on a full-width rounded box of the given colour', (tester) async {
    // Built non-const so the constructor runs at test time.
    const text = 'Heads up';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: InfoBanner(text: [text].first, color: Colors.amber)),
    ));

    expect(find.text('Heads up'), findsOneWidget);
    final box = tester.widget<Container>(find.byType(Container));
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.color, Colors.amber);
    expect(decoration.borderRadius, BorderRadius.circular(8));
    expect(box.padding, const EdgeInsets.all(12));
    expect(tester.getSize(find.byType(InfoBanner)).width, tester.view.physicalSize.width / tester.view.devicePixelRatio);
  });
}
