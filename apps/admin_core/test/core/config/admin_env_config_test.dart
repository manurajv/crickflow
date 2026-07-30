import 'package:crickflow_admin_core/core/config/admin_env_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AdminBuildEnvironment parses known values', () {
    expect(
      AdminBuildEnvironment.parse('production'),
      AdminBuildEnvironment.production,
    );
    expect(
      AdminBuildEnvironment.parse('nope'),
      AdminBuildEnvironment.development,
    );
  });

  test('production is not isolated from production resources', () {
    expect(AdminBuildEnvironment.production.isolatesFromProduction, isFalse);
    expect(AdminBuildEnvironment.development.isolatesFromProduction, isTrue);
  });

  test('default AdminEnvConfig is development', () {
    expect(AdminEnvConfig.environment, AdminBuildEnvironment.development);
    expect(AdminEnvConfig.displayBanner, contains('Development'));
  });
}
