import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../shared/providers/my_cricket_ui_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/providers/team_ui_provider.dart';
import '../../../../shared/widgets/location_filter_bar.dart';

enum _TeamScope { yours, all }

class MyCricketTeamsTab extends ConsumerStatefulWidget {
  const MyCricketTeamsTab({super.key});

  @override
  ConsumerState<MyCricketTeamsTab> createState() => _MyCricketTeamsTabState();
}

class _MyCricketTeamsTabState extends ConsumerState<MyCricketTeamsTab> {
  _TeamScope _scope = _TeamScope.yours;
  String _search = '';
  String _country = '';
  String _city = '';

  @override
  Widget build(BuildContext context) {
    final teamsAsync = ref.watch(
      _scope == _TeamScope.yours ? teamsProvider : allTeamsProvider,
    );
    final search = ref.watch(myCricketSearchProvider);
    final uid = ref.watch(authStateProvider).value?.uid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: AppColors.surfaceElevated,
          child: ListTile(
            dense: true,
            title: const Text('Want to create a new team?'),
            trailing: FilledButton(
              onPressed: () {
                ref.read(teamsInitialTabProvider.notifier).state = 2;
                context.push('/teams?tab=2');
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
              ),
              child: const Text('Create'),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceSm,
            AppDimens.spaceMd,
            0,
          ),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Quick search',
              prefixIcon: Icon(Icons.search, size: 22),
            ),
            onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceSm,
            AppDimens.spaceMd,
            0,
          ),
          child: Row(
            children: [
              _scopeChip('Your teams', _TeamScope.yours),
              const SizedBox(width: AppDimens.spaceXs),
              _scopeChip('All', _TeamScope.all),
            ],
          ),
        ),
        LocationFilterBar(
          onFilterChanged: (c, city) => setState(() {
            _country = c;
            _city = city;
          }),
        ),
        Expanded(
          child: teamsAsync.when(
            data: (all) {
              var list = all.where((t) {
                if (!locationMatchesFilter(t.location, _country, _city)) {
                  return false;
                }
                if (_scope == _TeamScope.yours && uid != null) {
                  return t.createdBy == uid;
                }
                return true;
              }).toList();

              if (search.isNotEmpty) {
                final q = search.toLowerCase();
                list = list.where((t) => t.name.toLowerCase().contains(q)).toList();
              }

              if (list.isEmpty) {
                return const Center(child: Text('No teams found'));
              }

              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final t = list[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceMd,
                      vertical: AppDimens.spaceXs,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primaryBlue,
                        backgroundImage: t.logoUrl != null
                            ? NetworkImage(t.logoUrl!)
                            : null,
                        child: t.logoUrl == null
                            ? Text(t.name.isNotEmpty ? t.name[0] : '?')
                            : null,
                      ),
                      title: Text(t.name),
                      subtitle: Text(
                        '${t.location.displayLabel} · ${t.playerIds.length} players',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/teams/${t.id}'),
                    ),
                  );
                },
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
          ),
        ),
      ],
    );
  }

  Widget _scopeChip(String label, _TeamScope scope) {
    final selected = _scope == scope;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _scope = scope),
      selectedColor: AppColors.primaryBlue.withValues(alpha: 0.35),
      checkmarkColor: AppColors.gold,
    );
  }
}
