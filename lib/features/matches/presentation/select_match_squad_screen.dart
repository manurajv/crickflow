import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../data/models/match_player_snapshot.dart';
import '../../../data/models/player_model.dart';
import '../../../data/models/team_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/start_match_draft_provider.dart';
import '../../../core/utils/match_setup_navigation.dart';
import 'widgets/add_match_squad_player_sheet.dart';
import '../../../shared/widgets/scoring_ui_kit.dart';
import '../../../shared/widgets/start_match_ui.dart';
import '../../../core/theme/cf_colors.dart';

enum _SquadSlot { playing, substitute, none }

/// Pick playing squad and substitutes for one team before toss.
class SelectMatchSquadScreen extends ConsumerStatefulWidget {
  const SelectMatchSquadScreen({
    super.key,
    required this.teamSlot,
  });

  /// `a` or `b`
  final String teamSlot;

  bool get isTeamA => teamSlot == 'a';

  @override
  ConsumerState<SelectMatchSquadScreen> createState() =>
      _SelectMatchSquadScreenState();
}

class _SelectMatchSquadScreenState extends ConsumerState<SelectMatchSquadScreen> {
  final _searchController = TextEditingController();
  final List<MatchPlayerSnapshot> _playing = [];
  final List<MatchPlayerSnapshot> _substitutes = [];
  final List<MatchPlayerSnapshot> _localGuests = [];
  String _query = '';
  var _playingExpanded = true;
  var _subsExpanded = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final draft = ref.read(startMatchDraftProvider);
      final setup = draft.setup;
      setState(() {
        _playing.addAll(setup.playingPlayersForTeam(widget.isTeamA));
        _substitutes.addAll(setup.substitutePlayersForTeam(widget.isTeamA));
        _localGuests.addAll(
          [
            ...setup.playingPlayersForTeam(widget.isTeamA),
            ...setup.substitutePlayersForTeam(widget.isTeamA),
          ].where((p) => p.isMatchOnlyPlayer),
        );
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  TeamModel? _team(StartMatchDraft draft) =>
      widget.isTeamA ? draft.teamA : draft.teamB;

  String _teamName(StartMatchDraft draft) =>
      widget.isTeamA ? draft.resolvedTeamAName : draft.resolvedTeamBName;

  _SquadSlot _slotFor(String id) {
    if (_playing.any((p) => p.id == id)) return _SquadSlot.playing;
    if (_substitutes.any((p) => p.id == id)) return _SquadSlot.substitute;
    return _SquadSlot.none;
  }

  void _removeFromSquads(String id) {
    _playing.removeWhere((p) => p.id == id);
    _substitutes.removeWhere((p) => p.id == id);
  }

  Future<bool> _confirmAddAsSubstitute() async {
    final result = await ScoringUiKit.showThemedDialog<bool>(
      context,
      builder: (ctx) => AlertDialog(
        title: const Text('Playing Squad is full'),
        content: const Text('Add as substitute?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ScoringUiKit.primaryButtonStyle(ctx),
            child: const Text('Add Substitute'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _tryAddPlaying(MatchPlayerSnapshot snapshot) async {
    final limit = ref.read(startMatchDraftProvider).rules.playersPerTeam;
    if (_playing.length >= limit) {
      final addSub = await _confirmAddAsSubstitute();
      if (!addSub || !mounted) return;
      _addSubstitute(snapshot);
      return;
    }
    setState(() {
      _removeFromSquads(snapshot.id);
      _playing.add(snapshot);
    });
  }

  void _addSubstitute(MatchPlayerSnapshot snapshot) {
    setState(() {
      _removeFromSquads(snapshot.id);
      _substitutes.add(snapshot);
    });
  }

  void _removePlayer(String id) {
    setState(() => _removeFromSquads(id));
  }

  Future<void> _openAddPlayer(String teamId) async {
    final guest = await showAddMatchSquadPlayerSheet(context, teamId: teamId);
    if (guest == null || !mounted) return;
    setState(() {
      if (!_localGuests.any((g) => g.id == guest.id)) {
        _localGuests.add(guest);
      }
    });
    await _tryAddPlaying(guest);
  }

  Future<void> _saveAndNext() async {
    final limit = ref.read(startMatchDraftProvider).rules.playersPerTeam;
    if (_playing.length != limit) {
      final need = limit - _playing.length;
      final msg = need > 0
          ? 'Select exactly $limit playing players ($need more needed).'
          : 'Remove ${_playing.length - limit} player(s) from the playing squad.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    ref.read(startMatchDraftProvider.notifier).setMatchSquad(
          isTeamA: widget.isTeamA,
          playing: List.unmodifiable(_playing),
          substitutes: List.unmodifiable(_substitutes),
        );

    try {
      await persistMatchSetupDraft(ref);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save squad: $e')),
        );
      }
      return;
    }

    if (!mounted) return;
    if (widget.isTeamA) {
      context.push('/match/create/roles/a');
    } else {
      context.push('/match/create/roles/b');
    }
  }

  List<_RosterEntry> _buildRoster(List<PlayerModel> players) {
    final entries = <_RosterEntry>[];
    final seen = <String>{};

    for (final guest in _localGuests) {
      if (seen.add(guest.id)) {
        entries.add(_RosterEntry.guest(guest));
      }
    }
    for (final p in players) {
      if (seen.add(p.id)) {
        entries.add(_RosterEntry.team(p));
      }
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final draft = ref.watch(startMatchDraftProvider);
    final team = _team(draft);
    final teamId = team?.id;
    final limit = draft.rules.playersPerTeam;

    if (teamId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Select squad')),
        body: const Center(child: Text('Select a team first')),
      );
    }

    return Scaffold(
      backgroundColor: cf.background,
      appBar: AppBar(
        title: Text(_teamName(draft)),
      ),
      body: StreamBuilder<List<PlayerModel>>(
        stream: ref.read(playerRepositoryProvider).watchPlayersForTeam(teamId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }

          final players = snapshot.data ?? [];
          final roster = _buildRoster(players);
          final available = roster.where((entry) {
            final id = entry.id;
            if (_slotFor(id) != _SquadSlot.none) return false;
            if (_query.isEmpty) return true;
            return entry.name.toLowerCase().contains(_query.toLowerCase());
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const StartMatchFlowProgress(
                currentIndex: StartMatchFlowStep.squads,
              ),
              Padding(
                padding: AppDimens.listPadding,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Quick search',
                          prefixIcon: Icon(Icons.search, size: 20),
                        ),
                        onChanged: (v) => setState(() => _query = v.trim()),
                      ),
                    ),
                    const SizedBox(width: AppDimens.spaceSm),
                    FilledButton.icon(
                      onPressed: () => _openAddPlayer(teamId),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add player'),
                      style: FilledButton.styleFrom(
                        backgroundColor: cf.accent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: AppDimens.listPadding,
                  children: [
                    _SquadSectionHeader(
                      title: 'PLAYING XI',
                      countLabel: '${_playing.length} / $limit',
                      expanded: _playingExpanded,
                      accentColor: cf.accent,
                      onToggle: () =>
                          setState(() => _playingExpanded = !_playingExpanded),
                    ),
                    if (_playingExpanded) ...[
                      if (_playing.isEmpty)
                        const _EmptySectionHint(
                          text: 'Tap players below to add to the playing squad.',
                        )
                      else
                        ..._playing.map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppDimens.spaceSm,
                            ),
                            child: _SelectedPlayerTile(
                              snapshot: p,
                              slot: _SquadSlot.playing,
                              onRemove: () => _removePlayer(p.id),
                            ),
                          ),
                        ),
                      const SizedBox(height: AppDimens.spaceMd),
                    ],
                    _SquadSectionHeader(
                      title: 'SUBSTITUTE',
                      countLabel: _substitutes.isEmpty
                          ? '0 Subs'
                          : '${_substitutes.length} Sub${_substitutes.length == 1 ? '' : 's'}',
                      expanded: _subsExpanded,
                      accentColor: cf.statusUpcoming,
                      onToggle: () =>
                          setState(() => _subsExpanded = !_subsExpanded),
                    ),
                    if (_subsExpanded) ...[
                      if (_substitutes.isEmpty)
                        const _EmptySectionHint(
                          text: 'Reserve players appear here.',
                        )
                      else
                        ..._substitutes.map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppDimens.spaceSm,
                            ),
                            child: _SelectedPlayerTile(
                              snapshot: p,
                              slot: _SquadSlot.substitute,
                              onRemove: () => _removePlayer(p.id),
                            ),
                          ),
                        ),
                      const SizedBox(height: AppDimens.spaceMd),
                    ],
                    Text(
                      'Available players',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppDimens.spaceSm),
                    if (available.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          roster.isEmpty
                              ? 'No players on this team yet'
                              : 'All players are in the squad',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cf.textSecondary),
                        ),
                      )
                    else
                      ...available.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppDimens.spaceSm,
                          ),
                          child: _AvailablePlayerTile(
                            entry: entry,
                            onAddPlaying: () => _tryAddPlaying(entry.snapshot),
                            onAddSubstitute: () =>
                                _addSubstitute(entry.snapshot),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.spaceMd),
                  child: FilledButton(
                    onPressed: _saveAndNext,
                    style: ScoringUiKit.primaryButtonStyle(context).copyWith(
                      minimumSize: WidgetStateProperty.all(
                        const Size(double.infinity, AppDimens.buttonHeightLarge),
                      ),
                    ),
                    child: Text('Next (${_playing.length}/$limit playing)'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RosterEntry {
  const _RosterEntry._({
    required this.id,
    required this.name,
    required this.snapshot,
    this.photoUrl,
  });

  factory _RosterEntry.team(PlayerModel player) {
    return _RosterEntry._(
      id: player.id,
      name: player.name,
      photoUrl: player.photoUrl,
      snapshot: MatchPlayerSnapshot.fromPlayer(player),
    );
  }

  factory _RosterEntry.guest(MatchPlayerSnapshot guest) {
    return _RosterEntry._(
      id: guest.id,
      name: guest.name,
      photoUrl: guest.photoUrl,
      snapshot: guest,
    );
  }

  final String id;
  final String name;
  final String? photoUrl;
  final MatchPlayerSnapshot snapshot;
}

class _SquadSectionHeader extends StatelessWidget {
  const _SquadSectionHeader({
    required this.title,
    required this.countLabel,
    required this.expanded,
    required this.accentColor,
    required this.onToggle,
  });

  final String title;
  final String countLabel;
  final bool expanded;
  final Color accentColor;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            Text(
              countLabel,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: accentColor,
              ),
            ),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              color: cf.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySectionHint extends StatelessWidget {
  const _EmptySectionHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      child: Text(
        text,
        style: TextStyle(
          color: cf.textSecondary,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _SquadBadge extends StatelessWidget {
  const _SquadBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SelectedPlayerTile extends StatelessWidget {
  const _SelectedPlayerTile({
    required this.snapshot,
    required this.slot,
    required this.onRemove,
  });

  final MatchPlayerSnapshot snapshot;
  final _SquadSlot slot;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final isPlaying = slot == _SquadSlot.playing;
    final accent = isPlaying ? cf.accent : cf.statusUpcoming;

    return Material(
      color: cf.card,
      borderRadius: AppDimens.cardRadius,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppDimens.cardRadius,
          border: Border.all(color: accent, width: 2),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceSm,
        ),
        child: Row(
          children: [
            _PlayerAvatar(name: snapshot.name, photoUrl: snapshot.photoUrl),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    snapshot.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (snapshot.isMatchOnlyPlayer)
                    Text(
                      'Guest',
                      style: TextStyle(
                        fontSize: 11,
                        color: cf.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            _SquadBadge(
              label: isPlaying ? 'PLAYING' : 'SUB',
              color: accent,
            ),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 20),
              tooltip: 'Remove',
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailablePlayerTile extends StatelessWidget {
  const _AvailablePlayerTile({
    required this.entry,
    required this.onAddPlaying,
    required this.onAddSubstitute,
  });

  final _RosterEntry entry;
  final VoidCallback onAddPlaying;
  final VoidCallback onAddSubstitute;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Material(
      color: cf.card,
      borderRadius: AppDimens.cardRadius,
      child: InkWell(
        onTap: onAddPlaying,
        borderRadius: AppDimens.cardRadius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppDimens.cardRadius,
            border: Border.all(color: cf.border),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceMd,
            vertical: AppDimens.spaceSm,
          ),
          child: Row(
            children: [
              _PlayerAvatar(name: entry.name, photoUrl: entry.photoUrl),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Text(
                  entry.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              TextButton(
                onPressed: onAddSubstitute,
                style: TextButton.styleFrom(
                  foregroundColor: cf.statusUpcoming,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('Add as Substitute'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerAvatar extends StatelessWidget {
  const _PlayerAvatar({required this.name, this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return CircleAvatar(
      radius: 24,
      backgroundColor: cf.sectionBackground,
      backgroundImage:
          photoUrl != null ? CachedNetworkImageProvider(photoUrl!) : null,
      child: photoUrl == null
          ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
          : null,
    );
  }
}
