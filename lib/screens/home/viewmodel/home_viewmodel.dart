import 'package:flutter/foundation.dart';

import '../model/home_tab.dart';

class HomeViewModel extends ChangeNotifier {
  HomeTab _tab = HomeTab.signal;
  HomeTab get tab => _tab;

  void select(HomeTab tab) {
    if (tab == _tab) return;
    _tab = tab;
    notifyListeners();
  }
}
