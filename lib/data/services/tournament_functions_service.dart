import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

/// Privileged tournament operations enforced by Cloud Functions.
class TournamentFunctionsService {
  TournamentFunctionsService({FirebaseFunctions? functions})
      : _functions = functions;

  FirebaseFunctions? _functions;

  FirebaseFunctions get _fn => _functions ??= FirebaseFunctions.instanceFor(
        app: Firebase.app(),
        region: 'us-central1',
      );

  /// Adds an existing normal/quick match to [tournamentId] (tournament
  /// owner/admins). Validates teams and existing links server-side and
  /// recalculates standings when the match already has a result.
  Future<bool> linkMatchToTournament({
    required String tournamentId,
    required String matchId,
  }) async {
    final res = await _fn.httpsCallable('linkMatchToTournament').call(
      <String, dynamic>{'tournamentId': tournamentId, 'matchId': matchId},
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    return data['standingsUpdated'] == true;
  }

  /// Registers a match that was created inside the tournament (it already
  /// carries `tournamentId`) in the tournament's match list.
  Future<void> registerTournamentMatch({
    required String tournamentId,
    required String matchId,
  }) async {
    await _fn.httpsCallable('linkMatchToTournament').call(<String, dynamic>{
      'tournamentId': tournamentId,
      'matchId': matchId,
      'mode': 'register',
    });
  }

  /// User-facing text for a callable failure.
  static String messageFor(Object error) {
    if (error is FirebaseFunctionsException) {
      return error.message ?? error.code;
    }
    return error.toString();
  }
}
