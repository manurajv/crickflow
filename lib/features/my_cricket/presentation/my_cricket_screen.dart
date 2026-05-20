import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/match_permissions.dart';
import '../../../shared/providers/my_cricket_ui_provider.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/shell_tab_scaffold.dart';
import 'tabs/my_cricket_highlights_tab.dart';
import 'tabs/my_cricket_matches_tab.dart';
import 'tabs/my_cricket_stats_tab.dart';
import 'tabs/my_cricket_teams_tab.dart';
import 'tabs/my_cricket_tournaments_tab.dart';

/// Unified My Cricket hub: Matches · Tournaments · Teams · Stats (one screen).
class MyCricketScreen extends ConsumerStatefulWidget {
  const MyCricketScreen({super.key});

  @override
  ConsumerState<MyCricketScreen> createState() => _MyCricketScreenState();
}

class _MyCricketScreenState extends ConsumerState<MyCricketScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _tabs.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initial = ref.read(myCricketInitialTabProvider);
      if (initial > 0 && initial < _tabs.length) {
        _tabs.animateTo(initial);
        ref.read(myCricketInitialTabProvider.notifier).state = 0;
      }
    });
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = canCreateMatches(
      ref.watch(currentUserProfileProvider).valueOrNull?.role ??
          UserRole.organizer,
    );

    return ShellTabScaffold(
      title: const Text('My Cricket'),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search',
          onPressed: () => _showSearch(context),
        ),
        if (canCreate)
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New match',
            onPressed: () => context.push('/match/create'),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.textSecondary,
          dividerColor: AppColors.border,
          tabs: const [
            Tab(text: 'Matches'),
            Tab(text: 'Tournaments'),
            Tab(text: 'Teams'),
            Tab(text: 'Stats'),
            Tab(text: 'Highlights'),
          ],
        ),
      ),
      floatingActionButton: canCreate && _tabs.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/match/create'),
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.sports_cricket),
              label: const Text('Start match'),
            )
          : null,
      body: TabBarView(
        controller: _tabs,
        children: const [
          MyCricketMatchesTab(),
          MyCricketTournamentsTab(),
          MyCricketTeamsTab(),
          MyCricketStatsTab(),
          MyCricketHighlightsTab(),
        ],
      ),
    );
  }

  Future<void> _showSearch(BuildContext context) async {
    final current = ref.read(myCricketSearchProvider);
    final controller = TextEditingController(text: current);
    final hints = [
      'Team or match name',
      'Tournament name',
      'Team name',
      'Your stats',
      'Completed matches',
    ];
    final hint = hints[_tabs.index.clamp(0, hints.length - 1)];

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Search'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
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
    if (result != null) {
      ref.read(myCricketSearchProvider.notifier).state = result.trim();
    }
  }
}
