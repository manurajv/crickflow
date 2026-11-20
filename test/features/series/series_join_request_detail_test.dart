import 'package:crickflow/core/navigation/notification_navigation.dart';
import 'package:crickflow/core/constants/series_notification_types.dart';
import 'package:crickflow/data/models/series/series.dart';
import 'package:crickflow/features/series/presentation/widgets/series_document_image.dart';
import 'package:crickflow/features/series/presentation/widgets/series_ui.dart';
import 'package:crickflow/features/series/presentation/widgets/series_user_name.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('join-request notifications deep-link to the request detail screen', () {
    expect(
      NotificationNavigation.routeFor(
        type: SeriesNotificationTypes.approvalPending,
        seriesId: 's1',
        requestId: 'a9',
        clubId: 'c1',
      ),
      '/series/s1/approvals/a9',
    );
  });

  test('merged approvals are not treated as still pending', () {
    final item = SeriesApprovalModel.fromMap('a1', {
      'seriesId': 's1',
      'targetType': 'playerJoin',
      'targetId': 'c1_u1',
      'requestedBy': 'u1',
      'status': 'merged',
    });
    expect(item.status, SeriesApprovalStatus.merged);
    expect(item.isPending, isFalse);
    expect(item.status.label, 'Updated');
  });

  test('identity labels never use raw field keys or document ids', () {
    expect(
      seriesIdentityFieldLabel('nationalIdDocUrl'),
      'National ID document',
    );
    expect(
      seriesIdentityFieldLabel('crickFlowPlayerId'),
      'CrickFlow Player ID',
    );
    expect(
      seriesIdentityFieldLabel('nationalIdDocUrl').contains('Url'),
      isFalse,
    );
  });

  testWidgets('document image shows a missing-state and opens a zoom viewer', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SeriesDocumentImage(url: null, label: 'National ID document'),
        ),
      ),
    );
    expect(find.text('National ID document'), findsOneWidget);
    expect(find.text('No document uploaded'), findsOneWidget);
  });

  test('team admin add requests are reviewed by org admins, not as a team first pass', () {
    final add = SeriesRequestActionScope.resolve(
      pending: true,
      isClubAdmin: true,
      isOrgAdmin: true,
      isSuperAdmin: false,
      targetType: 'playerAdd',
      clubReviewStatus: '',
    );
    expect(add.clubScope, isFalse);
    expect(add.orgScope, isTrue);

    final join = SeriesRequestActionScope.resolve(
      pending: true,
      isClubAdmin: true,
      isOrgAdmin: false,
      isSuperAdmin: false,
      targetType: 'playerJoin',
      clubReviewStatus: 'pending',
    );
    expect(join.clubScope, isTrue);
    expect(join.orgScope, isFalse);

    final joinForOrg = SeriesRequestActionScope.resolve(
      pending: true,
      isClubAdmin: false,
      isOrgAdmin: true,
      isSuperAdmin: false,
      targetType: 'playerJoin',
      clubReviewStatus: 'approved',
    );
    expect(joinForOrg.orgScope, isTrue);
  });
}
