import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/models/team_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/team_ui_provider.dart';
import '../../../shared/widgets/location_filter_bar.dart'; // locationMatchesFilter

/// Pick a team for Team A or Team B during start-match flow.
class SelectTeamForMatchScreen extends ConsumerStatefulWidget {
  const SelectTeamForMatchScreen({
    super.key,
    required this.slotLabel,
    this.opponentsOnly = false,
  });

  final String slotLabel;
  final bool opponentsOnly;

  @override
  ConsumerState<SelectTeamForMatchScreen> createState() =>
      _SelectTeamForMatchScreenState();
}

class _SelectTeamForMatchScreenState extends ConsumerState<SelectTeamForMatchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String _query = '';
  String _country = '';
  String _city = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: widget.opponentsOnly ? 1 : 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).value?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text('Select ${widget.slotLabel}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _searchDialog(),
          ),
        ],
        bottom: widget.opponentsOnly
            ? null
            : TabBar(
                controller: _tabs,
                indicatorColor: AppColors.gold,
                labelColor: AppColors.gold,
                unselectedLabelColor: AppColors.textSecondary,
                tabs: const [
                  Tab(text: 'Your teams'),
                  Tab(text: 'Opponents'),
                  Tab(text: 'Add'),
                ],
              ),
      ),
      body: widget.opponentsOnly
          ? _TeamList(
              yoursOnly: false,
              uid: uid,
              query: _query,
              country: _country,
              city: _city,
              onFilter: (c, city) => setState(() {
                _country = c;
                _city = city;
              }),
              onPick: (t) => context.pop(t),
            )
          : TabBarView(
              controller: _tabs,
              children: [
                _TeamList(
                  yoursOnly: true,
                  uid: uid,
                  query: _query,
                  country: _country,
                  city: _city,
                  onFilter: (c, city) => setState(() {
                    _country = c;
                    _city = city;
                  }),
                  onPick: (t) => context.pop(t),
                ),
                _TeamList(
                  yoursOnly: false,
                  uid: uid,
                  query: _query,
                  country: _country,
                  city: _city,
                  onFilter: (c, city) => setState(() {
                    _country = c;
                    _city = city;
                  }),
                  onPick: (t) => context.pop(t),
                ),
                _AddTeamTab(onCreated: (t) => context.pop(t)),
              ],
            ),
    );
  }

  Future<void> _searchDialog() async {
    final controller = TextEditingController(text: _query);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Search teams'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Team name…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) setState(() => _query = result.trim().toLowerCase());
  }
}

class _TeamList extends ConsumerWidget {
  const _TeamList({
    required this.yoursOnly,
    required this.uid,
    required this.query,
    required this.country,
    required this.city,
    required this.onFilter,
    required this.onPick,
  });

  final bool yoursOnly;
  final String? uid;
  final String query;
  final String country;
  final String city;
  final void Function(String country, String city) onFilter;
  final void Function(TeamModel team) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(
      yoursOnly ? teamsProvider : allTeamsProvider,
    );

    return teamsAsync.when(
      data: (teams) {
        var list = teams.where((t) {
          if (!locationMatchesFilter(t.location, country, city)) return false;
          if (yoursOnly) return uid != null && t.createdBy == uid;
          return uid == null || t.createdBy != uid;
        }).toList();
        if (query.isNotEmpty) {
          list = list
              .where((t) => t.name.toLowerCase().contains(query))
              .toList();
        }

        return Column(
          children: [
            LocationFilterBar(onFilterChanged: onFilter),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('No teams found'))
                  : ListView.builder(
                      padding: AppDimens.listPadding,
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final t = list[i];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primaryBlue,
                              backgroundImage: t.logoUrl != null
                                  ? CachedNetworkImageProvider(t.logoUrl!)
                                  : null,
                              child: t.logoUrl == null
                                  ? Text(
                                      t.name.isNotEmpty ? t.name[0] : '?',
                                    )
                                  : null,
                            ),
                            title: Text(t.name),
                            subtitle: Text(t.location.displayLabel),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => onPick(t),
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
    );
  }
}

class _AddTeamTab extends ConsumerWidget {
  const _AddTeamTab({required this.onCreated});

  final void Function(TeamModel team) onCreated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Create a new team and use it in this match.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimens.spaceLg),
            FilledButton.icon(
              onPressed: () {
                ref.read(teamsInitialTabProvider.notifier).state = 1;
                context.push('/teams?tab=1').then((_) {
                  // User returns manually; they can re-open picker.
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Add team'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
