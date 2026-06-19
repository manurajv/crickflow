import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/cricket_math.dart';
import '../../../../data/models/innings_model.dart';
import '../../../../data/models/lineup_player.dart';
import '../../../../data/models/match_model.dart';
import '../../../../data/models/match_player_snapshot.dart';
import '../../../../data/models/match_rules_model.dart';
import '../../../../shared/widgets/scoring_ui_kit.dart';
import '../utils/scoring_display_utils.dart';
import '../../../../core/theme/cf_colors.dart';

enum BowlerPickMode {
  /// Quick shortcut / replace bowler — current bowler disabled.
  changeBowler,

  /// After over ends — previous over bowler excluded.
  nextOver,
}

enum BowlerIneligibility {
  none,
  currentBowler,
  wicketKeeper,
  bowledLastOver,
  maxOversReached,
}

/// Searchable bowler picker with eligibility rules and live figures.
class ChangeBowlerSheet extends StatefulWidget {
  const ChangeBowlerSheet({
    super.key,
    required this.match,
    required this.innings,
    required this.bowlingSquad,
    required this.overNumber,
    required this.scrollController,
    required this.mode,
    this.excludedBowlerIds = const {},
    this.wicketKeeperId,
  });

  final MatchModel match;
  final InningsModel innings;
  final List<LineupPlayer> bowlingSquad;
  final int overNumber;
  final ScrollController scrollController;
  final BowlerPickMode mode;
  final Set<String> excludedBowlerIds;
  final String? wicketKeeperId;

  static Future<LineupPlayer?> show(
    BuildContext context, {
    required MatchModel match,
    required InningsModel innings,
    required List<LineupPlayer> bowlingSquad,
    required int overNumber,
    BowlerPickMode mode = BowlerPickMode.changeBowler,
    Set<String> excludedBowlerIds = const {},
    String? wicketKeeperId,
  }) {
    debugPrint('Opening bowler selector');
    return ScoringUiKit.showDraggableSheet<LineupPlayer>(
      context,
      initialChildSize: 0.72,
      maxChildSize: 0.92,
      builder: (ctx, controller) => ChangeBowlerSheet(
        match: match,
        innings: innings,
        bowlingSquad: bowlingSquad,
        overNumber: overNumber,
        scrollController: controller,
        mode: mode,
        excludedBowlerIds: excludedBowlerIds,
        wicketKeeperId: wicketKeeperId,
      ),
    );
  }

  static BowlerIneligibility ineligibility({
    required LineupPlayer player,
    required MatchModel match,
    required InningsModel innings,
    required BowlerPickMode mode,
    required Set<String> excludedBowlerIds,
    required String? wicketKeeperId,
  }) {
    if (mode == BowlerPickMode.changeBowler &&
        innings.currentBowlerId == player.id) {
      return BowlerIneligibility.currentBowler;
    }
    if (wicketKeeperId != null &&
        wicketKeeperId.isNotEmpty &&
        player.id == wicketKeeperId) {
      return BowlerIneligibility.wicketKeeper;
    }
    if (mode == BowlerPickMode.nextOver &&
        excludedBowlerIds.contains(player.id)) {
      return BowlerIneligibility.bowledLastOver;
    }
    final stats = ScoringDisplayUtils.bowler(innings, player.id);
    if (stats != null &&
        stats.oversBowledBalls >= match.rules.maxBowlerLegalBalls) {
      return BowlerIneligibility.maxOversReached;
    }
    return BowlerIneligibility.none;
  }

  static String ineligibilityLabel(
    BowlerIneligibility reason,
    MatchRulesModel rules,
  ) {
    return switch (reason) {
      BowlerIneligibility.currentBowler => 'Current bowler',
      BowlerIneligibility.wicketKeeper =>
        '${ScoringDisplayUtils.wicketKeeperCannotBowlReason}. Change wicketkeeper first.',
      BowlerIneligibility.bowledLastOver => 'Bowled last over',
      BowlerIneligibility.maxOversReached =>
        'Maximum overs reached (${rules.oversPerBowler})',
      BowlerIneligibility.none => '',
    };
  }

  static int eligibleCount({
    required List<LineupPlayer> squad,
    required MatchModel match,
    required InningsModel innings,
    required BowlerPickMode mode,
    required Set<String> excludedBowlerIds,
    required String? wicketKeeperId,
  }) {
    return squad
        .where(
          (p) =>
              ineligibility(
                player: p,
                match: match,
                innings: innings,
                mode: mode,
                excludedBowlerIds: excludedBowlerIds,
                wicketKeeperId: wicketKeeperId,
              ) ==
              BowlerIneligibility.none,
        )
        .length;
  }

  @override
  State<ChangeBowlerSheet> createState() => _ChangeBowlerSheetState();
}

