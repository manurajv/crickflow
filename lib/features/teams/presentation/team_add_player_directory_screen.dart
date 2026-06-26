import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../core/utils/cf_player_id_format.dart';
import '../../../data/models/player_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/team_players_provider.dart';

/// Search the player directory by name or Player ID.
class TeamAddPlayerDirectoryScreen extends ConsumerStatefulWidget {
  const TeamAddPlayerDirectoryScreen({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<TeamAddPlayerDirectoryScreen> createState() =>
      _TeamAddPlayerDirectoryScreenState();
}

class _TeamAddPlayerDirectoryScreenState
    extends ConsumerState<TeamAddPlayerDirectoryScreen> {
  final _searchController = TextEditingController();

  Timer? _debounce;
  List<PlayerModel> _results = [];
  Set<String> _squadIds = {};
  bool _searching = false;
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
    if (mounted) {
      setState(() => _squadIds = squad.map((p) => p.id).toSet());
    }
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
      if (!mounted) return;
      ref.invalidate(teamPlayersProvider(widget.teamId));
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
    final cf = context.cf;

    return Scaffold(
      appBar: AppBar(title: const Text('Player directory')),
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
                  'Search the directory',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Find players by name or Player ID (full or partial, e.g. CF000042).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cf.textSecondary,
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
                    color: cf.textSecondary,
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
                      return _PlayerDirectoryTile(
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
    final cf = context.cf;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search_outlined,
              size: 56,
              color: cf.textSecondary.withValues(alpha: 0.5),
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
              'For guests without a CrickFlow account, use Walk-in player from Add players.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cf.textSecondary,
                  ),
            ),
            const SizedBox(height: AppDimens.spaceLg),
            OutlinedButton.icon(
              onPressed: () =>
                  context.push('/teams/${widget.teamId}/add-players/walkin'),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Add walk-in player'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerDirectoryTile extends StatelessWidget {
  const _PlayerDirectoryTile({
    required this.player,
    required this.onAdd,
    this.isAdding = false,
  });

  final PlayerModel player;
  final VoidCallback onAdd;
  final bool isAdding;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
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
        backgroundColor: cf.sectionBackground,
        backgroundImage: player.photoUrl != null
            ? CachedNetworkImageProvider(player.photoUrl!)
            : null,
        child: player.photoUrl == null
            ? Text(
                player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: cf.textPrimary,
                ),
              )
            : null,
      ),
      title: Text(
        player.name,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: cf.textPrimary,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (idLabel != null)
            Text(
              idLabel,
              style: TextStyle(
                color: cf.accent,
                fontSize: 12,
                letterSpacing: 0.3,
              ),
            ),
          Text(
            player.role,
            style: TextStyle(color: cf.textSecondary),
          ),
        ],
      ),
      trailing: isAdding
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cf.accent,
              ),
            )
          : OutlinedButton.icon(
              onPressed: onAdd,
              icon: Icon(Icons.add, size: 16, color: cf.onAccent),
              label: Text(
                'Add',
                style: TextStyle(
                  color: cf.onAccent,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: cf.accent,
                foregroundColor: cf.onAccent,
                side: BorderSide(color: cf.accent),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
    );
  }
}
