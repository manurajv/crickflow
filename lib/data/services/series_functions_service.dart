import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Typed gateway for privileged Series operations enforced by Cloud Functions.
class SeriesFunctionsService {
  SeriesFunctionsService({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(
              app: Firebase.app(),
              region: 'us-central1',
            );

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> createSeries(Map<String, dynamic> data) =>
      _call('createSeries', data);

  Future<Map<String, dynamic>> addSeriesAdmin({
    required String seriesId,
    required String userId,
    String displayName = '',
    List<String> permissions = const [],
  }) =>
      _call('addSeriesAdmin', {
        'seriesId': seriesId,
        'userId': userId,
        'displayName': displayName,
        'permissions': permissions,
      });

  Future<Map<String, dynamic>> removeSeriesAdmin({
    required String seriesId,
    required String userId,
  }) =>
      _call('removeSeriesAdmin', {'seriesId': seriesId, 'userId': userId});

  Future<Map<String, dynamic>> createSeriesClub(Map<String, dynamic> data) =>
      _call('createSeriesClub', data);

  Future<Map<String, dynamic>> reviewSeriesApproval({
    required String seriesId,
    required String approvalId,
    required String decision,
    String reason = '',
  }) =>
      _call('reviewSeriesApproval', {
        'seriesId': seriesId,
        'approvalId': approvalId,
        'decision': decision,
        'reason': reason,
      });

  Future<Map<String, dynamic>> submitSeriesRegistration(
    Map<String, dynamic> data,
  ) =>
      _call('submitSeriesRegistration', data);

  Future<Map<String, dynamic>> submitPlayerJoinRequest(
    Map<String, dynamic> data,
  ) =>
      _call('submitPlayerJoinRequest', data);

  Future<Map<String, dynamic>> submitPlayerAddRequest(
    Map<String, dynamic> data,
  ) =>
      _call('submitPlayerAddRequest', data);

  Future<Map<String, dynamic>> submitPlayerRemovalRequest(
    Map<String, dynamic> data,
  ) =>
      _call('submitPlayerRemovalRequest', data);

  Future<Map<String, dynamic>> proposeSeriesMatch(Map<String, dynamic> data) =>
      _call('proposeSeriesMatch', data);

  Future<Map<String, dynamic>> proposeSeriesTournament(
    Map<String, dynamic> data,
  ) =>
      _call('proposeSeriesTournament', data);

  Future<Map<String, dynamic>> updateSeriesSettings({
    required String seriesId,
    required Map<String, dynamic> settings,
  }) =>
      _call('updateSeriesSettings', {
        'seriesId': seriesId,
        'settings': settings,
      });

  Future<Map<String, dynamic>> suspendSeriesEntity({
    required String seriesId,
    required String entityType,
    required String entityId,
    String reason = '',
  }) =>
      _call('suspendSeriesEntity', {
        'seriesId': seriesId,
        'entityType': entityType,
        'entityId': entityId,
        'reason': reason,
      });

  Future<Map<String, dynamic>> getSeriesRegistrationIdentity({
    required String seriesId,
    required String registrationId,
  }) =>
      _call('getSeriesRegistrationIdentity', {
        'seriesId': seriesId,
        'registrationId': registrationId,
      });

  Future<Map<String, dynamic>> reviewClubJoinRequest({
    required String seriesId,
    required String approvalId,
    required String decision,
    String reason = '',
  }) =>
      _call('reviewClubJoinRequest', {
        'seriesId': seriesId,
        'approvalId': approvalId,
        'decision': decision,
        'reason': reason,
      });

  Future<Map<String, dynamic>> addSeriesClubAdmin({
    required String seriesId,
    required String clubId,
    required String userId,
    String displayName = '',
  }) =>
      _call('addSeriesClubAdmin', {
        'seriesId': seriesId,
        'clubId': clubId,
        'userId': userId,
        'displayName': displayName,
      });

  Future<Map<String, dynamic>> removeSeriesClubAdmin({
    required String seriesId,
    required String clubId,
    required String userId,
  }) =>
      _call('removeSeriesClubAdmin', {
        'seriesId': seriesId,
        'clubId': clubId,
        'userId': userId,
      });

  /// Copies legacy top-level approvals into series/{id}/approvals for list rules.
  Future<Map<String, dynamic>> syncSeriesApprovalMirrors({
    required String seriesId,
  }) =>
      _call('syncSeriesApprovalMirrors', {'seriesId': seriesId}, maxAttempts: 1);

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data, {
    int maxAttempts = 3,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        // Refresh auth after camera/crop activities — stale tokens can surface as UNAVAILABLE.
        await FirebaseAuth.instance.currentUser?.getIdToken(true);
        final callable = _functions.httpsCallable(
          name,
          options: HttpsCallableOptions(timeout: const Duration(seconds: 90)),
        );
        final result = await callable.call(data);
        final value = result.data;
        if (value == null) return <String, dynamic>{};
        if (value is Map) return Map<String, dynamic>.from(value);
        throw StateError('$name returned an invalid response');
      } on FirebaseFunctionsException catch (e) {
        lastError = e;
        final retryable = e.code == 'unavailable' ||
            e.code == 'deadline-exceeded' ||
            e.code == 'resource-exhausted';
        if (!retryable || attempt == maxAttempts) {
          throw FirebaseFunctionsException(
            code: e.code,
            message: _friendlyMessage(e),
            details: e.details,
          );
        }
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
    throw lastError ?? StateError('$name failed');
  }

  String _friendlyMessage(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unavailable':
        return 'Server is warming up. Please try again in a moment.';
      case 'deadline-exceeded':
        return 'Request timed out. Check your connection and try again.';
      case 'unauthenticated':
        return 'Sign in required to continue.';
      case 'permission-denied':
        return e.message ?? 'You do not have permission for this action.';
      case 'invalid-argument':
        return e.message ?? 'Check the form and try again.';
      case 'already-exists':
        return e.message ?? 'This already exists.';
      case 'failed-precondition':
        return e.message ?? 'This action is not available right now.';
      case 'not-found':
        return e.message ?? 'Not found.';
      default:
        return e.message?.trim().isNotEmpty == true
            ? e.message!
            : 'Something went wrong. Try again.';
    }
  }
}
