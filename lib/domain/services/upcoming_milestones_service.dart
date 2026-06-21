import '../../data/models/match_player_snapshot.dart';
import '../../data/models/player_model.dart';
import 'match_upcoming_models.dart';

/// Surfaces career milestones squad players are close to unlocking.
class UpcomingMilestonesService {
  List<UpcomingMilestoneCard> buildFromPlayers(List<PlayerModel> players) {
    final cards = <UpcomingMilestoneCard>[];
    for (final player in players) {
      cards.addAll(_milestonesForPlayer(player));
    }
    cards.sort((a, b) => b.progress.compareTo(a.progress));
    return cards.take(8).toList();
  }

  List<UpcomingMilestoneCard> buildFromSnapshots(
    List<MatchPlayerSnapshot> snapshots,
  ) {
    // Snapshots do not include career stats; use [buildFromPlayers] instead.
    if (snapshots.isEmpty) return const [];
    return const [];
  }

  List<UpcomingMilestoneCard> _milestonesForPlayer(PlayerModel player) =>
      _milestonesForStats(player.name, player.stats);

  List<UpcomingMilestoneCard> _milestonesForStats(
    String name,
    PlayerStatsModel stats,
  ) {
    final cards = <UpcomingMilestoneCard>[];
    void add({
      required String emoji,
      required String title,
      required String description,
      required int current,
      required int target,
    }) {
      if (current >= target) return;
      final remaining = target - current;
      if (remaining > target * 0.15) return;
      cards.add(
        UpcomingMilestoneCard(
          emoji: emoji,
          title: title,
          description: description,
          playerName: name,
          progressLabel: _needsLabel(name, target, current, title),
          progress: current / target,
        ),
      );
    }

    add(
      emoji: '🏏',
      title: 'First 50 Runs',
      description: 'Score your first half-century in limited overs.',
      current: stats.runs,
      target: 50,
    );
    add(
      emoji: '🏏',
      title: 'First Century',
      description: 'Reach 100 career runs in limited overs cricket.',
      current: stats.runs,
      target: 100,
    );
    add(
      emoji: '🔥',
      title: '1000 Career Runs',
      description: 'Join the 1000-run club in limited overs.',
      current: stats.runs,
      target: 1000,
    );
    add(
      emoji: '🎯',
      title: '100 Career Wickets',
      description: 'Take 100 wickets in limited overs cricket.',
      current: stats.wickets,
      target: 100,
    );
    add(
      emoji: '⚡',
      title: 'Fastest Fifty',
      description: 'Score a fifty — high score milestone.',
      current: stats.highScore,
      target: 50,
    );
    add(
      emoji: '🧤',
      title: '50 Catches',
      description: 'Reach 50 fielding dismissals as a catcher.',
      current: stats.catches,
      target: 50,
    );
    add(
      emoji: '4️⃣',
      title: '100 Fours',
      description: 'Hit 100 boundaries in limited overs cricket.',
      current: stats.fours,
      target: 100,
    );
    return cards;
  }

  static String _needsLabel(
    String playerName,
    int target,
    int current,
    String title,
  ) {
    final remaining = target - current;
    final who = playerName.trim().isEmpty ? 'Player' : playerName.trim();
    if (title.contains('Fours')) {
      return '$who needs $remaining 4s';
    }
    if (title.contains('Wickets')) {
      return '$who needs $remaining wickets';
    }
    if (title.contains('Catches')) {
      return '$who needs $remaining catches';
    }
    return '$who needs $remaining runs';
  }
}
