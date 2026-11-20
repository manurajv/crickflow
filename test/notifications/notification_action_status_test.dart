import 'package:crickflow/core/navigation/notification_navigation.dart';
import 'package:crickflow/core/constants/series_notification_types.dart';
import 'package:crickflow/data/models/notification_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('action status labels match the in-place inbox copy', () {
    expect(notificationActionStatusLabel('accepted'), 'You accepted');
    expect(notificationActionStatusLabel('declined'), 'You declined');
    expect(notificationActionStatusLabel('approved'), 'Approved');
    expect(notificationActionStatusLabel('rejected'), 'Rejected');
    expect(notificationActionStatusLabel('cancelled'), 'Cancelled by sender');
    expect(notificationActionStatusLabel('expired'), 'Expired');
  });

  test('approval notifications are actionable only for reviewers', () {
    NotificationModel n({String? reviewScope, String? actionStatus}) =>
        NotificationModel(
          id: '1',
          userId: 'u',
          title: 'Approval needed',
          body: 'Please review',
          type: SeriesNotificationTypes.approvalPending,
          seriesId: 's1',
          requestId: 'a1',
          reviewScope: reviewScope,
          actionStatus: actionStatus,
        );
    expect(n(reviewScope: 'org').isActionable, isFalse);
    expect(n(reviewScope: 'club').usesApproveRejectActions, isFalse);
    expect(n(reviewScope: 'none').isActionable, isFalse);
    expect(
      n(reviewScope: 'org', actionStatus: 'approved').isActionable,
      isFalse,
    );
    expect(
      NotificationNavigation.routeForNotification(n(reviewScope: 'club')),
      '/series/s1/approvals/a1',
    );
  });
}
