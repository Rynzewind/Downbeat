final class BrowserNavigationController {
  Future<void> Function()? _back;
  Future<void> Function()? _forward;
  Future<void> Function()? _reload;

  void attach({
    required Future<void> Function() back,
    required Future<void> Function() forward,
    required Future<void> Function() reload,
  }) {
    _back = back;
    _forward = forward;
    _reload = reload;
  }

  void detach() {
    _back = null;
    _forward = null;
    _reload = null;
  }

  Future<void> back() => _back?.call() ?? Future.value();
  Future<void> forward() => _forward?.call() ?? Future.value();
  Future<void> reload() => _reload?.call() ?? Future.value();
}
