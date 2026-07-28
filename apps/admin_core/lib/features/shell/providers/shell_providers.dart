import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/nav_models.dart';

final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);

final navSectionsProvider = Provider<List<AdminNavSection>>((ref) {
  throw UnimplementedError('Override navSectionsProvider per app');
});

final breadcrumbProvider = StateProvider<List<String>>((ref) => ['Dashboard']);
