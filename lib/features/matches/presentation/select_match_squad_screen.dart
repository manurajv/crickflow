import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/models/player_model.dart';
import '../../../data/models/team_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/start_match_draft_provider.dart';

/// Pick playing squad for one team before toss (reference: Select squad).
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
  final Set<String> _selected = {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final draft = ref.read(startMatchDraftProvider);
      final ids = widget.isTeamA
          ? draft.setup.teamASquadIds
          : draft.setup.teamBSquadIds;
      setState(() => _selected.addAll(ids));
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

  void _toggleAll(List<PlayerModel> players) {
    setState(() {
      if (_selected.length == players.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(players.map((p) => p.id));
      }
    });
  }

  void _saveAndNext(List<PlayerModel> players) {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one player')),
      );
      return;
    }
    final names = <String, String>{
      for (final p in players)
        if (_selected.contains(p.id)) p.id: p.name,
    };
    ref.read(startMatchDraftProvider.notifier).setSquad(
          isTeamA: widget.isTeamA,
          playerIds: _selected.toList(),
          playerNames: names,
        );

    if (widget.isTeamA) {
      context.push('/match/create/roles/a');
    } else {
      context.push('/match/create/roles/b');
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(startMatchDraftProvider);
    final team = _team(draft);
    final teamId = team?.id;

    if (teamId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Select squad')),
        body: const Center(child: Text('Select a team first')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
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
          final filtered = players
              .where(
                (p) =>
                    _query.isEmpty ||
                    p.name.toLowerCase().contains(_query.toLowerCase()),
              )
              .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: AppDimens.listPadding,
                child: Row(
                  children: [
                    Text(
                      'Select squad (${_selected.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: players.isEmpty
                          ? null
                          : () => _toggleAll(players),
                      child: Text(
                        _selected.length == players.length
                            ? 'Clear all'
                            : 'Select all',
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
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
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Add players from team profile'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add player'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.spaceSm),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          players.isEmpty
                              ? 'No players on this team yet'
                              : 'No matches for search',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: AppDimens.listPadding,
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppDimens.spaceSm),
                        itemBuilder: (_, i) {
                          final p = filtered[i];
                          final selected = _selected.contains(p.id);
                          return _SquadTile(
                            player: p,
                            selected: selected,
                            onTap: () {
                              setState(() {
                                if (selected) {
                                  _selected.remove(p.id);
                                } else {
                                  _selected.add(p.id);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.spaceMd),
                  child: FilledButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => _saveAndNext(players),
                    style: FilledButton.styleFrom(
                      minimumSize:
                          const Size(double.infinity, AppDimens.buttonHeightLarge),
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Next'),
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

class _SquadTile extends StatelessWidget {
  const _SquadTile({
    required this.player,
    required this.selected,
    required this.onTap,
  });

  final PlayerModel player;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: AppDimens.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppDimens.cardRadius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppDimens.cardRadius,
            border: Border.all(
              color: selected ? AppColors.gold : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceMd,
            vertical: AppDimens.spaceSm,
          ),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.surfaceElevated,
                    backgroundImage: player.photoUrl != null
                        ? CachedNetworkImageProvider(player.photoUrl!)
                        : null,
                    child: player.photoUrl == null
                        ? Text(
                            player.name.isNotEmpty
                                ? player.name[0].toUpperCase()
                                : '?',
                          )
                        : null,
                  ),
                  if (selected)
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white),
                    ),
                ],
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Text(
                  player.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
