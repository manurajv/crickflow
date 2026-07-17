import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/utils/venue_maps_utils.dart';
import '../../../../data/models/tournament/tournament_rules_model.dart';
import '../../../../data/models/tournament/tournament_sponsor_model.dart';
import '../../../../data/models/tournament/tournament_points_table_model.dart';
import '../../../../data/models/tournament_model.dart';
import '../../../../domain/services/tournament/tournament_hero_ranking_engine.dart';
import '../../../../shared/providers/tournament_analytics_providers.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/providers/tournament_providers.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/match_scoring_rules_form.dart';
import '../widgets/points/tournament_points_table_view.dart';
import '../utils/tournament_display_utils.dart';
import '../widgets/tournament_completion_sheet.dart';
import '../widgets/tournament_delete_sheet.dart';
import '../widgets/tournament_share_sheet.dart';

export 'tournament_fixtures_tab.dart';

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
        final matches = matchesAsync.valueOrNull ?? [];

        if (groupTables.isNotEmpty) {
          // Rebuild group tables from match data so NRR, RF, OF, RA, OB are
          // always correctly calculated (Firestore may have stale values).
          final rebuiltTables = groupTables.map((table) {
            if (table.entries.isEmpty || matches.isEmpty) return table;
            final groupMatches = table.groupId != null
                ? matches.where((m) => m.groupId == table.groupId).toList()
                : matches;
            if (groupMatches.isEmpty) return table;
            final rebuilt = engine.rebuildFromMatches(
              seed: table.entries,
              matches: groupMatches,
              winPts: tournament.defaultRules.pointsPerWin,
              tiePts: tournament.defaultRules.pointsPerTie,
              lossPts: tournament.defaultRules.pointsPerLoss,
              noResultPts: tournament.defaultRules.pointsPerNoResult,
            );
            return TournamentPointsTableModel(
              id: table.id,
              tournamentId: table.tournamentId,
              groupId: table.groupId,
              groupName: table.groupName,
              entries: rebuilt,
              updatedAt: table.updatedAt,
            );
          }).toList();

          return ListView(
            padding: AppDimens.screenPadding,
            children: rebuiltTables
                .map(
                  (table) => TournamentPointsTableView(
                    title: table.groupName.isEmpty
                        ? 'Points table'
                        : table.groupName,
                    entries: table.entries,
                  ),
                )
                .toList(),
          );
        }

        var entries = tournament.pointsTable;
        if (entries.isNotEmpty && matches.isNotEmpty) {
          entries = engine.rebuildFromMatches(
            seed: entries,
            matches: matches,
            winPts: tournament.defaultRules.pointsPerWin,
            tiePts: tournament.defaultRules.pointsPerTie,
            lossPts: tournament.defaultRules.pointsPerLoss,
            noResultPts: tournament.defaultRules.pointsPerNoResult,
          );
        } else if (entries.isEmpty && matches.isNotEmpty) {
          // No seeded table — build entirely from match data.
          final teamIds = <String>{};
          final teamNames = <String, String>{};
          for (final m in matches) {
            if (m.teamAId != null) {
              teamIds.add(m.teamAId!);
              teamNames[m.teamAId!] = m.teamAName;
            }
            if (m.teamBId != null) {
              teamIds.add(m.teamBId!);
              teamNames[m.teamBId!] = m.teamBName;
            }
          }
          final seed = teamIds
              .map((id) => PointsTableEntry(
                    teamId: id,
                    teamName: teamNames[id] ?? id,
                  ))
              .toList();
          entries = engine.rebuildFromMatches(
            seed: seed,
            matches: matches,
            winPts: tournament.defaultRules.pointsPerWin,
            tiePts: tournament.defaultRules.pointsPerTie,
            lossPts: tournament.defaultRules.pointsPerLoss,
            noResultPts: tournament.defaultRules.pointsPerNoResult,
          );
        }

        return ListView(
          padding: AppDimens.screenPadding,
          children: [
            TournamentPointsTableView(
              title: 'Overall standings',
              entries: entries,
              trailing: Text(
                '${entries.length} teams',
                style: TextStyle(
                  color: context.cf.textSecondary,
                  fontSize: 12,
                ),
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
    final cf = context.cf;
    final canEdit =
        ref.watch(tournamentPermissionServiceProvider).canEditSettings(role);
    final isOwner = role == TournamentRole.owner;
    final isCompleted = tournament.status == TournamentStatus.completed;

    return ListView(
      padding: AppDimens.screenPadding,
      children: [
        _SettingsSummaryCard(tournament: tournament),
        if (isCompleted && tournament.championTeamName != null) ...[
          const SizedBox(height: AppDimens.spaceMd),
          _ChampionBanner(
            championName: tournament.championTeamName!,
            runnerUp: tournament.runnerUpTeamName,
          ),
        ],
        const SizedBox(height: AppDimens.spaceLg),
        _SettingsSection(
          title: 'General',
          children: [
            _SettingsTile(
              icon: Icons.edit_outlined,
              iconColor: cf.accent,
              title: 'Edit tournament',
              subtitle: tournament.isLocked
                  ? 'Logo, cover & description'
                  : 'Name, description, logo & cover',
              enabled: canEdit,
              onTap: canEdit
                  ? () => context.push('/tournaments/${tournament.id}/edit')
                  : null,
            ),
            _SettingsTile(
              icon: Icons.share_outlined,
              iconColor: cf.accent,
              title: 'Share & invite',
              subtitle: tournament.tournamentCode != null
                  ? 'Code ${tournament.tournamentCode}'
                  : 'Invite link and tournament code',
              onTap: () => showTournamentShareSheet(
                context,
                tournament: tournament,
              ),
            ),
          ],
        ),
        _SettingsSection(
          title: 'Competition',
          children: [
            _SettingsTile(
              icon: Icons.table_chart_outlined,
              iconColor: cf.accent,
              title: 'Points rules',
              subtitle:
                  'Win ${tournament.defaultRules.pointsPerWin} · '
                  'Tie ${tournament.defaultRules.pointsPerTie} · '
                  'NR ${tournament.defaultRules.pointsPerNoResult}',
              showChevron: false,
            ),
            _SettingsTile(
              icon: Icons.groups_outlined,
              iconColor: cf.accent,
              title: 'Groups & qualification',
              subtitle: 'Configure in the Groups tab',
              showChevron: false,
            ),
          ],
        ),
        _SettingsSection(
          title: 'Access',
          children: [
            _SettingsTile(
              icon: Icons.admin_panel_settings_outlined,
              iconColor: cf.accent,
              title: 'Your access',
              subtitle: tournamentRoleLabel(role),
              showChevron: false,
            ),
          ],
        ),
        if (canEdit && !tournament.isLocked)
          _SettingsSection(
            title: 'Completion',
            children: [
              _SettingsTile(
                icon: Icons.flag_outlined,
                iconColor: cf.accent,
                title: 'Finish tournament',
                subtitle: 'Select champion, awards, and lock editing',
                onTap: () => showTournamentCompletionSheet(
                  context,
                  ref,
                  tournament: tournament,
                ),
              ),
            ],
          ),
        if (isOwner && !tournament.isLocked)
          _SettingsSection(
            title: 'Danger zone',
            children: [
              _SettingsTile(
                icon: Icons.delete_outline,
                iconColor: cf.error,
                title: 'Delete tournament',
                subtitle: 'Removes all data and community posts',
                titleColor: cf.error,
                onTap: () => showTournamentDeleteSheet(
                  context: context,
                  ref: ref,
                  tournament: tournament,
                ),
              ),
            ],
          ),
        const SizedBox(height: AppDimens.spaceXl),
      ],
    );
  }
}

class _SettingsSummaryCard extends StatelessWidget {
  const _SettingsSummaryCard({required this.tournament});

  final TournamentModel tournament;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final status = tournamentStatusLabel(tournament.status);

    return Container(
      padding: AppDimens.cardPadding,
      decoration: BoxDecoration(
        color: cf.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cf.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cf.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: cf.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              if (tournament.isLocked) ...[
                const SizedBox(width: 8),
                Icon(Icons.lock_outline, size: 16, color: cf.textMuted),
              ],
            ],
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            tournament.name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          if (tournament.location.displayLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              tournament.location.displayLabel,
              style: TextStyle(color: cf.textSecondary, fontSize: 13),
            ),
          ],
          const SizedBox(height: AppDimens.spaceMd),
          Row(
            children: [
              _SummaryStat(
                label: 'Teams',
                value: '${tournament.teamIds.length}',
              ),
              const SizedBox(width: AppDimens.spaceMd),
              _SummaryStat(
                label: 'Matches',
                value: '${tournament.matchIds.length}',
              ),
              const SizedBox(width: AppDimens.spaceMd),
              _SummaryStat(
                label: 'Format',
                value: tournamentFormatLabel(tournament.format),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: cf.sectionBackground,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            Text(
              label,
              style: TextStyle(color: cf.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChampionBanner extends StatelessWidget {
  const _ChampionBanner({
    required this.championName,
    this.runnerUp,
  });

  final String championName;
  final String? runnerUp;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Container(
      padding: AppDimens.cardPadding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cf.accent.withValues(alpha: 0.18),
            cf.accent.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cf.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events, color: cf.accent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Champion',
                  style: TextStyle(
                    color: cf.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  championName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                if (runnerUp != null && runnerUp!.isNotEmpty)
                  Text(
                    'Runner-up: $runnerUp',
                    style: TextStyle(color: cf.textSecondary, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.enabled = true,
    this.showChevron = true,
    this.titleColor,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;
  final bool showChevron;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceMd,
            vertical: AppDimens.spaceSm,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: enabled
                            ? (titleColor ?? cf.textPrimary)
                            : cf.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: cf.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (showChevron && enabled && onTap != null)
                Icon(Icons.chevron_right, color: cf.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppDimens.spaceMd, bottom: 4),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) Divider(height: 1, color: context.cf.border),
                children[i],
              ],
            ],
          ),
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
