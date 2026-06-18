import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/cf_player_id_format.dart';
import '../../../data/models/player_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/team_players_provider.dart';

/// Add a registered player by name or public Player ID.
class TeamAddPlayerQuickScreen extends ConsumerStatefulWidget {
  const TeamAddPlayerQuickScreen({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<TeamAddPlayerQuickScreen> createState() =>
      _TeamAddPlayerQuickScreenState();
}

class _TeamAddPlayerQuickScreenState
    extends ConsumerState<TeamAddPlayerQuickScreen> {
  final _searchController = TextEditingController();

  Timer? _debounce;
  List<PlayerModel> _results = [];
  Set<String> _squadIds = {};
  var _searching = false;
  String? _addingPlayerId;

  @override
  void initState() {
    super.initState();
    _loadSquadIds();
    _search('');
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search(_searchController.text);
    });
  }

  Future<void> _loadSquadIds() async {
    final squad = await ref
        .read(playerRepositoryProvider)
        .getPlayersByTeam(widget.teamId);
    if (mounted) setState(() => _squadIds = squad.map((p) => p.id).toSet());
  }

  Future<void> _search(String query) async {
    setState(() => _searching = true);
    try {
      final results = await ref
          .read(playerRepositoryProvider)
          .searchAvailablePlayers(
            excludeTeamId: widget.teamId,
            alreadyOnSquadIds: _squadIds,
            query: query,
          );
      if (mounted) setState(() => _results = results);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _addExisting(PlayerModel player) async {
    setState(() => _addingPlayerId = player.id);
    try {
      final uid = ref.read(authStateProvider).value?.uid;
      await ref.read(playerRepositoryProvider).assignPlayerToTeam(
            playerId: player.id,
            teamId: widget.teamId,
            addedByUserId: uid,
          );
      ref.invalidate(teamPlayersProvider(widget.teamId));
      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${player.name} added to squad')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add player: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _addingPlayerId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add registered player')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              AppDimens.spaceMd,
              AppDimens.spaceMd,
              AppDimens.spaceSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Find a registered player',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Search by name or Player ID (full or partial, e.g. CF000042).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: AppDimens.spaceMd),
                TextField(
                  controller: _searchController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Search by name or Player ID',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: _searchController.clear,
                              )
                            : null,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            child: Text(
              _results.isEmpty && !_searching
                  ? 'No matches — try another name or ID.'
                  : '${_results.length} player${_results.length == 1 ? '' : 's'} available',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Expanded(
            child: _results.isEmpty && !_searching
                ? _emptySearchState()
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: AppDimens.spaceLg),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (_, i) {
                      final player = _results[i];
                      return _PlayerSearchTile(
                        player: player,
                        isAdding: _addingPlayerId == player.id,
                        onAdd: () => _addExisting(player),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptySearchState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search_outlined,
              size: 56,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Text(
              _searchController.text.trim().isEmpty
                  ? 'Start typing a name or Player ID'
                  : 'No players match your search',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              'Registered players must have completed onboarding. For guests without CrickFlow, use Player directory → Walk-in.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerSearchTile extends StatelessWidget {
  const _PlayerSearchTile({
    required this.player,
    required this.onAdd,
    this.isAdding = false,
  });

  final PlayerModel player;
  final VoidCallback onAdd;
  final bool isAdding;

  @override
  Widget build(BuildContext context) {
    final idLabel = player.playerId != null && player.playerId!.isNotEmpty
        ? CfPlayerIdFormat.displayLabel(player.playerId)
        : null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceXs,
      ),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: AppColors.surfaceElevated,
        backgroundImage: player.photoUrl != null
            ? CachedNetworkImageProvider(player.photoUrl!)
            : null,
        child: player.photoUrl == null
            ? Text(
                player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                style: const TextStyle(fontWeight: FontWeight.w600),
              )
            : null,
      ),
      title: Text(
        player.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (idLabel != null)
            Text(
              idLabel,
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 12,
                letterSpacing: 0.3,
              ),
            ),
          Text(
            player.role,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
      trailing: isAdding
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : FilledButton.tonalIcon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              style: FilledButton.styleFrom(
                foregroundColor: AppColors.gold,
                visualDensity: VisualDensity.compact,
              ),
            ),
    );
  }
}
