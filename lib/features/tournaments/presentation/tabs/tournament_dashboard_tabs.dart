import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/utils/venue_maps_utils.dart';
import '../../../../data/models/tournament/tournament_official_model.dart';
import '../../../../data/models/tournament/tournament_rules_model.dart';
import '../../../../data/models/tournament/tournament_sponsor_model.dart';
import '../../../../data/models/tournament_model.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/providers/tournament_providers.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/match_scoring_rules_form.dart';

class TournamentFixturesTab extends ConsumerStatefulWidget {
  const TournamentFixturesTab({
    super.key,
    required this.tournament,
    required this.role,
  });

  final TournamentModel tournament;
  final TournamentRole role;

  @override
  ConsumerState<TournamentFixturesTab> createState() =>
      _TournamentFixturesTabState();
}

class _TournamentFixturesTabState extends ConsumerState<TournamentFixturesTab> {
  var _busy = false;

  Future<void> _generate(Future<List<String>> Function() action, String label) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      final ids = await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label: ${ids.length} matches created')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = ref
        .watch(tournamentPermissionServiceProvider)
        .canManageFixtures(widget.role);
    final repo = ref.read(tournamentRepositoryProvider);
    final uid = ref.read(authStateProvider).value?.uid ?? '';

    return ListView(
      padding: AppDimens.screenPadding,
      children: [
        Text(
          'Generate fixtures automatically or create matches manually from the Matches tab.',
          style: TextStyle(color: context.cf.textSecondary),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        if (canManage) ...[
          CfButton(
            label: 'Round robin (league)',
            isGold: true,
            isLoading: _busy,
            onPressed: _busy
                ? null
                : () => _generate(
                      () => repo.generateLeagueFixtures(
                        tournamentId: widget.tournament.id,
                        createdBy: uid,
                      ),
                      'League fixtures',
                    ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          CfButton(
            label: 'Group stage fixtures',
            isOutlined: true,
            isLoading: _busy,
            onPressed: _busy
                ? null
                : () => _generate(
                      () => repo.generateGroupStageFixtures(
                        tournamentId: widget.tournament.id,
                        createdBy: uid,
                      ),
                      'Group fixtures',
                    ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          CfButton(
            label: 'Knockout bracket',
            isOutlined: true,
            isLoading: _busy,
            onPressed: _busy
                ? null
                : () => _generate(
                      () => repo.generateKnockoutBracket(
                        tournamentId: widget.tournament.id,
                        createdBy: uid,
                      ),
                      'Knockout',
                    ),
          ),
        ] else
          const Center(child: Text('View-only access')),
      ],
    );
  }
}

class TournamentPointsTab extends ConsumerWidget {
  const TournamentPointsTab({super.key, required this.tournament});

  final TournamentModel tournament;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tablesAsync = ref.watch(tournamentPointsTablesProvider(tournament.id));
    final matchesAsync = ref.watch(tournamentMatchesProvider(tournament.id));
    final engine = ref.watch(pointsTableEngineProvider);

    return tablesAsync.when(
      data: (groupTables) {
        if (groupTables.isNotEmpty) {
          return ListView(
            children: groupTables
                .map((table) => _PointsTableSection(
                      title: table.groupName.isEmpty
                          ? 'Points table'
                          : table.groupName,
                      entries: table.entries,
                    ))
                .toList(),
          );
        }

        var entries = tournament.pointsTable;
        final matches = matchesAsync.valueOrNull ?? [];
        if (entries.isNotEmpty && matches.isNotEmpty) {
          entries = engine.rebuildFromMatches(
            seed: entries,
            matches: matches,
            winPts: tournament.defaultRules.pointsPerWin,
            tiePts: tournament.defaultRules.pointsPerTie,
            lossPts: tournament.defaultRules.pointsPerLoss,
            noResultPts: tournament.defaultRules.pointsPerNoResult,
          );
        }

        return _PointsTableSection(
          title: 'Overall standings',
          entries: entries,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }
}

class _PointsTableSection extends StatelessWidget {
  const _PointsTableSection({required this.title, required this.entries});

  final String title;
  final List<PointsTableEntry> entries;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: AppDimens.screenPadding,
          child: const Text('Points table will populate after matches'),
        ),
      );
    }

    return Padding(
      padding: AppDimens.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppDimens.spaceSm),
          Card(
            child: DataTable(
              headingTextStyle: TextStyle(
                color: cf.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              columns: const [
                DataColumn(label: Text('#')),
                DataColumn(label: Text('Team')),
                DataColumn(label: Text('P')),
                DataColumn(label: Text('W')),
                DataColumn(label: Text('L')),
                DataColumn(label: Text('Pts')),
                DataColumn(label: Text('NRR')),
              ],
              rows: entries.map((e) {
                return DataRow(cells: [
                  DataCell(Text('${e.position == 0 ? '—' : e.position}')),
                  DataCell(Text(e.teamName)),
                  DataCell(Text('${e.played}')),
                  DataCell(Text('${e.won}')),
                  DataCell(Text('${e.lost}')),
                  DataCell(Text('${e.points}')),
                  DataCell(Text(e.netRunRate.toStringAsFixed(3))),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class TournamentOfficialsTab extends ConsumerWidget {
  const TournamentOfficialsTab({
    super.key,
    required this.tournamentId,
    required this.role,
  });

  final String tournamentId;
  final TournamentRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final officialsAsync = ref.watch(tournamentOfficialsProvider(tournamentId));
    final canManage =
        ref.watch(tournamentPermissionServiceProvider).canManageOfficials(role);

    return officialsAsync.when(
      data: (list) => ListView(
        padding: AppDimens.screenPadding,
        children: [
          if (canManage)
            CfButton(
              label: 'Add official',
              isGold: true,
              onPressed: () => _addOfficial(context, ref),
            ),
          if (list.isEmpty)
            const Center(child: Text('No officials assigned'))
          else
            ...list.map(
              (o) => ListTile(
                leading: Icon(_roleIcon(o.role)),
                title: Text(o.displayName.isEmpty ? o.userId : o.displayName),
                subtitle: Text('${o.role.name}${o.phone.isNotEmpty ? ' · ${o.phone}' : ''}'),
                trailing: canManage
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => ref
                            .read(tournamentOfficialRepositoryProvider)
                            .removeOfficial(o.id),
                      )
                    : null,
              ),
            ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }

  IconData _roleIcon(TournamentOfficialRole role) => switch (role) {
        TournamentOfficialRole.scorer => Icons.scoreboard,
        TournamentOfficialRole.umpire => Icons.sports,
        TournamentOfficialRole.commentator => Icons.mic,
        TournamentOfficialRole.streamer => Icons.videocam,
        TournamentOfficialRole.photographer => Icons.camera_alt,
        TournamentOfficialRole.videographer => Icons.movie,
      };

  Future<void> _addOfficial(BuildContext context, WidgetRef ref) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    final profile = ref.read(currentUserProfileProvider).valueOrNull;

    await ref.read(tournamentOfficialRepositoryProvider).addOfficial(
          TournamentOfficialModel(
            id: '',
            tournamentId: tournamentId,
            userId: uid,
            role: TournamentOfficialRole.scorer,
            displayName: profile?.displayName ?? '',
          ),
        );
  }
}

class TournamentSponsorsTab extends ConsumerWidget {
  const TournamentSponsorsTab({
    super.key,
    required this.tournamentId,
    required this.role,
  });

  final String tournamentId;
  final TournamentRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sponsorsAsync = ref.watch(tournamentSponsorsProvider(tournamentId));
    final canManage =
        ref.watch(tournamentPermissionServiceProvider).canManageSponsors(role);

    return sponsorsAsync.when(
      data: (list) => ListView(
        padding: AppDimens.screenPadding,
        children: [
          if (canManage)
            CfButton(
              label: 'Add sponsor',
              isGold: true,
              onPressed: () => _addSponsor(context, ref),
            ),
          if (list.isEmpty)
            const Center(child: Text('No sponsors yet'))
          else
            ...list.map(
              (s) => ListTile(
                leading: const Icon(Icons.business, color: AppColors.gold),
                title: Text(s.name),
                subtitle: Text(s.type.name),
                trailing: canManage
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => ref
                            .read(tournamentSponsorRepositoryProvider)
                            .removeSponsor(s.id),
                      )
                    : null,
              ),
            ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }

  Future<void> _addSponsor(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sponsor name'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    await ref.read(tournamentSponsorRepositoryProvider).addSponsor(
          TournamentSponsorModel(
            id: '',
            tournamentId: tournamentId,
            name: name,
            type: SponsorType.associate,
          ),
        );
  }
}

class TournamentRulesTab extends ConsumerStatefulWidget {
  const TournamentRulesTab({
    super.key,
    required this.tournamentId,
    required this.role,
  });

  final String tournamentId;
  final TournamentRole role;

  @override
  ConsumerState<TournamentRulesTab> createState() => _TournamentRulesTabState();
}

class _TournamentRulesTabState extends ConsumerState<TournamentRulesTab> {
  TournamentRulesModel? _draft;
  var _saving = false;

  TournamentRulesModel _effectiveRules(
    TournamentRulesModel rules,
    TournamentModel? tournament,
  ) {
    if (_draft != null) return _draft!;
    if (tournament != null && rules == const TournamentRulesModel()) {
      return tournament.defaultRules;
    }
    return rules;
  }

  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(tournamentRulesProvider(widget.tournamentId));
    final tournament = ref.watch(tournamentProvider(widget.tournamentId)).valueOrNull;
    final canEdit =
        ref.watch(tournamentPermissionServiceProvider).canEditRules(widget.role);

    return rulesAsync.when(
      data: (rules) {
        final r = _effectiveRules(rules, tournament);
        final matchRules = r.toMatchRules();

        return ListView(
          padding: AppDimens.screenPadding,
          children: [
            MatchScoringRulesForm(
              rules: matchRules,
              enabled: canEdit,
              showMatchFormatFields: true,
              onChanged: canEdit
                  ? (next) => setState(
                        () => _draft = r.mergeFromMatchRules(next),
                      )
                  : (_) {},
            ),
            if (canEdit && _draft != null) ...[
              const SizedBox(height: AppDimens.spaceMd),
              CfButton(
                label: 'Save rules',
                isGold: true,
                isLoading: _saving,
                onPressed: _saving ? null : () => _save(_draft!),
              ),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }

  Future<void> _save(TournamentRulesModel rules) async {
    setState(() => _saving = true);
    try {
      await ref.read(tournamentRulesRepositoryProvider).saveRules(
            tournamentId: widget.tournamentId,
            rules: rules,
          );
      final tournament = ref.read(tournamentProvider(widget.tournamentId)).valueOrNull;
      if (tournament != null) {
        await ref.read(tournamentRepositoryProvider).updateTournament(
              tournament.copyWith(defaultRules: rules),
            );
      }
      if (mounted) {
        setState(() => _draft = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rules saved')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class TournamentStatsTab extends ConsumerWidget {
  const TournamentStatsTab({super.key, required this.tournamentId});

  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournament = ref.watch(tournamentProvider(tournamentId)).valueOrNull;
    final matches = ref.watch(tournamentMatchesProvider(tournamentId)).valueOrNull ?? [];
    if (tournament == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final stats = ref.watch(tournamentStatisticsServiceProvider).compute(
          tournament: tournament,
          matches: matches,
        );

    return ListView(
      padding: AppDimens.screenPadding,
      children: [
        _SectionCard(
          title: 'Match summary',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatChip(label: 'Total', value: '${stats.totalMatches}'),
              _StatChip(label: 'Completed', value: '${stats.completedMatches}'),
              _StatChip(label: 'Live', value: '${stats.liveMatches}'),
            ],
          ),
        ),
        _SectionCard(
          title: 'Run aggregate',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(label: 'Total runs', value: '${stats.totalRuns}'),
              _DetailRow(label: 'Total wickets', value: '${stats.totalWickets}'),
              _DetailRow(
                label: 'Highest team score',
                value: '${stats.highestTeamScore}',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TournamentSettingsTab extends ConsumerWidget {
  const TournamentSettingsTab({
    super.key,
    required this.tournament,
    required this.role,
  });

  final TournamentModel tournament;
  final TournamentRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEdit =
        ref.watch(tournamentPermissionServiceProvider).canEditSettings(role);

    return ListView(
      padding: AppDimens.screenPadding,
      children: [
        ListTile(
          leading: const Icon(Icons.edit_outlined),
          title: const Text('Edit tournament'),
          enabled: canEdit,
          onTap: canEdit
              ? () => context.push('/tournaments/${tournament.id}/edit')
              : null,
        ),
        ListTile(
          leading: const Icon(Icons.share_outlined),
          title: const Text('Share & invite'),
          onTap: () {},
        ),
        ListTile(
          leading: const Icon(Icons.admin_panel_settings_outlined),
          title: const Text('Manage access'),
          subtitle: Text('Your role: ${role.name}'),
          enabled: canEdit,
        ),
        if (role == TournamentRole.owner)
          ListTile(
            leading: Icon(Icons.delete_outline, color: context.cf.error),
            title: Text('Delete tournament', style: TextStyle(color: context.cf.error)),
            onTap: () {},
          ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
      color: cf.card,
      child: Padding(
        padding: AppDimens.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppDimens.spaceSm),
            child,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.mapsQuery,
  });

  final String label;
  final String value;
  final String? mapsQuery;

  Future<void> _openMaps(BuildContext context) async {
    final query = mapsQuery?.trim();
    if (query == null || query.isEmpty) return;

    final ok = await openVenueInGoogleMaps(query: query);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final canOpenMaps = mapsQuery != null && mapsQuery!.trim().isNotEmpty;

    final valueStyle = TextStyle(
      color: cf.accent,
      decoration: canOpenMaps ? TextDecoration.underline : null,
      fontWeight: canOpenMaps ? FontWeight.w600 : FontWeight.normal,
    );

    final valueWidget = canOpenMaps
        ? InkWell(
            onTap: () => _openMaps(context),
            child: Text(value, style: valueStyle),
          )
        : Text(value, style: TextStyle(color: cf.textPrimary));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(color: cf.textMuted)),
          ),
          Expanded(child: valueWidget),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cf.sectionBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cf.border),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text(label, style: TextStyle(color: cf.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

extension _PointsFirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
