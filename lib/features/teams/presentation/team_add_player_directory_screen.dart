import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/cf_player_id_format.dart';
import '../../../data/models/player_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/team_players_provider.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../../shared/widgets/cf_underlined_field.dart';

/// Search directory by name or Player ID; create walk-ins without an account.
class TeamAddPlayerDirectoryScreen extends ConsumerStatefulWidget {
  const TeamAddPlayerDirectoryScreen({
    super.key,
    required this.teamId,
    this.initialTab = 0,
  });

  final String teamId;
  final int initialTab;

  @override
  ConsumerState<TeamAddPlayerDirectoryScreen> createState() =>
      _TeamAddPlayerDirectoryScreenState();
}

class _TeamAddPlayerDirectoryScreenState
    extends ConsumerState<TeamAddPlayerDirectoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _jerseyController = TextEditingController();

  Timer? _debounce;
  List<PlayerModel> _results = [];
  Set<String> _squadIds = {};
  bool _searching = false;
  var _newPlayerRole = 'Player';
  var _creating = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _loadSquadIds();
    _search('');
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabs.dispose();
    _searchController.dispose();
    _nameController.dispose();
    _jerseyController.dispose();
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
    try {
      await ref
          .read(playerRepositoryProvider)
          .assignPlayerToTeam(playerId: player.id, teamId: widget.teamId);
      if (!mounted) return;
      ref.invalidate(teamPlayersProvider(widget.teamId));
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${player.name} added to squad')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not add player: $e')));
      }
    }
  }

  Future<void> _createNew() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Player name is required')));
      return;
    }

    setState(() => _creating = true);
    try {
      final uid = ref.read(authStateProvider).value?.uid;
      final playerId = const Uuid().v4();
      final player = PlayerModel(
        id: playerId,
        name: name,
        teamId: widget.teamId,
        jerseyNumber: int.tryParse(_jerseyController.text.trim()),
        role: _newPlayerRole,
        createdBy: uid,
      );

      await ref.read(playerRepositoryProvider).createPlayer(player);
      await ref
          .read(teamRepositoryProvider)
          .addPlayerToTeam(teamId: widget.teamId, playerId: playerId);

      if (!mounted) return;
      ref.invalidate(teamPlayersProvider(widget.teamId));
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$name added to squad')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not create player: $e')));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Player directory'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Search players'),
            Tab(text: 'Walk-in (no account)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_existingTab(), _newPlayerTab()],
      ),
    );
  }

  Widget _existingTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceMd,
            AppDimens.spaceMd,
            AppDimens.spaceSm,
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name or Player ID (CF000042)',
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
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
          child: Text(
            _results.isEmpty && !_searching
                ? 'No matches — try another name or add a walk-in player.'
                : '${_results.length} player${_results.length == 1 ? '' : 's'} available',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
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
                  itemBuilder: (_, i) => _PlayerDirectoryTile(
                    player: _results[i],
                    onAdd: () => _addExisting(_results[i]),
                  ),
                ),
        ),
      ],
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
              'Registered players appear here. For guests without CrickFlow, use the Walk-in tab.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppDimens.spaceLg),
            OutlinedButton.icon(
              onPressed: () => _tabs.animateTo(1),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Add walk-in player'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _newPlayerTab() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: AppDimens.listPadding,
            children: [
              Text(
                'Walk-in player',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add someone who does not have a CrickFlow account — no login or Player ID needed.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppDimens.spaceLg),
              Card(
                elevation: 0,
                color: AppColors.surfaceElevated,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.spaceMd),
                  child: CfFormFieldGroup(
                    children: [
                      CfUnderlinedField(
                        controller: _nameController,
                        label: 'Player name',
                        required: true,
                      ),
                      CfUnderlinedField(
                        controller: _jerseyController,
                        label: 'Jersey number',
                        keyboardType: TextInputType.number,
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _newPlayerRole,
                        decoration: const InputDecoration(labelText: 'Role'),
                        items:
                            const [
                                  'Player',
                                  'Captain',
                                  'Wicket Keeper',
                                  'All-rounder',
                                ]
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(r),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _newPlayerRole = v);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            child: CfButton(
              label: 'Create & add to squad',
              isLoading: _creating,
              isGold: true,
              onPressed: _creating ? null : _createNew,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlayerDirectoryTile extends StatelessWidget {
  const _PlayerDirectoryTile({required this.player, required this.onAdd});

  final PlayerModel player;
  final VoidCallback onAdd;

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
      trailing: FilledButton.tonalIcon(
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
