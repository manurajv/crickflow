import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/location_model.dart';
import '../../../data/models/team_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../../shared/widgets/location_fields.dart';
import '../../../shared/widgets/location_filter_bar.dart';

class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key});

  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> {
  String _filterCountry = '';
  String _filterCity = '';

  void _showCreateDialog() {
    final nameController = TextEditingController();
    var location = const LocationModel(country: AppConstants.defaultCountry);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Team Name'),
            ),
            const SizedBox(height: 16),
            LocationFields(
              location: location,
              onChanged: (l) => location = l,
            ),
            const SizedBox(height: 16),
            CfButton(
              label: 'Create Team',
              onPressed: () async {
                final uid = ref.read(authStateProvider).value?.uid;
                final team = TeamModel(
                  id: const Uuid().v4(),
                  name: nameController.text.trim(),
                  location: location,
                  createdBy: uid,
                );
                await ref.read(teamRepositoryProvider).createTeam(team);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teamsAsync = ref.watch(teamsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Teams')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        child: const Icon(Icons.add),
      ),
      body: teamsAsync.when(
        data: (teams) {
          final filtered = teams
              .where((t) =>
                  locationMatchesFilter(t.location, _filterCountry, _filterCity))
              .toList();

          if (teams.isEmpty) {
            return const Center(child: Text('No teams yet'));
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
                    ? const Center(child: Text('No teams match this location'))
                    : ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final t = filtered[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(t.name.isNotEmpty ? t.name[0] : '?'),
                  ),
                  title: Text(t.name),
                  subtitle: Text(
                    '${t.location.displayLabel}\n'
                    '${t.stats.matchesPlayed} matches • ${t.stats.matchesWon} wins',
                  ),
                  isThreeLine: true,
                  trailing: Text('${t.playerIds.length} players'),
                  onTap: () => context.push('/teams/${t.id}'),
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
