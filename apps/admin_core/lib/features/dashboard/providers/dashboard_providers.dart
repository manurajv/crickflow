import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/dashboard_repository.dart';
import '../models/dashboard_models.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return const DashboardRepository();
});

/// Live clock for welcome header / health strip.
final dashboardNowProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 30), (_) => DateTime.now());
});

class DashboardController
    extends StateNotifier<AsyncValue<DashboardSnapshot>> {
  DashboardController(this._ref) : super(const AsyncLoading()) {
    refresh();
  }

  final Ref _ref;
  bool _busy = false;

  Future<void> refresh({bool quiet = false}) async {
    if (_busy) return;
    _busy = true;
    if (!quiet) {
      state = const AsyncLoading<DashboardSnapshot>().copyWithPrevious(state);
    }
    try {
      final appType = _ref.read(adminAppTypeProvider);
      final admin = _ref.read(adminSessionProvider).adminUser;
      final snapshot = await _ref.read(dashboardRepositoryProvider).fetch(
            appType: appType,
            organizationId: admin?.organizationId,
            organizationName: admin?.organizationName,
          );
      state = AsyncData(snapshot);
    } catch (e, st) {
      state = AsyncError<DashboardSnapshot>(e, st).copyWithPrevious(state);
    } finally {
      _busy = false;
    }
  }
}

final dashboardControllerProvider = StateNotifierProvider.autoDispose<
    DashboardController, AsyncValue<DashboardSnapshot>>((ref) {
  return DashboardController(ref);
});
