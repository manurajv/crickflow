import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/cf_colors.dart';
import '../../data/models/lineup_player.dart';
import '../../features/matches/presentation/widgets/select_lineup_player_sheet.dart';
import '../../features/matches/presentation/widgets/select_quick_match_player_sheet.dart';
import '../../features/scoring/presentation/utils/scoring_display_utils.dart';
import 'scoring_ui_kit.dart';

/// Striker, non-striker, and bowler selection from squad lists.
///
/// Kept for mid-match lineup edits (Change Squad). Opening a new innings uses
/// [StartInningsScreen] for Normal Match. Quick Match uses this picker on the
/// live scoring screen with [quickMatchMode] for expanded player sources.
class PlayerLineupPicker extends StatefulWidget {
  const PlayerLineupPicker({
    super.key,
    required this.battingSquad,
    required this.bowlingSquad,
    this.initialStrikerId,
    this.initialNonStrikerId,
    this.initialBowlerId,
    this.wicketKeeperId,
    this.wicketKeeperCanBowl = true,
    this.quickMatchMode = false,
    this.openingLineup = true,
    this.battingWalkIns = const [],
    this.bowlingWalkIns = const [],
    this.bowlerSubtitles = const {},
    this.battingExcludeIds = const {},
    this.battingTeamSectionLabel,
    this.bowlingTeamSectionLabel,
    required this.onSave,
    this.isLoading = false,
  });

  final List<LineupPlayer> battingSquad;
  final List<LineupPlayer> bowlingSquad;
  final List<LineupPlayer> battingWalkIns;
  final List<LineupPlayer> bowlingWalkIns;
  final Map<String, String> bowlerSubtitles;
  /// Mid-innings: dismissed batters (and similar) must not be re-picked via search.
  final Set<String> battingExcludeIds;
  final String? battingTeamSectionLabel;
  final String? bowlingTeamSectionLabel;
  final String? initialStrikerId;
  final String? initialNonStrikerId;
  final String? initialBowlerId;
  final String? wicketKeeperId;
  final bool wicketKeeperCanBowl;
  final bool quickMatchMode;
  /// When false, vacant crease ends stay empty instead of auto-picking squad[0].
  final bool openingLineup;
  final bool isLoading;
  final void Function({
    required String strikerId,
    required String strikerName,
    required String nonStrikerId,
    required String nonStrikerName,
    required String bowlerId,
    required String bowlerName,
  }) onSave;

  static Future<void> show(
    BuildContext context, {
    required List<LineupPlayer> battingSquad,
    required List<LineupPlayer> bowlingSquad,
    List<LineupPlayer> battingWalkIns = const [],
    List<LineupPlayer> bowlingWalkIns = const [],
    Map<String, String> bowlerSubtitles = const {},
    String? battingTeamSectionLabel,
    String? bowlingTeamSectionLabel,
    String? initialStrikerId,
    String? initialNonStrikerId,
    String? initialBowlerId,
    String? wicketKeeperId,
    bool wicketKeeperCanBowl = true,
    bool quickMatchMode = false,
    bool openingLineup = true,
    Set<String> battingExcludeIds = const {},
    required void Function({
      required String strikerId,
      required String strikerName,
      required String nonStrikerId,
      required String nonStrikerName,
      required String bowlerId,
      required String bowlerName,
    }) onSave,
  }) {
    return ScoringUiKit.showDraggableSheet<void>(
      context,
      initialChildSize: quickMatchMode ? 0.62 : 0.55,
      maxChildSize: 0.85,
      builder: (ctx, _) => PlayerLineupPicker(
        battingSquad: battingSquad,
        bowlingSquad: bowlingSquad,
        battingWalkIns: battingWalkIns,
        bowlingWalkIns: bowlingWalkIns,
        bowlerSubtitles: bowlerSubtitles,
        battingExcludeIds: battingExcludeIds,
        battingTeamSectionLabel: battingTeamSectionLabel,
        bowlingTeamSectionLabel: bowlingTeamSectionLabel,
        initialStrikerId: initialStrikerId,
        initialNonStrikerId: initialNonStrikerId,
        initialBowlerId: initialBowlerId,
        wicketKeeperId: wicketKeeperId,
        wicketKeeperCanBowl: wicketKeeperCanBowl,
        quickMatchMode: quickMatchMode,
        openingLineup: openingLineup,
        onSave: onSave,
      ),
    );
  }

