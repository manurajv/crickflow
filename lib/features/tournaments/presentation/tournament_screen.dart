import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/location_model.dart';
import '../../../data/models/tournament_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../../shared/widgets/location_fields.dart';
import '../../../shared/widgets/location_filter_bar.dart';
import 'widgets/tournament_bracket_widget.dart';

class TournamentScreen extends ConsumerStatefulWidget {
  const TournamentScreen({super.key});

  @override
  ConsumerState<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends ConsumerState<TournamentScreen> {
  String _filterCountry = '';
  String _filterCity = '';

  void _showCreateDialog() {
    final nameController = TextEditingController();
    var format = TournamentFormat.league;
    var location = const LocationModel(country: AppConstants.defaultCountry);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Tournament Name'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<TournamentFormat>(
                  value: format,
                  decoration: const InputDecoration(labelText: 'Format'),
                  items: TournamentFormat.values
                      .map((f) => DropdownMenuItem(
                            value: f,
                            child: Text(f.name),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setModalState(() => format = v);
                  },
                ),
                const SizedBox(height: 16),
                LocationFields(
                  location: location,
                  onChanged: (l) => location = l,
                ),
                const SizedBox(height: 16),
                CfButton(
                  label: 'Create Tournament',
                  isGold: true,
                  onPressed: () async {
                    final uid = ref.read(authStateProvider).value?.uid;
                    final t = TournamentModel(
                      id: const Uuid().v4(),
                      name: nameController.text.trim(),
                      format: format,
                      location: location,
                      createdBy: uid,
                    );
                    await ref
                        .read(tournamentRepositoryProvider)
                        .createTournament(t);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _registerTeamFromList(
    BuildContext context,
    WidgetRef ref,
    TournamentModel tournament,
  ) async {
    final teams = await ref.read(teamsProvider.future);
    if (!context.mounted || teams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a team first')),
      );
      return;
    }

    final picked = await showDialog<dynamic>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select team'),
        children: teams
            .map((team) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, team),
                  child: Text(team.name),
                ))
            .toList(),
      ),
    );
    if (picked == null) return;

    await ref.read(tournamentRepositoryProvider).addTeamToTournament(
          tournamentId: tournament.id,
          teamId: picked.id,
          teamName: picked.name,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${picked.name} registered')),
      );
    }
  }

  Future<void> _generateKnockoutBracket(
    BuildContext context,
    WidgetRef ref,
    TournamentModel tournament,
  ) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    try {
      final ids = await ref.read(tournamentRepositoryProvider).generateKnockoutBracket(
            tournamentId: tournament.id,
            createdBy: uid,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Knockout bracket: ${ids.length} round-1 matches')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Future<void> _generateFixtures(
    BuildContext context,
    WidgetRef ref,
    TournamentModel tournament,
  ) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    try {
      final ids = await ref
          .read(tournamentRepositoryProvider)
          .generateLeagueFixtures(tournamentId: tournament.id, createdBy: uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Created ${ids.length} fixtures')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tournamentsAsync = ref.watch(tournamentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tournaments')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        child: const Icon(Icons.add),
      ),
      body: tournamentsAsync.when(
        data: (list) {
          final filtered = list
              .where((t) =>
                  locationMatchesFilter(t.location, _filterCountry, _filterCity))
              .toList();

          if (list.isEmpty) {
            return const Center(child: Text('No tournaments yet'));
          }

          return Column(
            children: [
              LocationFilterBar(
                initialCountry: _filterCountry,
                initialCity: _filterCity,
                onFilterChanged: (country, city) {
                  setState(() {
                    _filterCountry = country;
                    _filterCity = city;
                  });
                },
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text('No tournaments match this location'),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final t = filtered[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            child: ExpansionTile(
                              leading: const Icon(Icons.emoji_events,
                                  color: AppColors.gold),
                              title: Text(t.name),
                              subtitle: Text(
                                '${t.format.name} • ${t.location.displayLabel}',
                              ),
                              children: [
                                if (t.pointsTable.isEmpty)
                                  const ListTile(
                                    title: Text(
                                        'Points table will populate after matches'),
                                  )
                                else
                                  ...t.pointsTable.map((e) => ListTile(
                                        dense: true,
                                        title: Text(e.teamName),
                                        trailing: Text(
                                          '${e.points} pts • NRR ${e.netRunRate.toStringAsFixed(3)}',
                                        ),
                                      )),
                                ListTile(
                                  title: Text(
                                      '${t.teamIds.length} teams • ${t.matchIds.length} matches'),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.group_add),
                                  title: const Text(
                                      'Register team from my teams'),
                                  onTap: () =>
                                      _registerTeamFromList(context, ref, t),
                                ),
                                if (t.format == TournamentFormat.league ||
                                    t.format == TournamentFormat.leagueKnockout)
                                  ListTile(
                                    leading: const Icon(Icons.calendar_month,
                                        color: AppColors.gold),
                                    title: const Text('Generate league fixtures'),
                                    onTap: () =>
                                        _generateFixtures(context, ref, t),
                                  ),
                                if (t.format == TournamentFormat.knockout ||
                                    t.format == TournamentFormat.leagueKnockout)
                                  ListTile(
                                    leading: const Icon(Icons.account_tree,
                                        color: AppColors.gold),
                                    title: const Text('Generate knockout bracket'),
                                    onTap: () => _generateKnockoutBracket(
                                        context, ref, t),
                                  ),
                                if (t.bracketRounds.isNotEmpty)
                                  TournamentBracketWidget(tournament: t),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