class _ChangeBowlerSheetState extends State<ChangeBowlerSheet> {
  String _query = '';

  int get _ballsPerOver => widget.match.rules.ballsPerOver;

  MatchPlayerSnapshot? _snapshotFor(String playerId) {
    final setup = widget.match.setup;
    final inn = widget.innings;
    if (setup == null) return null;
    final isTeamA = inn.bowlingTeamId == widget.match.teamAId;
    return setup.findPlayingSnapshot(isTeamA, playerId);
  }

  List<LineupPlayer> get _filteredSquad {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.bowlingSquad;
    return widget.bowlingSquad
        .where((p) => p.name.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final title = widget.mode == BowlerPickMode.nextOver
        ? 'Select bowler — over ${widget.overNumber}'
        : 'Change bowler';

    return Material(
      color: cf.surface,
      child: Column(
        children: [
          ScoringSheetHeader(
            title: title,
            trailing: ScoringUiKit.sheetCloseButton(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              0,
              AppDimens.spaceMd,
              AppDimens.spaceSm,
            ),
            child: Text(
              '${ScoringDisplayUtils.battingTeamName(widget.match, widget.innings)}: '
              '${widget.innings.totalRuns}/${widget.innings.totalWickets} '
              '(${CricketMath.formatOvers(widget.innings.legalBalls, _ballsPerOver)} ov)',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: cf.textPrimary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              0,
              AppDimens.spaceMd,
              AppDimens.spaceSm,
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search bowlers',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: cf.sectionBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: _filteredSquad.isEmpty
                ? Center(
                    child: Text(
                      'No players found',
                      style: TextStyle(color: cf.textSecondary),
                    ),
                  )
                : ListView.separated(
                    controller: widget.scrollController,
                    padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
                    itemCount: _filteredSquad.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: cf.border),
                    itemBuilder: (_, i) => _BowlerTile(
                      player: _filteredSquad[i],
                      match: widget.match,
                      innings: widget.innings,
                      mode: widget.mode,
                      excludedBowlerIds: widget.excludedBowlerIds,
                      wicketKeeperId: widget.wicketKeeperId,
                      snapshot: _snapshotFor(_filteredSquad[i].id),
                      ballsPerOver: _ballsPerOver,
                      onSelected: (p) {
                        debugPrint('Bowler selected: ${p.name}');
                        Navigator.pop(context, p);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BowlerTile extends StatelessWidget {
  const _BowlerTile({
    required this.player,
    required this.match,
    required this.innings,
    required this.mode,
    required this.excludedBowlerIds,
    required this.wicketKeeperId,
    required this.snapshot,
    required this.ballsPerOver,
    required this.onSelected,
  });

  final LineupPlayer player;
  final MatchModel match;
  final InningsModel innings;
  final BowlerPickMode mode;
  final Set<String> excludedBowlerIds;
  final String? wicketKeeperId;
  final MatchPlayerSnapshot? snapshot;
  final int ballsPerOver;
  final ValueChanged<LineupPlayer> onSelected;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final reason = ChangeBowlerSheet.ineligibility(
      player: player,
      match: match,
      innings: innings,
      mode: mode,
      excludedBowlerIds: excludedBowlerIds,
      wicketKeeperId: wicketKeeperId,
    );
    final disabled = reason != BowlerIneligibility.none;
    final stats = ScoringDisplayUtils.bowler(innings, player.id);
    final overs = stats != null
        ? CricketMath.formatOvers(stats.oversBowledBalls, ballsPerOver)
        : '0.0';
    final runs = stats?.runsConceded ?? 0;
    final wickets = stats?.wickets ?? 0;
    final bowlingStyle = snapshot?.bowlingStyle ?? '';
    final photoUrl = snapshot?.photoUrl;

    return ListTile(
      enabled: !disabled,
      leading: CircleAvatar(
        backgroundColor: disabled
            ? cf.surface
            : cf.sectionBackground,
        backgroundImage:
            photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
        child: photoUrl == null || photoUrl.isEmpty
            ? Text(
                player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: disabled ? cf.textMuted : cf.accent,
                ),
              )
            : null,
      ),
      title: Text(
        player.name,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: disabled ? cf.textMuted : cf.textPrimary,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (disabled)
            Text(
              ChangeBowlerSheet.ineligibilityLabel(reason, match.rules),
              style: TextStyle(
                color: cf.error,
                fontSize: 12,
              ),
            )
          else ...[
            if (bowlingStyle.isNotEmpty)
              Text(
                bowlingStyle,
                style: const TextStyle(fontSize: 12),
              ),
            Text(
              '$overs overs · $runs runs · $wickets wkts',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
      onTap: disabled ? null : () => onSelected(player),
    );
  }
}
