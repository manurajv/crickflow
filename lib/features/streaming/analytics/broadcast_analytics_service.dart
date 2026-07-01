import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Device + network telemetry for the broadcaster dashboard.
class BroadcastAnalyticsSnapshot extends Equatable {
  const BroadcastAnalyticsSnapshot({
    this.networkType = 'Unknown',
    this.uploadSpeedKbps,
    this.batteryPercent,
    this.isWifi = false,
    this.isMobile = false,
  });

  final String networkType;
  final double? uploadSpeedKbps;
  final int? batteryPercent;
  final bool isWifi;
  final bool isMobile;

  @override
  List<Object?> get props =>
      [networkType, uploadSpeedKbps, batteryPercent, isWifi];
}

class BroadcastAnalyticsService {
  BroadcastAnalyticsService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  final _controller =
      StreamController<BroadcastAnalyticsSnapshot>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _sub;

  Stream<BroadcastAnalyticsSnapshot> get snapshots => _controller.stream;

  Future<void> start() async {
    await _sub?.cancel();
    final initial = await _connectivity.checkConnectivity();
    _emit(initial);
    _sub = _connectivity.onConnectivityChanged.listen(_emit);
  }

  void _emit(List<ConnectivityResult> results) {
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      _controller.add(const BroadcastAnalyticsSnapshot(networkType: 'Offline'));
      return;
    }
    final primary = results.firstWhere(
      (r) => r != ConnectivityResult.none,
      orElse: () => results.first,
    );
    final label = switch (primary) {
      ConnectivityResult.wifi => 'Wi‑Fi',
      ConnectivityResult.ethernet => 'Ethernet',
      ConnectivityResult.mobile => 'Mobile',
      ConnectivityResult.vpn => 'VPN',
      ConnectivityResult.bluetooth => 'Bluetooth',
      ConnectivityResult.other => 'Other',
      ConnectivityResult.satellite => 'Satellite',
      ConnectivityResult.none => 'Offline',
    };
    _controller.add(BroadcastAnalyticsSnapshot(
      networkType: label,
      isWifi: primary == ConnectivityResult.wifi ||
          primary == ConnectivityResult.ethernet,
      isMobile: primary == ConnectivityResult.mobile,
    ));
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _controller.close();
  }
}

final broadcastAnalyticsServiceProvider =
    Provider.autoDispose<BroadcastAnalyticsService>((ref) {
  final service = BroadcastAnalyticsService();
  ref.onDispose(service.dispose);
  unawaited(service.start());
  return service;
});

final broadcastAnalyticsProvider =
    StreamProvider.autoDispose<BroadcastAnalyticsSnapshot>((ref) {
  return ref.watch(broadcastAnalyticsServiceProvider).snapshots;
});
