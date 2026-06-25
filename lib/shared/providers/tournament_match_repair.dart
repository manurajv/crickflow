import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../../data/models/match_model.dart';
import '../../data/models/tournament_match_link.dart';
import 'providers.dart';

final _metadataRepairQueued = <String>{};

/// Resolves tournament link from match doc or parent tournament `matchIds`.
final matchTournamentLinkProvider =
    FutureProvider.family<TournamentMatchLink?, String>((ref, matchId) async {
  final match = ref.watch(matchProvider(matchId)).valueOrNull;
  if (match == null) return null;

  final fromMatch = TournamentMatchLink.fromMatch(match);
  if (fromMatch != null &&
      match.matchType == MatchType.tournament &&
      match.tournamentId != null &&
      match.tournamentId!.isNotEmpty) {
    return fromMatch;
  }

  if (fromMatch != null) return fromMatch;

  return ref
      .read(tournamentRepositoryProvider)
      .resolveTournamentMatchLink(matchId);
});

/// Match snapshot with tournament metadata restored for Info tab and cards.
final matchDisplayProvider =
    Provider.family<MatchModel?, String>((ref, matchId) {
  final match = ref.watch(matchProvider(matchId)).valueOrNull;
  if (match == null) return null;

  final link = ref.watch(matchTournamentLinkProvider(matchId)).valueOrNull;
  if (link == null) return match;
  return link.applyTo(match);
});

bool _obviousTournamentMetadataIssue(MatchModel match) {
  if (match.tournamentId != null &&
      match.tournamentId!.isNotEmpty &&
      match.matchType != MatchType.tournament) {
    return true;
  }
  if (match.tournamentId == null || match.tournamentId!.isEmpty) {
    return match.bracketRound != null ||
        match.groupId?.isNotEmpty == true ||
        match.roundId?.isNotEmpty == true;
  }
  return false;
}

Future<void> repairTournamentMatchMetadataIfNeeded(
  Ref ref,
  MatchModel match, {
  bool allowLookup = true,
}) async {
  TournamentMatchLink? link = TournamentMatchLink.fromMatch(match);
  if (link == null && allowLookup) {
    link = await ref
        .read(tournamentRepositoryProvider)
        .resolveTournamentMatchLink(match.id);
  }
  if (link == null) return;

  final patch = link.patchFor(match);
  if (patch == null || patch.isEmpty) return;
  if (!_metadataRepairQueued.add(match.id)) return;

  try {
    await ref.read(matchRepositoryProvider).patchMatchMetadata(match.id, patch);
  } catch (_) {
    _metadataRepairQueued.remove(match.id);
  }
}

void scheduleTournamentMatchRepairs(
  Ref ref,
  Iterable<MatchModel> matches, {
  bool allowLookup = false,
}) {
  for (final match in matches) {
    if (_obviousTournamentMetadataIssue(match) || allowLookup) {
      Future.microtask(
        () => repairTournamentMatchMetadataIfNeeded(
          ref,
          match,
          allowLookup: allowLookup,
        ),
      );
    }
  }
}
