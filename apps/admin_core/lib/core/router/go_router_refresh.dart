import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_providers.dart';

/// Notifies GoRouter when Riverpod auth/session state changes.
///
/// [notifyListeners] is deferred to the next frame so auth stream updates do
/// not mutate Riverpod's provider map while [UncontrolledProviderScope] is
/// iterating dependents (which causes [ConcurrentModificationError] on web,
/// often followed by CanvasKit `_handledContextLostEvent` crashes).
class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(this._ref) {
    _subs = [
      _ref.listen(authStateProvider, (_, _) => _scheduleRefresh()),
      _ref.listen(adminUserProvider, (_, _) => _scheduleRefresh()),
      _ref.listen(roleDefinitionProvider, (_, _) => _scheduleRefresh()),
      _ref.listen(idTokenProvider, (_, _) => _scheduleRefresh()),
    ];
  }

  final Ref _ref;
  late final List<ProviderSubscription<dynamic>> _subs;
  bool _scheduled = false;
  bool _disposed = false;

  void _scheduleRefresh() {
    if (_scheduled || _disposed) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subs) {
      s.close();
    }
    super.dispose();
  }
}
