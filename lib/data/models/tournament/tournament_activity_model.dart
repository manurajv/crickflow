import 'package:equatable/equatable.dart';

enum TournamentActivityType {
  teamRegistered,
  fixtureGenerated,
  matchScheduled,
  sponsorAdded,
  officialAdded,
  groupCreated,
  tournamentUpdated,
}

class TournamentActivityItem extends Equatable {
  const TournamentActivityItem({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.entityId,
  });

  final TournamentActivityType type;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final String? entityId;

  @override
  List<Object?> get props => [type, title, timestamp, entityId];
}
