import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_providers.dart';

/// Notifies GoRouter when Riverpod auth/session state changes.
class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(this._ref) {
    _sub = _ref.listen(authStateProvider, (_, _) => notifyListeners());
    _adminSub = _ref.listen(adminUserProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;
  late final ProviderSubscription<dynamic> _sub;
  late final ProviderSubscription<dynamic> _adminSub;

  @override
  void dispose() {
    _sub.close();
    _adminSub.close();
    super.dispose();
  }
}
