import 'package:flutter/foundation.dart';

/// Base for screen view models. A request that finishes after its screen has closed must not
/// throw, so notifications after [dispose] are dropped; check [disposed] before using a result.
abstract class ViewModel extends ChangeNotifier {
  bool _disposed = false;

  bool get disposed => _disposed;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
