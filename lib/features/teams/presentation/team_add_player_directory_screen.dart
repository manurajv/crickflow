import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/models/player_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/team_players_provider.dart';
import '../../../shared/widgets/cf_underlined_field.dart';

/// Search directory + create walk-in (full screen, not cramped sheet).
class TeamAddPlayerDirectoryScreen extends ConsumerStatefulWidget {
  const TeamAddPlayerDirectoryScreen({super.key, required this.teamId});

  final String teamId;

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add from directory'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Existing players'),
            Tab(text: 'New player'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _existingTab(),
          _newPlayerTab(),
        ],
      ),
    );
  }

  Widget _existingTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: CfUnderlinedField(
            controller: _searchController,
            label: 'Search players',
            hint: 'Name…',
            prefix: const Icon(Icons.search, color: AppColors.textSecondary),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
          child: Text(
            'Pick a registered profile. Walk-ins without an account go under New player.',
            style: TextStyle(color: AppColors.textSecondary),
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
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.spaceMd,
                            vertical: AppDimens.spaceXs,
                          ),
                          leading: CircleAvatar(
                            radius: 24,
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
                          title: Text(
                            p.name,
                            style: const TextStyle(fontSize: 16),
                          ),
                          subtitle: Text(p.role),
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            color: AppColors.gold,
                            onPressed: () => _addExisting(p),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _newPlayerTab() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimens.spaceLg),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.spaceLg),
                child: CfFormFieldGroup(
                  children: [
                    const Text(
                      'For players without a CrickFlow account (guest / walk-in).',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
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
                      items: const [
                        'Player',
                        'Captain',
                        'Wicket Keeper',
                        'All-rounder',
                      ]
                          .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _newPlayerRole = v);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _createNew,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Create & add to squad'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
