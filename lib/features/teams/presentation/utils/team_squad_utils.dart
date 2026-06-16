import '../../../../core/utils/cf_player_id_format.dart';
import '../../../../core/utils/team_leadership_utils.dart';
import '../../../../data/models/player_model.dart';
import '../../../../data/models/team_model.dart';

class TeamSquadUtils {
  TeamSquadUtils._();

  static String squadFullName(PlayerModel player) => player.effectiveFullName;

  static String playerInitials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  static String playerIdDisplay(String? playerId) {
    if (playerId == null || playerId.isEmpty) return '';
    final normalized = CfPlayerIdFormat.normalize(playerId);
    if (normalized.length > 2) {
      return '${normalized.substring(0, 2)}-${normalized.substring(2)}';
    }
    return normalized;
  }

  /// Single-line: `AR • RHB • RAM`
  static String roleLine(PlayerModel player) {
    final parts = <String>[];
    final role = shortRole(player.role);
    if (role.isNotEmpty) parts.add(role);

    final bat = shortBattingStyle(player.battingStyle);
    if (bat.isNotEmpty) parts.add(bat);

    final bowl = shortBowlingStyle(player.bowlingStyle);
    if (bowl.isNotEmpty && bowl != bat) parts.add(bowl);

    return parts.join(' • ');
  }

  static String shortRole(String role) {
    final key = role.trim();
    if (key.isEmpty) return '';
    return _roleShortMap[key] ?? _abbreviateWords(key);
  }

  static String shortBattingStyle(String style) {
    final key = style.trim();
    if (key.isEmpty) return '';
    return _battingShortMap[key] ?? _shortHandBat(key);
  }

  static String shortBowlingStyle(String style) {
    final key = style.trim();
    if (key.isEmpty || key.toLowerCase().contains('do not bowl')) return '';
    return _bowlingShortMap[key] ?? _shortArmBowling(key);
  }

  static String _shortHandBat(String style) {
    final lower = style.toLowerCase();
    if (lower.contains('left')) return 'LHB';
    if (lower.contains('right')) return 'RHB';
    return _abbreviateWords(style);
  }

  static String _shortArmBowling(String style) {
    final lower = style.toLowerCase();
    final arm = lower.contains('left arm')
        ? 'LA'
        : lower.contains('right arm')
            ? 'RA'
            : '';
    if (arm.isEmpty) return _abbreviateWords(style);

    if (lower.contains('medium fast')) return '${arm}MF';
    if (lower.contains('medium')) return '${arm}M';
    if (lower.contains('fast')) return '${arm}F';
    if (lower.contains('off spin')) return '${arm}OS';
    if (lower.contains('leg spin') || lower.contains('leg break')) {
      return '${arm}LS';
    }
    if (lower.contains('googly')) return '${arm}G';
    if (lower.contains('orthodox')) return '${arm}OS';
    if (lower.contains('chinaman') || lower.contains('wrist spin')) {
      return '${arm}WS';
    }
    if (lower.contains('spin')) return '${arm}S';
    return _abbreviateWords(style);
  }

  static String _abbreviateWords(String text) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.map((w) => w[0].toUpperCase()).join();
  }

  static const _roleShortMap = {
    'Batsman': 'Bat',
    'Bowler': 'Bowl',
    'All Rounder': 'AR',
    'Wicket Keeper': 'WK',
    'Wicket Keeper Batter': 'WKB',
    'Bowling All Rounder': 'BAR',
    'Batting All Rounder': 'AR',
  };

  static const _battingShortMap = {
    'Right Hand Batsman': 'RHB',
    'Right Hand Bat': 'RHB',
    'Left Hand Batsman': 'LHB',
    'Left Hand Bat': 'LHB',
  };

  static const _bowlingShortMap = {
    'Right Arm Fast': 'RAF',
    'Left Arm Fast': 'LAF',
    'Right Arm Medium Fast': 'RAMF',
    'Left Arm Medium Fast': 'LAMF',
    'Right Arm Medium': 'RAM',
    'Left Arm Medium': 'LAM',
    'Right Arm Off Spin': 'RAOS',
    'Right Arm Leg Spin': 'RALS',
    'Right Arm Leg Break': 'RALB',
    'Right Arm Googly': 'RAG',
    'Left Arm Orthodox Spin': 'LAOS',
    'Left Arm Chinaman': 'LAC',
    'Left Arm Wrist Spin': 'LAWS',
  };

  static bool isTeamOwner(String? uid, TeamModel team) =>
      TeamLeadershipUtils.isTeamOwner(uid, team);

  static bool isTeamCaptain(String? uid, TeamModel team) =>
      TeamLeadershipUtils.isTeamCaptain(uid, team);

  static bool isTeamViceCaptain(String? uid, TeamModel team) =>
      TeamLeadershipUtils.isTeamViceCaptain(uid, team);

  static bool canManageJoinRequests(String? uid, TeamModel team) =>
      TeamLeadershipUtils.canManageJoinRequests(uid, team);

  static bool isLeadership(String? uid, TeamModel team) =>
      canManageJoinRequests(uid, team);

  static bool canRemoveMember({
    required String? actorUid,
    required TeamModel team,
    required PlayerModel target,
    required List<PlayerModel> squad,
  }) =>
      TeamLeadershipUtils.canRemoveMember(
        actorUid: actorUid,
        team: team,
        target: target,
      );

  static PlayerModel? pickNextOwner(TeamModel team, List<PlayerModel> others) =>
      TeamLeadershipUtils.pickNextOwner(team, others);

  static bool isPlayerOwner(PlayerModel player, TeamModel team) =>
      TeamLeadershipUtils.isPlayerOwner(player, team);

  static bool isCaptain(PlayerModel player, TeamModel team) =>
      team.captainId == player.id;

  static bool isViceCaptain(PlayerModel player, TeamModel team) =>
      team.viceCaptainId == player.id;

  static bool isOnSquad(String? uid, TeamModel team, List<PlayerModel> squad) {
    if (uid == null) return false;
    return team.playerIds.contains(uid) ||
        squad.any((p) => p.id == uid || p.userId == uid);
  }

  static PlayerModel? currentSquadPlayer(String? uid, List<PlayerModel> squad) {
    if (uid == null) return null;
    for (final p in squad) {
      if (p.id == uid || p.userId == uid) return p;
    }
    return null;
  }
}
