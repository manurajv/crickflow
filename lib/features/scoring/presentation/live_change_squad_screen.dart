import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/match_model.dart';
import '../../../../data/models/match_player_snapshot.dart';
import '../../../../data/models/player_model.dart';
import '../../../../shared/providers/lineup_providers.dart';
import '../../../../shared/providers/providers.dart';
import '../../matches/presentation/widgets/add_match_squad_player_sheet.dart';

enum _SquadSlot { playing, substitute, none }

/// Live squad management — playing XI, substitutes, swap, add players.
class LiveChangeSquadScreen extends ConsumerStatefulWidget {
  const LiveChangeSquadScreen({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<LiveChangeSquadScreen> createState() =>
      _LiveChangeSquadScreenState();
}

class _LiveChangeSquadScreenState extends ConsumerState<LiveChangeSquadScreen> {
  bool _isTeamA = true;
  final _searchController = TextEditingController();
  final List<MatchPlayerSnapshot> _playing = [];
  final List<MatchPlayerSnapshot> _substitutes = [];
  final List<MatchPlayerSnapshot> _localGuests = [];
  String _query = '';
  var _playingExpanded = true;
  var _subsExpanded = true;
  var _loaded = false;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFromMatch());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadFromMatch() {
    final match = ref.read(matchProvider(widget.matchId)).valueOrNull;
    if (match == null) return;
    final setup = match.setup;
    if (setup == null) return;
    setState(() {
      _playing
        ..clear()
        ..addAll(setup.playingPlayersForTeam(_isTeamA));
      _substitutes
        ..clear()
        ..addAll(setup.substitutePlayersForTeam(_isTeamA));
      _localGuests
        ..clear()
        ..addAll([
          ..._playing,
          ..._substitutes,
        ].where((p) => p.isMatchOnlyPlayer));
      _loaded = true;
    });
  }

  void _switchTeam(bool isTeamA) {
    if (_isTeamA == isTeamA) return;
    setState(() {
      _isTeamA = isTeamA;
      _loaded = false;
    });
    _loadFromMatch();
  }

  MatchModel? get _match => ref.read(matchProvider(widget.matchId)).valueOrNull;

  String? get _teamId =>
      _isTeamA ? _match?.teamAId : _match?.teamBId;

  String get _teamName =>
      _isTeamA ? _match?.teamAName ?? 'Team A' : _match?.teamBName ?? 'Team B';

  int get _limit => _match?.rules.playersPerTeam ?? 11;

  _SquadSlot _slotFor(String id) {
    if (_playing.any((p) => p.id == id)) return _SquadSlot.playing;
    if (_substitutes.any((p) => p.id == id)) return _SquadSlot.substitute;
    return _SquadSlot.none;
  }

  void _removeFromSquads(String id) {
    _playing.removeWhere((p) => p.id == id);
    _substitutes.removeWhere((p) => p.id == id);
  }

  Future<void> _persist() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(matchRepositoryProvider).updateMatchSquad(
            matchId: widget.matchId,
            isTeamA: _isTeamA,
            playing: List.unmodifiable(_playing),
            substitutes: List.unmodifiable(_substitutes),
          );
      ref.invalidate(matchLineupSquadsProvider(widget.matchId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmAddAsSubstitute() async {
    final result = await showDialog<bool>(
      context: context,
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
            child: const Text('Add Substitute'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _tryAddPlaying(MatchPlayerSnapshot snapshot) async {
    if (_playing.length >= _limit) {
      final addSub = await _confirmAddAsSubstitute();
      if (!addSub || !mounted) return;
      await _addSubstitute(snapshot);
      return;
    }
    setState(() {
      _removeFromSquads(snapshot.id);
      _playing.add(snapshot);
    });
    await _persist();
  }

  Future<void> _addSubstitute(MatchPlayerSnapshot snapshot) async {
    setState(() {
      _removeFromSquads(snapshot.id);
      _substitutes.add(snapshot);
    });
    await _persist();
  }

  Future<void> _removePlayer(String id) async {
    setState(() => _removeFromSquads(id));
    await _persist();
  }

  Future<void> _swapWithSubstitute(MatchPlayerSnapshot playing) async {
    if (_substitutes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No substitutes available')),
      );
      return;
    }
    final sub = await showModalBottomSheet<MatchPlayerSnapshot>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              child: Text(
                'Swap ${playing.name} with',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ..._substitutes.map(
              (s) => ListTile(
                title: Text(s.name),
                onTap: () => Navigator.pop(ctx, s),
              ),
            ),
          ],
        ),
      ),
    );
    if (sub == null || !mounted) return;
    setState(() {
      _playing.removeWhere((p) => p.id == playing.id);
      _substitutes.removeWhere((p) => p.id == sub.id);
      _playing.add(sub);
      _substitutes.add(playing);
    });
    await _persist();
  }

  Future<void> _swapWithPlaying(MatchPlayerSnapshot substitute) async {
    if (_playing.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No playing players to swap with')),
      );
      return;
    }
    if (_playing.length >= _limit) {
      final sub = await showModalBottomSheet<MatchPlayerSnapshot>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppDimens.spaceMd),
                child: Text(
                  'Swap ${substitute.name} with',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              ..._playing.map(
                (p) => ListTile(
                  title: Text(p.name),
                  onTap: () => Navigator.pop(ctx, p),
                ),
              ),
            ],
          ),
        ),
      );
      if (sub == null || !mounted) return;
      setState(() {
        _playing.removeWhere((p) => p.id == sub.id);
        _substitutes.removeWhere((p) => p.id == substitute.id);
        _playing.add(substitute);
        _substitutes.add(sub);
      });
      await _persist();
    } else {
      setState(() {
        _substitutes.removeWhere((p) => p.id == substitute.id);
        _playing.add(substitute);
      });
      await _persist();
    }
  }

  Future<void> _openAddPlayer() async {
    final teamId = _teamId;
    if (teamId == null) return;
    final guest = await showAddMatchSquadPlayerSheet(context, teamId: teamId);
    if (guest == null || !mounted) return;
    setState(() {
      if (!_localGuests.any((g) => g.id == guest.id)) {
        _localGuests.add(guest);
      }
    });
    await _tryAddPlaying(guest);
  }

  List<_RosterEntry> _buildRoster(List<PlayerModel> players) {
    final entries = <_RosterEntry>[];
    final seen = <String>{};
    for (final guest in _localGuests) {
      if (seen.add(guest.id)) entries.add(_RosterEntry.guest(guest));
    }
    for (final p in players) {
      if (seen.add(p.id)) entries.add(_RosterEntry.team(p));
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final matchAsync = ref.watch(matchProvider(widget.matchId));
    final teamId = _teamId;

    return matchAsync.when(
      data: (match) {
        if (match == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Change Squad')),
            body: const Center(child: Text('Match not found')),
          );
        }
        if (teamId == null || teamId.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Change Squad')),
            body: const Center(child: Text('Team not configured')),
          );
        }
        if (!_loaded) {
          return Scaffold(
            appBar: AppBar(title: const Text('Change Squad')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Change Squad'),
            actions: [
              if (_saving)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: AppDimens.listPadding,
                child: SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: true,
                      label: Text(match.teamAName),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text(match.teamBName),
                    ),
                  ],
                  selected: {_isTeamA},
                  onSelectionChanged: (s) => _switchTeam(s.first),
                ),
              ),
              Padding(
                padding: AppDimens.listPadding,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search roster',
                          prefixIcon: Icon(Icons.search, size: 20),
                        ),
                        onChanged: (v) => setState(() => _query = v.trim()),
                      ),
                    ),
                    const SizedBox(width: AppDimens.spaceSm),
                    FilledButton.icon(
                      onPressed: _openAddPlayer,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<PlayerModel>>(
                  stream: ref
                      .read(playerRepositoryProvider)
                      .watchPlayersForTeam(teamId),
                  builder: (context, snapshot) {
                    final players = snapshot.data ?? [];
                    final roster = _buildRoster(players);
                    final available = roster.where((entry) {
                      if (_slotFor(entry.id) != _SquadSlot.none) return false;
                      if (_query.isEmpty) return true;
                      return entry.name
                          .toLowerCase()
                          .contains(_query.toLowerCase());
                    }).toList();

                    return ListView(
                      padding: AppDimens.listPadding,
                      children: [
                        _SectionHeader(
                          title: 'Playing Squad',
                          count: '${_playing.length} / $_limit',
                          expanded: _playingExpanded,
                          onToggle: () =>
                              setState(() => _playingExpanded = !_playingExpanded),
                        ),
                        if (_playingExpanded)
                          ..._playing.map(
                            (p) => _PlayerTile(
                              snapshot: p,
                              isPlaying: true,
                              onRemove: () => _removePlayer(p.id),
                              onSwap: () => _swapWithSubstitute(p),
                            ),
                          ),
                        const SizedBox(height: AppDimens.spaceMd),
                        _SectionHeader(
                          title: 'Substitute Players',
                          count: _substitutes.isEmpty
                              ? '0 Subs'
                              : '${_substitutes.length} Subs',
                          expanded: _subsExpanded,
                          onToggle: () =>
                              setState(() => _subsExpanded = !_subsExpanded),
                        ),
                        if (_subsExpanded)
                          ..._substitutes.map(
                            (p) => _PlayerTile(
                              snapshot: p,
                              isPlaying: false,
                              onRemove: () => _removePlayer(p.id),
                              onSwap: () => _swapWithPlaying(p),
                            ),
                          ),
                        const SizedBox(height: AppDimens.spaceMd),
                        Text(
                          'Available ($_teamName roster)',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: AppDimens.spaceSm),
                        if (available.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'All roster players are in the match squad',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        else
                          ...available.map(
                            (entry) => ListTile(
                              leading: CircleAvatar(
                                backgroundImage: entry.photoUrl != null
                                    ? CachedNetworkImageProvider(entry.photoUrl!)
                                    : null,
                                child: entry.photoUrl == null
                                    ? Text(entry.name[0].toUpperCase())
                                    : null,
                              ),
                              title: Text(entry.name),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton(
                                    onPressed: () =>
                                        _tryAddPlaying(entry.snapshot),
                                    child: const Text('Playing'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        _addSubstitute(entry.snapshot),
                                    child: const Text('Sub'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Change Squad')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Change Squad')),
        body: Center(child: Text('$e')),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.expanded,
    required this.onToggle,
  });

  final String title;
  final String count;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(count, style: const TextStyle(color: AppColors.gold)),
            Icon(expanded ? Icons.expand_less : Icons.expand_more),
          ],
        ),
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({
    required this.snapshot,
    required this.isPlaying,
    required this.onRemove,
    required this.onSwap,
  });

  final MatchPlayerSnapshot snapshot;
  final bool isPlaying;
  final VoidCallback onRemove;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: snapshot.photoUrl != null
              ? CachedNetworkImageProvider(snapshot.photoUrl!)
              : null,
          child: snapshot.photoUrl == null
              ? Text(snapshot.name[0].toUpperCase())
              : null,
        ),
        title: Text(snapshot.name),
        subtitle: Text(isPlaying ? 'Playing' : 'Substitute'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Swap',
              icon: const Icon(Icons.swap_horiz),
              onPressed: onSwap,
            ),
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.close),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}
