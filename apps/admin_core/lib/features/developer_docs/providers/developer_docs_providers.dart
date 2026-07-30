import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/developer_docs_catalog.dart';

final developerDocsQueryProvider = StateProvider<String>((ref) => '');

final developerDocsSelectedIdProvider =
    StateProvider<String>((ref) => DeveloperDocsCatalog.pages.first.id);

final developerDocsFilteredProvider = Provider<List<DeveloperDocPage>>((ref) {
  return DeveloperDocsCatalog.search(ref.watch(developerDocsQueryProvider));
});

final developerDocBodyProvider =
    FutureProvider.family<String, String>((ref, pageId) async {
  final page = DeveloperDocsCatalog.byId(pageId);
  if (page == null) return '# Not found\n\nUnknown documentation page.';
  try {
    return await rootBundle.loadString(page.assetPath);
  } catch (_) {
    return '# Missing asset\n\nCould not load `${page.assetPath}`.\n\n'
        'Ensure `apps/admin_core/assets/docs/` is listed in pubspec assets '
        'and mirrors `docs/developer/`.';
  }
});