  @override
  State<PlayerLineupPicker> createState() => _PlayerLineupPickerState();
}

class _PlayerLineupPickerState extends State<PlayerLineupPicker> {
  LineupPlayer? _striker;
  LineupPlayer? _nonStriker;
  LineupPlayer? _bowler;

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
  }

  @override
  void didUpdateWidget(PlayerLineupPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.battingSquad != widget.battingSquad ||
        oldWidget.bowlingSquad != widget.bowlingSquad) {
      _syncFromWidget();
    }
  }

  void _syncFromWidget() {
    final opening = widget.openingLineup;
    _striker = _pick(
      widget.battingSquad,
      widget.initialStrikerId,
      opening ? 0 : -1,
    );
    _nonStriker = _pick(
      widget.battingSquad,
      widget.initialNonStrikerId,
      opening ? (_striker == null ? 0 : 1) : -1,
    );
    // Never pre-fill both crease ends with the same batter.
    if (opening &&
        _nonStriker != null &&
        _striker != null &&
        _nonStriker!.id == _striker!.id) {
      _nonStriker = widget.battingSquad
          .where((p) => p.id != _striker!.id)
          .firstOrNull;
    }
    _bowler = _pick(
      widget.bowlingSquad,
      widget.initialBowlerId,
      opening ? 0 : -1,
    );
  }

  LineupPlayer? _pick(List<LineupPlayer> squad, String? id, int fallbackIndex) {
    if (id != null && id.isNotEmpty) {
      return squad.where((p) => p.id == id).firstOrNull;
    }
    if (fallbackIndex >= 0 && squad.length > fallbackIndex) {
      return squad[fallbackIndex];
    }
    return null;
  }

  bool get _strikerLocked =>
      !widget.openingLineup &&
      widget.initialStrikerId != null &&
      widget.initialStrikerId!.isNotEmpty;

  bool get _nonStrikerLocked =>
      !widget.openingLineup &&
      widget.initialNonStrikerId != null &&
      widget.initialNonStrikerId!.isNotEmpty;

  bool get _bowlerLocked =>
      !widget.openingLineup &&
      widget.initialBowlerId != null &&
      widget.initialBowlerId!.isNotEmpty;

  Map<String, String> get _bowlerDisabledIds {
    final keeperId = widget.wicketKeeperId;
    if (widget.wicketKeeperCanBowl) return const {};
    if (keeperId == null || keeperId.isEmpty) return const {};
    return {keeperId: ScoringDisplayUtils.wicketKeeperCannotBowlReason};
  }

  Future<LineupPlayer?> _showPlayerPicker({
    required String title,
    required List<LineupPlayer> squad,
    required List<LineupPlayer> walkIns,
    Set<String> excludeIds = const {},
    Map<String, String> disabledIds = const {},
    Map<String, String> playerSubtitles = const {},
    String? teamSectionLabel,
  }) {
    if (widget.quickMatchMode) {
      return SelectQuickMatchPlayerSheet.show(
        context,
        title: title,
        teamPlayers: squad,
        walkInPlayers: walkIns,
        excludeIds: excludeIds,
        disabledIds: disabledIds,
        playerSubtitles: playerSubtitles,
        teamSectionLabel: teamSectionLabel,
      );
    }
    return SelectLineupPlayerSheet.show(
      context,
      title: title,
      players: squad,
      excludeIds: excludeIds,
      disabledIds: disabledIds,
    );
  }

  Future<void> _pickStriker() async {
    final p = await _showPlayerPicker(
      title: 'Select striker',
      squad: widget.battingSquad,
      walkIns: widget.battingWalkIns,
      excludeIds: {
        ...widget.battingExcludeIds,
        if (_nonStriker != null) _nonStriker!.id,
      },
      teamSectionLabel: widget.battingTeamSectionLabel,
    );
    if (p != null && mounted) setState(() => _striker = p);
  }

  Future<void> _pickNonStriker() async {
    final p = await _showPlayerPicker(
      title: 'Select non-striker',
      squad: widget.battingSquad,
      walkIns: widget.battingWalkIns,
      excludeIds: {
        ...widget.battingExcludeIds,
        if (_striker != null) _striker!.id,
      },
      teamSectionLabel: widget.battingTeamSectionLabel,
    );
    if (p != null && mounted) setState(() => _nonStriker = p);
  }

  Future<void> _pickBowler() async {
    final squad = widget.bowlingSquad.isNotEmpty
        ? widget.bowlingSquad
        : widget.battingSquad;
    final p = await _showPlayerPicker(
      title: 'Select bowler',
      squad: squad,
      walkIns: widget.bowlingWalkIns,
      disabledIds: _bowlerDisabledIds,
      playerSubtitles: widget.bowlerSubtitles,
      teamSectionLabel: widget.bowlingTeamSectionLabel,
    );
    if (p != null && mounted) setState(() => _bowler = p);
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;

    if (widget.isLoading) {
      return Material(
        color: cf.surface,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppDimens.spaceLg),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (widget.battingSquad.isEmpty && !widget.quickMatchMode) {
      return Material(
        color: cf.surface,
        child: Column(
          children: [
            ScoringSheetHeader(
              title: 'Edit lineup',
              trailing: ScoringUiKit.sheetCloseButton(context),
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              child: Text(
                'Add players to teams in Firestore, or link team IDs on this match.',
                style: TextStyle(color: cf.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return Material(
      color: cf.surface,
      child: Column(
        children: [
          ScoringSheetHeader(
            title: widget.quickMatchMode ? 'Select players' : 'Edit lineup',
            trailing: ScoringUiKit.sheetCloseButton(context),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                0,
                AppDimens.spaceMd,
                AppDimens.spaceMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.quickMatchMode)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
                      child: Text(
                        'Choose striker, non-striker and bowler. Search registered players or add walk-ins.',
                        style: TextStyle(fontSize: 13, color: cf.textSecondary),
                      ),
                    ),
                  if (_strikerLocked && _striker != null)
                    _LockedSlotRow(
                      label: 'On strike',
                      player: _striker!,
                      icon: Icons.sports_cricket,
                    )
                  else
                    _SlotRow(
                      label: 'Striker',
                      player: _striker,
                      onTap: _pickStriker,
                      icon: Icons.sports_cricket,
                    ),
                  const SizedBox(height: AppDimens.spaceSm),
                  if (_nonStrikerLocked && _nonStriker != null)
                    _LockedSlotRow(
                      label: 'Non-striker',
                      player: _nonStriker!,
                      icon: Icons.sports_cricket_outlined,
                    )
                  else
                    _SlotRow(
                      label: 'Non-striker',
                      player: _nonStriker,
                      onTap: _pickNonStriker,
                      icon: Icons.sports_cricket_outlined,
                    ),
                  const SizedBox(height: AppDimens.spaceSm),
                  if (_bowlerLocked && _bowler != null)
                    _LockedSlotRow(
                      label: 'Bowler',
                      player: _bowler!,
                      icon: Icons.sports_baseball_outlined,
                    )
                  else
                    _SlotRow(
                      label: 'Bowler',
                      player: _bowler,
                      onTap: _pickBowler,
                      icon: Icons.sports_baseball_outlined,
                    ),
                  const SizedBox(height: AppDimens.spaceLg),
                  FilledButton(
                    onPressed: _striker == null ||
                            _nonStriker == null ||
                            _bowler == null
                        ? null
                        : () {
                            widget.onSave(
                              strikerId: _striker!.id,
                              strikerName: _striker!.name,
                              nonStrikerId: _nonStriker!.id,
                              nonStrikerName: _nonStriker!.name,
                              bowlerId: _bowler!.id,
                              bowlerName: _bowler!.name,
                            );
                          },
                    style: ScoringUiKit.primaryButtonStyle(context).copyWith(
                      minimumSize: const WidgetStatePropertyAll(
                        Size(double.infinity, 48),
                      ),
                    ),
                    child: Text(
                      widget.quickMatchMode ? 'Start scoring' : 'Apply lineup',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.label,
    required this.player,
    required this.onTap,
    required this.icon,
  });

  final String label;
  final LineupPlayer? player;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Material(
      color: cf.card,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cf.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: cf.sectionBackground,
                child: Icon(icon, size: 20, color: cf.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cf.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      player?.name ?? 'Tap to select',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: player != null
                            ? cf.textPrimary
                            : cf.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: cf.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LockedSlotRow extends StatelessWidget {
  const _LockedSlotRow({
    required this.label,
    required this.player,
    required this.icon,
  });

  final String label;
  final LineupPlayer player;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cf.border),
        color: cf.sectionBackground,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: cf.card,
            child: Icon(icon, size: 20, color: cf.textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cf.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  player.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: cf.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.lock_outline, size: 18, color: cf.textMuted),
        ],
      ),
    );
  }
}
