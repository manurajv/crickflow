import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/models/tournament_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/tournament_providers.dart';
import 'tabs/tournament_dashboard_tabs.dart';
import 'widgets/tournament_share_sheet.dart';

class TournamentDashboardScreen extends ConsumerStatefulWidget {
  const TournamentDashboardScreen({super.key, required this.tournamentId});

  final String tournamentId;

  @override
  ConsumerState<TournamentDashboardScreen> createState() =>
      _TournamentDashboardScreenState();
}

class _TournamentDashboardScreenState extends ConsumerState<TournamentDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  static const _labels = [
    'Overview',
    'Teams',
    'Groups',
    'Fixtures',
    'Matches',
    'Points',
    'Officials',
    'Sponsors',
    'Rules',
    'Stats',
    'Settings',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _labels.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final uid = ref.watch(authStateProvider).value?.uid;
    final tournamentAsync = ref.watch(tournamentProvider(widget.tournamentId));
    final role = ref.watch(
      tournamentMemberRoleProvider((widget.tournamentId, uid)),
    );

    return tournamentAsync.when(
      data: (tournament) {
        if (tournament == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Tournament')),
            body: const Center(child: Text('Tournament not found')),
          );
        }

        return Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                expandedHeight: 180,
                pinned: true,
                actions: [
                  IconButton(
                    tooltip: 'Share',
                    icon: const Icon(Icons.share_outlined),
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      builder: (_) => TournamentShareSheet(tournament: tournament),
                    ),
                  ),
                  if (role == TournamentRole.owner ||
                      role == TournamentRole.admin)
                    IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => context.push(
                        '/tournaments/${widget.tournamentId}/edit',
                      ),
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    tournament.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  background: _TournamentHeaderBanner(tournament: tournament),
                ),
                bottom: TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: _labels.map((l) => Tab(text: l)).toList(),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabs,
              children: [
                TournamentOverviewTab(tournament: tournament, role: role),
                TournamentTeamsTab(tournament: tournament, role: role),
                TournamentGroupsTab(tournament: tournament, role: role),
                TournamentFixturesTab(tournament: tournament, role: role),
                TournamentMatchesTab(tournamentId: widget.tournamentId),
                TournamentPointsTab(tournament: tournament),
                TournamentOfficialsTab(tournamentId: widget.tournamentId, role: role),
                TournamentSponsorsTab(tournamentId: widget.tournamentId, role: role),
                TournamentRulesTab(tournamentId: widget.tournamentId, role: role),
                TournamentStatsTab(tournamentId: widget.tournamentId),
                TournamentSettingsTab(tournament: tournament, role: role),
              ],
            ),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Tournament')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Tournament')),
        body: Center(child: Text('$e', style: TextStyle(color: cf.error))),
      ),
    );
  }
}

class _TournamentHeaderBanner extends StatelessWidget {
  const _TournamentHeaderBanner({required this.tournament});

  final TournamentModel tournament;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (tournament.bannerUrl != null)
          CachedNetworkImage(
            imageUrl: tournament.bannerUrl!,
            fit: BoxFit.cover,
          )
        else
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A2744), AppColors.primaryBlue],
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.7),
              ],
            ),
          ),
        ),
        Positioned(
          left: AppDimens.spaceMd,
          bottom: AppDimens.spaceMd,
          child: Row(
            children: [
              if (tournament.logoUrl != null)
                CircleAvatar(
                  radius: 24,
                  backgroundImage: CachedNetworkImageProvider(tournament.logoUrl!),
                )
              else
                const CircleAvatar(
                  radius: 24,
                  child: Icon(Icons.emoji_events, color: AppColors.gold),
                ),
              const SizedBox(width: AppDimens.spaceSm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tournament.location.displayLabel,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  if (tournament.tournamentCode != null)
                    Text(
                      tournament.tournamentCode!,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
