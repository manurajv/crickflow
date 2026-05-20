import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:crickflow/core/theme/app_dimens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/player_model.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/providers/team_players_provider.dart';
import '../../../../shared/widgets/cf_button.dart';

/// Legacy bottom sheet — prefer [TeamAddPlayersScreen] full-screen flow.
@Deprecated('Use TeamAddPlayersScreen via /teams/:id/add-players')
class AddPlayerSheet extends ConsumerStatefulWidget {
  const AddPlayerSheet({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<AddPlayerSheet> createState() => _AddPlayerSheetState();
}

class _AddPlayerSheetState extends ConsumerState<AddPlayerSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _jerseyController = TextEditingController();

  List<PlayerModel> _results = [];
  Set<String> _squadIds = {};
  bool _searching = false;
  var _newPlayerRole = 'Player';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadSquadIds();
    _search('');
    _searchController.addListener(() => _search(_searchController.text));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchController.dispose();
    _nameController.dispose();
    _jerseyController.dispose();
    super.dispose();
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
      final results = await ref.read(playerRepositoryProvider).searchAvailablePlayers(
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
    await ref.read(playerRepositoryProvider).assignPlayerToTeam(
          playerId: player.id,
          teamId: widget.teamId,
        );
    if (!mounted) return;
    ref.invalidate(teamPlayersProvider(widget.teamId));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${player.name} added to squad')),
    );
  }

  Future<void> _createNew() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

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
    await ref.read(teamRepositoryProvider).addPlayerToTeam(
          teamId: widget.teamId,
          playerId: playerId,
        );

    if (!mounted) return;
    ref.invalidate(teamPlayersProvider(widget.teamId));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name added to squad')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          const Text(
            'Add to squad',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Existing players'),
              Tab(text: 'New player'),
            ],
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            child: TabBarView(
              controller: _tabs,
              children: [
                _existingTab(),
                _newPlayerTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _existingTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Search players',
              prefixIcon: Icon(Icons.search),
              hintText: 'Name…',
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
          child: Text(
            'Pick a registered player profile. Walk-ins without an account can be added under New player.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: _searching
              ? const Center(child: CircularProgressIndicator())
              : _results.isEmpty
                  ? const Center(child: Text('No matching players found'))
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (_, i) {
                        final p = _results[i];
                        final onOtherTeam =
                            p.teamId != null && p.teamId != widget.teamId;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: p.photoUrl != null
                                ? CachedNetworkImageProvider(p.photoUrl!)
                                : null,
                            child: p.photoUrl == null
                                ? Text(
                                    p.name.isNotEmpty
                                        ? p.name[0].toUpperCase()
                                        : '?',
                                  )
                                : null,
                          ),
                          title: Text(p.name),
                          subtitle: Text(
                            [
                              if (p.userId != null) 'Registered account',
                              if (onOtherTeam) 'On another team — will transfer',
                              if (p.role.isNotEmpty) p.role,
                            ].join(' • '),
                          ),
                          trailing: const Icon(Icons.add_circle_outline),
                          onTap: () => _addExisting(p),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _newPlayerTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'For players without a CrickFlow account yet (guest / walk-in).',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Player name *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _jerseyController,
            decoration: const InputDecoration(labelText: 'Jersey number'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _newPlayerRole,
            decoration: const InputDecoration(labelText: 'Role'),
            items: ['Player', 'Captain', 'Wicket Keeper', 'All-rounder']
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _newPlayerRole = v);
            },
          ),
          const SizedBox(height: 20),
          CfButton(label: 'Create & add to squad', onPressed: _createNew),
        ],
      ),
    );
  }
}
