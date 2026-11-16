import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/grounds/models/managed_ground.dart';
import '../../features/matches/models/managed_match.dart';
import '../../features/teams/models/managed_team.dart';
import '../../features/tournaments/models/managed_tournament.dart';
import '../../features/users/models/managed_user.dart';
import 'related_records.dart';
import 'related_records_repository.dart';

final relatedRecordsRepositoryProvider = Provider<RelatedRecordsRepository>(
  (ref) => RelatedRecordsRepository(),
);

final userRelatedRecordsProvider = FutureProvider.autoDispose
    .family<UserRelatedSnapshot, ManagedUser>((ref, user) {
      return ref.watch(relatedRecordsRepositoryProvider).fetchForUser(user);
    });

final teamRelatedRecordsProvider = FutureProvider.autoDispose
    .family<TeamRelatedSnapshot, ManagedTeam>((ref, team) {
      return ref.watch(relatedRecordsRepositoryProvider).fetchForTeam(team);
    });

final matchRelatedRecordsProvider = FutureProvider.autoDispose
    .family<MatchRelatedSnapshot, ManagedMatch>((ref, match) {
      return ref.watch(relatedRecordsRepositoryProvider).fetchForMatch(match);
    });

final tournamentRelatedRecordsProvider = FutureProvider.autoDispose
    .family<TournamentRelatedSnapshot, ManagedTournament>((ref, tournament) {
      return ref
          .watch(relatedRecordsRepositoryProvider)
          .fetchForTournament(tournament);
    });

final groundRelatedRecordsProvider = FutureProvider.autoDispose
    .family<GroundRelatedSnapshot, ManagedGround>((ref, ground) {
      return ref.watch(relatedRecordsRepositoryProvider).fetchForGround(ground);
    });
