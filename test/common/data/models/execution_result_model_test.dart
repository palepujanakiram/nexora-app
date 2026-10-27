import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/data/models/execution_result_model.dart';
import 'package:nexora_app/common/domain/entities/execution_result.dart';

void main() {
  final time = DateTime.utc(2026, 10, 27, 9, 30);

  test('toJson writes all fields including orders', () {
    final r = ExecutionResult(
      accountLabel: 'A',
      broker: 'Zerodha',
      signalText: 'BUY X',
      paper: true,
      time: time,
      symbol: 'SYM',
      quantity: 40,
      entryPrice: 410.5,
      orders: const [PlacedOrder('ENTRY', '1'), PlacedOrder('GTT OCO', '2')],
    );
    expect(ExecutionResultModel.toJson(r), {
      'accountLabel': 'A',
      'broker': 'Zerodha',
      'signalText': 'BUY X',
      'paper': true,
      'time': '2026-10-27T09:30:00.000Z',
      'symbol': 'SYM',
      'quantity': 40,
      'entryPrice': 410.5,
      'orders': [
        {'kind': 'ENTRY', 'id': '1'},
        {'kind': 'GTT OCO', 'id': '2'},
      ],
      'error': null,
    });
  });

  test('fromJson round-trips a successful result', () {
    final r = ExecutionResult(
      accountLabel: 'A',
      broker: 'Upstox',
      signalText: 's',
      paper: false,
      time: time,
      symbol: 'SYM',
      quantity: 20,
      entryPrice: 400,
      orders: const [PlacedOrder('ENTRY', '9')],
    );
    final back = ExecutionResultModel.fromJson(ExecutionResultModel.toJson(r));
    expect(back.accountLabel, 'A');
    expect(back.broker, 'Upstox');
    expect(back.signalText, 's');
    expect(back.paper, isFalse);
    expect(back.time, time);
    expect(back.symbol, 'SYM');
    expect(back.quantity, 20);
    expect(back.entryPrice, 400.0);
    expect(back.orders.single.kind, 'ENTRY');
    expect(back.orders.single.id, '9');
    expect(back.success, isTrue);
  });

  test('fromJson converts integer entry prices to double', () {
    final back = ExecutionResultModel.fromJson({
      'accountLabel': 'A',
      'broker': 'b',
      'signalText': 's',
      'paper': true,
      'time': '2026-10-27T09:30:00.000Z',
      'entryPrice': 420,
    });
    expect(back.entryPrice, isA<double>());
    expect(back.entryPrice, 420.0);
  });

  test('fromJson handles a failed result without optional fields or orders', () {
    final back = ExecutionResultModel.fromJson({
      'accountLabel': 'A',
      'broker': 'b',
      'signalText': 's',
      'paper': true,
      'time': '2026-10-27T09:30:00.000Z',
      'error': 'Token expired',
    });
    expect(back.symbol, isNull);
    expect(back.quantity, isNull);
    expect(back.entryPrice, isNull);
    expect(back.orders, isEmpty);
    expect(back.error, 'Token expired');
    expect(back.success, isFalse);
  });
}
