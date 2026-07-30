import 'package:crickflow_admin_core/features/security/models/security_enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SocHubSection visibility', () {
    test('Org Admin never sees platform-only sections', () {
      final visible = SocHubSection.visibleFor(isSuperAdmin: false);
      expect(visible, isNot(contains(SocHubSection.roleManagement)));
      expect(visible, isNot(contains(SocHubSection.ipManagement)));
      expect(visible, isNot(contains(SocHubSection.backupCenter)));
      expect(visible, isNot(contains(SocHubSection.disasterRecovery)));
      expect(visible, contains(SocHubSection.dashboard));
      expect(visible, contains(SocHubSection.loginSessions));
      expect(visible, contains(SocHubSection.securityAlerts));
    });

    test('Super Admin sees all sections', () {
      final visible = SocHubSection.visibleFor(isSuperAdmin: true);
      expect(visible, hasLength(SocHubSection.values.length));
    });
  });
}
