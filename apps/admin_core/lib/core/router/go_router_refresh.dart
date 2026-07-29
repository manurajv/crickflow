import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_providers.dart';

/// Notifies GoRouter when Riverpod auth/session state changes.
class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(this._ref) {
    _subs = [
      _ref.listen(authStateProvider, (_, _) => notifyListeners()),
      _ref.listen(adminUserProvider, (_, _) => notifyListeners()),
      _ref.listen(roleDefinitionProvider, (_, _) => notifyListeners()),
      _ref.listen(idTokenProvider, (_, _) => notifyListeners()),
    ];
  }

  final Ref _ref;
  late final List<ProviderSubscription<dynamic>> _subs;

  @override
  void dispose() {
    for (final s in _subs) {
      s.close();
    }
    super.dispose();
  }
}
