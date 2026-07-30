import 'package:crickflow_admin_core/features/developer_docs/data/developer_docs_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog search finds firestore by keyword', () {
    final hits = DeveloperDocsCatalog.search('admin_users');
    expect(hits.any((p) => p.id == 'firestore'), isTrue);
  });

  test('catalog sections are stable and non-empty', () {
    expect(DeveloperDocsCatalog.sections, isNotEmpty);
    expect(DeveloperDocsCatalog.byId('architecture'), isNotNull);
  });
}
