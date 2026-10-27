import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../common/domain/entities/execution_result.dart';
import '../model/activity_state.dart';
import '../usecase/clear_activity_usecase.dart';
import '../usecase/watch_activity_usecase.dart';

class ActivityViewModel extends ChangeNotifier {
  ActivityViewModel(WatchActivityUseCase watchActivity, this._clear) {
    _sub = watchActivity().listen((results) {
      _state = ActivityState(results: results);
      notifyListeners();
    });
  }

  final ClearActivityUseCase _clear;
  late final StreamSubscription<List<ExecutionResult>> _sub;

  ActivityState _state = const ActivityState();
  ActivityState get state => _state;

  Future<void> clear() => _clear();

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
