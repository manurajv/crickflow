import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/lineup_player.dart';
import '../../../../data/models/match_player_snapshot.dart';
import '../../../../data/models/player_model.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/lineup_player_avatar.dart';
import '../../../../shared/widgets/scoring_ui_kit.dart';

enum QuickPlayerSource { team, otherRegistered, walkIn }

class QuickMatchPlayerOption {
  const QuickMatchPlayerOption({
    required this.player,
    required this.source,
  });

  final LineupPlayer player;
  final QuickPlayerSource source;

  String get sectionLabel => switch (source) {
        QuickPlayerSource.team => 'Team Players',
        QuickPlayerSource.otherRegistered => 'Other Registered Players',
        QuickPlayerSource.walkIn => 'Walk-in Players',
      };
}

/// Quick Match player picker: team roster, other registered, walk-in + search.
class SelectQuickMatchPlayerSheet extends ConsumerStatefulWidget {
  const SelectQuickMatchPlayerSheet({
    super.key,
    required this.title,
    required this.teamPlayers,
    required this.walkInPlayers,
    required this.scrollController,
    this.excludeIds = const {},
    this.disabledIds = const {},
    this.playerSubtitles = const {},
    this.teamSectionLabel,
    this.prioritizeTeam = true,
  });

  final String title;
  final List<LineupPlayer> teamPlayers;
  final List<LineupPlayer> walkInPlayers;
  final ScrollController scrollController;
  final Set<String> excludeIds;
  final Map<String, String> disabledIds;
  /// Optional per-player subtitle (e.g. bowler overs · runs · wkts).
  final Map<String, String> playerSubtitles;
  /// Section header for [QuickPlayerSource.team] (defaults to "Team Players").
  final String? teamSectionLabel;
  final bool prioritizeTeam;

  static Future<LineupPlayer?> show(
    BuildContext context, {
    required String title,
    required List<LineupPlayer> teamPlayers,
    List<LineupPlayer> walkInPlayers = const [],
    Set<String> excludeIds = const {},
    Map<String, String> disabledIds = const {},
    Map<String, String> playerSubtitles = const {},
    String? teamSectionLabel,
  }) {
    return ScoringUiKit.showDraggableSheet<LineupPlayer>(
      context,
      initialChildSize: 0.72,
      maxChildSize: 0.95,
      builder: (ctx, controller) => SelectQuickMatchPlayerSheet(
        title: title,
        teamPlayers: teamPlayers,
        walkInPlayers: walkInPlayers,
        scrollController: controller,
        excludeIds: excludeIds,
        disabledIds: disabledIds,
        playerSubtitles: playerSubtitles,
        teamSectionLabel: teamSectionLabel,
      ),
    );
  }

  @override
  ConsumerState<SelectQuickMatchPlayerSheet> createState() =>
      _SelectQuickMatchPlayerSheetState();
}

