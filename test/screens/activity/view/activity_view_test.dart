import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/di/injector.dart';
import 'package:nexora_app/common/domain/entities/execution_result.dart';
import 'package:nexora_app/common/presentation/widgets/execution_result_card.dart';
import 'package:nexora_app/screens/activity/usecase/clear_activity_usecase.dart';
import 'package:nexora_app/screens/activity/usecase/watch_activity_usecase.dart';
import 'package:nexora_app/screens/activity/view/activity_view.dart';

import '../../../fakes.dart';

void main() {
  late FakeActivityRepository activity;

  setUp(() {
    activity = FakeActivityRepository();
    sl
      ..reset()
      ..registerFactory(() => WatchActivityUseCase(activity))
      ..registerFactory(() => ClearActivityUseCase(activity));
  });

  Future<void> pumpView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ActivityView())));
    await tester.pumpAndSettle();
  }

  testWidgets('empty state has no Clear button', (tester) async {
    await pumpView(tester);

    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Executed signals will appear here.'), findsOneWidget);
    expect(find.text('Clear'), findsNothing);
    expect(find.byType(ExecutionResultCard), findsNothing);
  });

  testWidgets('lists results newest first with time and signal, and Clear empties it', (tester) async {
    await activity.addAll([
      ExecutionResult(
          accountLabel: 'Old', broker: 'Zerodha', signalText: 'BUY OLD', paper: true, time: DateTime(2026, 10, 1, 9, 5, 7)),
    ]);
    await activity.addAll([
      ExecutionResult(
          accountLabel: 'New',
          broker: 'Upstox',
          signalText: 'BUY NEW',
          paper: false,
          time: DateTime(2026, 10, 2, 14, 30),
          error: 'Rejected'),
    ]);
    await pumpView(tester);

    expect(find.text('Executed signals will appear here.'), findsNothing);
    expect(find.byType(ExecutionResultCard), findsNWidgets(2));
    expect(find.text('02 Oct, 14:30:00 · BUY NEW'), findsOneWidget);
    expect(find.text('01 Oct, 09:05:07 · BUY OLD'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('New')).dy,
      lessThan(tester.getTopLeft(find.text('Old (paper)')).dy),
    );

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(activity.current, isEmpty);
    expect(find.byType(ExecutionResultCard), findsNothing);
    expect(find.text('Executed signals will appear here.'), findsOneWidget);
    expect(find.text('Clear'), findsNothing);
  });

  testWidgets('new results appear live', (tester) async {
    await pumpView(tester);
    await activity.addAll([
      ExecutionResult(accountLabel: 'Live', broker: 'Zerodha', signalText: 'S', paper: false, time: DateTime(2026)),
    ]);
    await tester.pumpAndSettle();

    expect(find.byType(ExecutionResultCard), findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);
  });
}
