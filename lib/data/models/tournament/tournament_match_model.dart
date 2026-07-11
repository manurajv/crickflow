import '../../../core/constants/enums.dart';
import '../../../domain/scoring/match_lifecycle.dart';
import '../match_model.dart';

/// Tournament-scoped view of a [MatchModel] (persisted in `matches` collection).
class TournamentMatchModel {
  const TournamentMatchModel({required this.match});

  final MatchModel match;

  String get id => match.id;
  String? get tournamentId => match.tournamentId;
  String? get roundId => match.roundId;
  String? get groupId => match.groupId;
  String? get roundName => match.roundName;
  String? get teamAId => match.teamAId;
  String? get teamBId => match.teamBId;
  String get teamAName => match.teamAName;
  String get teamBName => match.teamBName;
  String get venue => match.venue;
  DateTime? get dateTime => match.scheduledAt;
  MatchStatus get status => match.status;
  int get overs => match.rules.totalOvers;
  CricketMatchType get cricketMatchType => match.rules.cricketMatchType;

  bool get isLive => MatchLifecycle.isEffectivelyLive(match);

  bool get isUpcoming => MatchLifecycle.isUpcoming(match);

  bool get isCompleted => match.status == MatchStatus.completed;

  factory TournamentMatchModel.fromMatch(MatchModel match) =>
      TournamentMatchModel(match: match);

  MatchModel toMatch() => match;
}