class _SelectQuickMatchPlayerSheetState
    extends ConsumerState<SelectQuickMatchPlayerSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<PlayerModel> _directoryResults = [];
  var _searching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _query = _searchController.text.trim());
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _searchDirectory(_searchController.text);
    });
  }

  Future<void> _searchDirectory(String raw) async {
    final q = raw.trim();
    if (q.length < 2) {
      if (mounted) {
        setState(() {
          _directoryResults = [];
          _searching = false;
        });
      }
      return;
    }
    setState(() => _searching = true);
    try {
      final results = await ref
          .read(playerRepositoryProvider)
          .searchPlayersDirectory(query: q);
      if (!mounted) return;
      setState(() {
        _directoryResults = results;
        _searching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _addWalkIn() async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Walk-in player'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Player name',
            hintText: 'Exists only for this match',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    final snap = MatchPlayerSnapshot.matchOnly(
      name: name,
      playingRole: '',
      battingStyle: '',
      bowlingStyle: '',
    );
    Navigator.pop(
      context,
      LineupPlayer(id: snap.id, name: snap.name),
    );
  }

  bool _matchesQuery(String name) {
    if (_query.isEmpty) return true;
    return name.toLowerCase().contains(_query.toLowerCase());
  }

  List<QuickMatchPlayerOption> _buildOptions() {
    final exclude = widget.excludeIds;
    final teamIds = widget.teamPlayers.map((p) => p.id).toSet();
    final options = <QuickMatchPlayerOption>[];

    for (final p in widget.teamPlayers) {
      if (exclude.contains(p.id)) continue;
      if (!_matchesQuery(p.name)) continue;
      options.add(QuickMatchPlayerOption(
        player: p,
        source: QuickPlayerSource.team,
      ));
    }

    for (final p in widget.walkInPlayers) {
      if (exclude.contains(p.id) || teamIds.contains(p.id)) continue;
      if (!_matchesQuery(p.name)) continue;
      options.add(QuickMatchPlayerOption(
        player: p,
        source: QuickPlayerSource.walkIn,
      ));
    }

    final knownIds = {
      ...teamIds,
      ...widget.walkInPlayers.map((p) => p.id),
      ...exclude,
    };

    for (final p in _directoryResults) {
      if (knownIds.contains(p.id)) continue;
      if (!_matchesQuery(p.name)) continue;
      options.add(QuickMatchPlayerOption(
        player: LineupPlayer.fromPlayer(p),
        source: QuickPlayerSource.otherRegistered,
      ));
    }

    return options;
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final options = _buildOptions();
    final sections = <QuickPlayerSource, List<QuickMatchPlayerOption>>{};
    for (final o in options) {
      sections.putIfAbsent(o.source, () => []).add(o);
    }
    final order = [
      QuickPlayerSource.team,
      QuickPlayerSource.otherRegistered,
      QuickPlayerSource.walkIn,
    ];

    return Material(
      color: cf.surface,
      child: Column(
        children: [
          ScoringSheetHeader(
            title: widget.title,
            trailing: ScoringUiKit.sheetCloseButton(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              0,
              AppDimens.spaceMd,
              AppDimens.spaceSm,
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search players',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addWalkIn,
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                label: const Text('Add walk-in player'),
              ),
            ),
          ),
          Expanded(
            child: options.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimens.spaceMd),
                      child: Text(
                        _query.isEmpty
                            ? 'No team players yet — search registered players or add a walk-in.'
                            : 'No players match your search',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cf.textSecondary),
                      ),
                    ),
                  )
                : ListView(
                    controller: widget.scrollController,
                    padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
                    children: [
                      for (final source in order) ...[
                        if (sections[source]?.isNotEmpty == true) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppDimens.spaceMd,
                              AppDimens.spaceSm,
                              AppDimens.spaceMd,
                              4,
                            ),
                            child: Text(
                              source == QuickPlayerSource.team &&
                                      widget.teamSectionLabel != null
                                  ? widget.teamSectionLabel!
                                  : sections[source]!.first.sectionLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: cf.textMuted,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          for (final opt in sections[source]!)
                            _PlayerTile(
                              option: opt,
                              disabledReason: widget.disabledIds[opt.player.id],
                              subtitleOverride:
                                  widget.playerSubtitles[opt.player.id],
                              onTap: () =>
                                  Navigator.pop(context, opt.player),
                            ),
                        ],
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({
    required this.option,
    required this.onTap,
    this.disabledReason,
    this.subtitleOverride,
  });

  final QuickMatchPlayerOption option;
  final VoidCallback onTap;
  final String? disabledReason;
  final String? subtitleOverride;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final disabled = disabledReason != null;
    return ListTile(
      enabled: !disabled,
      leading: LineupPlayerAvatar(
        name: option.player.name,
        photoUrl: option.player.photoUrl,
        radius: 22,
        backgroundColor: disabled ? cf.surface : cf.sectionBackground,
        foregroundColor: disabled ? cf.textMuted : cf.accent,
      ),
      title: Text(
        option.player.name,
        style: TextStyle(color: disabled ? cf.textMuted : null),
      ),
      subtitle: Text(
        disabledReason ??
            subtitleOverride ??
            switch (option.source) {
              QuickPlayerSource.team => 'Team player',
              QuickPlayerSource.otherRegistered => 'Registered player',
              QuickPlayerSource.walkIn => 'Walk-in · this match only',
            },
        style: TextStyle(fontSize: 12, color: cf.textMuted),
      ),
      onTap: disabled ? null : onTap,
    );
  }
}

/// Builds a match-only guest snapshot from a lineup pick when needed.
MatchPlayerSnapshot snapshotFromLineupPlayer(LineupPlayer player) {
  if (player.id.startsWith('guest_')) {
    return MatchPlayerSnapshot(
      id: player.id,
      name: player.name,
      photoUrl: player.photoUrl,
      isMatchOnlyPlayer: true,
      isRegisteredUser: false,
    );
  }
  return MatchPlayerSnapshot(
    id: player.id.isNotEmpty ? player.id : 'guest_${const Uuid().v4()}',
    name: player.name,
    photoUrl: player.photoUrl,
    isMatchOnlyPlayer: false,
    isRegisteredUser: true,
  );
}
