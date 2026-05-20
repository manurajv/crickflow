import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/models/team_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/team_ui_provider.dart';
import '../../../shared/widgets/location_filter_bar.dart';
import 'widgets/create_team_form.dart';

/// Teams hub: Your teams · Opponents · Add (reference layout, CrickFlow theme).
class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _searchController = TextEditingController();
  String _query = '';
  String _filterCountry = '';
  String _filterCity = '';

  @override
  void initState() {
    super.initState();
    final tab = widget.initialTab.clamp(0, 2);
    _tabs = TabController(length: 3, vsync: this, initialIndex: tab);
    _tabs.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = ref.read(teamsInitialTabProvider);
      if (pending > 0 && pending < 3) {
        _tabs.animateTo(pending);
        ref.read(teamsInitialTabProvider.notifier).state = 0;
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showSearch() async {
    final controller = TextEditingController(text: _query);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Search teams'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Team name…'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
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
    if (result != null) {
      setState(() => _query = result.trim().toLowerCase());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tabs.index == 2 ? 'Create your team' : 'Teams'),
        actions: [
          if (_tabs.index != 2)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_outlined),
              tooltip: 'Scan team QR',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('QR scan — open a team invite link')),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: _tabs.index == 2 ? null : _showSearch,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.textSecondary,
          dividerColor: AppColors.border,
          tabs: const [
            Tab(text: 'Your teams'),
            Tab(text: 'Opponents'),
            Tab(text: 'Add'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _TeamsListTab(
            yoursOnly: true,
            query: _query,
            filterCountry: _filterCountry,
            filterCity: _filterCity,
            onFilterChanged: (c, city) => setState(() {
              _filterCountry = c;
              _filterCity = city;
            }),
          ),
          _TeamsListTab(
            yoursOnly: false,
            query: _query,
            filterCountry: _filterCountry,
            filterCity: _filterCity,
            onFilterChanged: (c, city) => setState(() {
              _filterCountry = c;
              _filterCity = city;
            }),
          ),
          CreateTeamForm(
            onCreated: (_) => _tabs.animateTo(0),
          ),
        ],
      ),
    );
  }
}

class _TeamsListTab extends ConsumerWidget {
  const _TeamsListTab({
    required this.yoursOnly,
    required this.query,
    required this.filterCountry,
    required this.filterCity,
    required this.onFilterChanged,
  });

  final bool yoursOnly;
  final String query;
  final String filterCountry;
  final String filterCity;
  final void Function(String country, String city) onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(
      yoursOnly ? teamsProvider : allTeamsProvider,
    );
    final uid = ref.watch(authStateProvider).value?.uid;

    return teamsAsync.when(
      data: (teams) {
        var list = teams.where((t) {
          if (!locationMatchesFilter(t.location, filterCountry, filterCity)) {
            return false;
          }
          if (yoursOnly) {
            return uid != null && t.createdBy == uid;
          }
          return uid == null || t.createdBy != uid;
        }).toList();

        if (query.isNotEmpty) {
          list = list
              .where((t) => t.name.toLowerCase().contains(query))
              .toList();
        }

        if (list.isEmpty) {
          return Column(
            children: [
              LocationFilterBar(
                initialCountry: filterCountry,
                initialCity: filterCity,
                onFilterChanged: onFilterChanged,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    yoursOnly ? 'No teams yet — use Add tab' : 'No opponent teams',
                  ),
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            LocationFilterBar(
              initialCountry: filterCountry,
              initialCity: filterCity,
              onFilterChanged: onFilterChanged,
            ),
            Expanded(
              child: ListView.builder(
                padding: AppDimens.listPadding,
                itemCount: list.length,
                itemBuilder: (_, i) => _TeamRow(team: list[i]),
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

class _TeamRow extends StatelessWidget {
  const _TeamRow({required this.team});

  final TeamModel team;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceSm,
        ),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.primaryBlue,
          backgroundImage: team.logoUrl != null
              ? CachedNetworkImageProvider(team.logoUrl!)
              : null,
          child: team.logoUrl == null
              ? Text(
                  team.name.isNotEmpty ? team.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                )
              : null,
        ),
        title: Text(
          team.name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${team.location.displayLabel} · ${team.playerIds.length} players',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/teams/${team.id}'),
      ),
    );
  }
}
