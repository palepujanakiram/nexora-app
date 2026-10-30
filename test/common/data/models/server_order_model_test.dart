import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/data/models/server_order_model.dart';
import 'package:nexora_app/common/domain/entities/broker_account.dart';

import '../repositories/server/fake_server.dart';

void main() {
  test('contractLabel reads option ids and leaves others as they are', () {
    expect(ServerOrderModel.contractLabel('NFO:CE:NIFTY:2026-10-29:2450000'), 'NIFTY 29 OCT 2026 24500 CE');
    expect(ServerOrderModel.contractLabel('BFO:PE:SENSEX:2026-11-05:7310050'), 'SENSEX 05 NOV 2026 73100.50 PE');
    expect(ServerOrderModel.contractLabel('NSE:EQ:RELIANCE'), 'NSE:EQ:RELIANCE');
    expect(ServerOrderModel.contractLabel('NFO:FUT:NIFTY:2026-10-29:x'), 'NFO:FUT:NIFTY:2026-10-29:x');
  });

  test('product and rupees match the server\'s order fields', () {
    expect(ServerOrderModel.product(ProductType.carryForward), 'CARRYFORWARD');
    expect(ServerOrderModel.product(ProductType.intraday), 'INTRADAY');
    expect(ServerOrderModel.rupees(420), '420.00');
    expect(ServerOrderModel.rupees(99.95), '99.95');
  });

  test('fromOrder lists each leg with the account name, status and broker order id', () {
    const accounts = {
      'acc1': BrokerAccount(id: 'acc1', broker: BrokerType.zerodha, label: 'Main', apiKey: 'k', apiSecret: ''),
    };
    final results = ServerOrderModel.fromOrder(
      orderJson(kind: 'EXIT', legs: [
        legJson(mode: 'paper', status: 'PARTIALLY_FILLED'),
        legJson(accountId: 'acc2', status: 'UNKNOWN', brokerOrderId: null, error: {'code': 'TIMEOUT', 'message': 't'}),
        legJson(accountId: 'acc3', status: 'REJECTED', error: {'code': 'DRY_RUN'}),
      ]),
      accounts,
    );
    final [paper, unknown, rejected] = results;
    expect([paper.accountLabel, paper.broker, paper.paper, paper.success], ['Main', 'Zerodha (Kite Connect)', true, true]);
    expect(paper.orders.single.kind, 'EXIT (paper) · partially filled');
    expect(paper.orders.single.id, 'B1');
    expect(paper.time, DateTime.utc(2026, 10, 30, 4).toLocal());
    expect(paper.signalText, 'BUY 75 NIFTY 30 OCT 2026 24000 PE @ 100.00');
    expect([paper.symbol, paper.quantity, paper.entryPrice], ['NIFTY 30 OCT 2026 24000 PE', 75, 100]);

    expect([unknown.accountLabel, unknown.broker, unknown.success, unknown.errorCode], ['acc2', 'Upstox', true, 'TIMEOUT']);
    expect(unknown.orders.single.kind, 'EXIT · not confirmed yet, being checked');
    expect(unknown.orders.single.id, 'leg_acc2');

    expect([rejected.error, rejected.errorCode, rejected.orders], ['Rejected.', 'DRY_RUN', isEmpty]);
  });

  test('fromLeg falls back to the order\'s price and a market order', () {
    final r = ServerOrderModel.fromLeg(
      {'accountId': 'a', 'broker': 'groww', 'status': 'OPEN', 'mode': 'live'},
      order: {'side': 'SELL', 'quantity': 10, 'instrumentId': 'NSE:EQ:X'},
      accounts: const {},
      time: DateTime.utc(2026),
    );
    expect([r.signalText, r.entryPrice, r.broker, r.orders.single.id], ['SELL 10 NSE:EQ:X @ market', null, 'Groww', '-']);
    expect(ServerOrderModel.fromOrder({'createdAt': '2026-10-30T04:00:00Z'}, const {}), isEmpty);
  });
}
