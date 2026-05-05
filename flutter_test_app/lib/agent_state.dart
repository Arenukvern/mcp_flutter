// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';

/// A small, process-wide holder for the showcase app's runtime state.
///
/// Exposed at module scope so it's easy to reach from
/// `evaluate_dart_expression`, e.g.:
///
/// ```
/// AgentState.instance.counter
/// AgentState.instance.greeting
/// AgentState.instance.toggle
/// AgentState.instance.slider
/// ```
class AgentState extends ChangeNotifier {
  AgentState._();

  static final AgentState instance = AgentState._();

  int _counter = 0;
  String _greeting = '';
  bool _toggle = false;
  double _slider = 50;
  String _lastLog = '';

  int get counter => _counter;
  String get greeting => _greeting;
  bool get toggle => _toggle;
  double get slider => _slider;
  String get lastLog => _lastLog;

  void increment() {
    _counter += 1;
    notifyListeners();
  }

  set greeting(final String value) {
    if (_greeting == value) return;
    _greeting = value;
    notifyListeners();
  }

  set toggle(final bool value) {
    if (_toggle == value) return;
    _toggle = value;
    notifyListeners();
  }

  set slider(final double value) {
    if (_slider == value) return;
    _slider = value;
    notifyListeners();
  }

  void logMessage(final String message) {
    _lastLog = message;
    print(message);
    notifyListeners();
  }

  Map<String, Object?> snapshot() => <String, Object?>{
    'counter': _counter,
    'greeting': _greeting,
    'toggle': _toggle,
    'slider': _slider,
    'lastLog': _lastLog,
  };
}
