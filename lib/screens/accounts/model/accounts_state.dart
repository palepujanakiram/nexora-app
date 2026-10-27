import '../../../common/domain/entities/broker_account.dart';

class AccountsState {
  const AccountsState({this.accounts = const []});

  final List<BrokerAccount> accounts;

  bool get isEmpty => accounts.isEmpty;

  /// Accounts grouped by broker, in [BrokerType] order, skipping empty groups.
  List<(BrokerType, List<BrokerAccount>)> get groups => [
        for (final broker in BrokerType.values)
          if (accounts.any((a) => a.broker == broker)) (broker, accounts.where((a) => a.broker == broker).toList()),
      ];
}
