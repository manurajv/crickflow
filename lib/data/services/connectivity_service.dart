import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Observes device network connectivity for offline sync.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  final _statusController = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  Stream<bool> get onStatusChanged => _statusController.stream;

  Future<void> init() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = _isConnected(results);
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final online = _isConnected(results);
      if (online == _isOnline) return;
      _isOnline = online;
      _statusController.add(online);
    });
  }

  bool _isConnected(List<ConnectivityResult> results) {
    return results.any(
      (r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.vpn,
    );
  }

  void dispose() {
    _subscription?.cancel();
    _statusController.close();
  }
}
