import 'package:flutter/material.dart';

/// Bottom-navigation tab state (so Home quick actions can switch tabs).
class ShellProvider extends ChangeNotifier {
  int _index = 0;
  int get index => _index;

  void go(int index) {
    if (index == _index) return;
    _index = index;
    notifyListeners();
  }
}
