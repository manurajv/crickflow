import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/enums.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../core/utils/date_utils.dart';
import '../../../../../core/utils/tournament_match_stage_utils.dart';
import '../../../../../data/models/match_model.dart';
import '../../../../../shared/providers/tournament_match_providers.dart';
import '../../../../../shared/providers/tournament_providers.dart';
import '../../../../../shared/widgets/match_card_ui.dart';

/// Read-only fixture schedule grouped by league, group stage, and knockout.
class TournamentFixturesSchedule extends ConsumerWidget {
  const TournamentFixturesSchedule({
    super.key,
    required this.tournamentId,
    required this.matches,
    this.showKnockoutSection = true,
  });

  final String tournamentId;
  final List<MatchModel> matches;
  final bool showKnockoutSection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (matches.isEmpty) return const SizedBox.shrink();

    final sections = _buildSections(ref, matches);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: AppDimens.spaceLg),
          _FixtureSectionView(
            section: sections[i],
            tournamentId: tournamentId,
          ),
        ],
      ],
    );
  }

  List<_FixtureSection> _buildSections(WidgetRef ref, List<MatchModel> all) {
    final sections = <_FixtureSection>[];
    final tournamentFormat =
        ref.watch(tournamentProvider(tournamentId)).valueOrNull?.format;

    int compareSchedule(MatchModel a, MatchModel b) {
      final ad = a.scheduledAt ?? DateTime(0);
      final bd = b.scheduledAt ?? DateTime(0);
      final byDate = ad.compareTo(bd);
      if (byDate != 0) return byDate;
      return a.title.compareTo(b.title);
    }

    bool isKnockoutMatch(MatchModel m) {
      if (m.bracketRound != null) return true;
      if (!_isBlank(m.groupId)) return false;
      if (m.roundId != null && m.roundId!.isNotEmpty) {
        final round = ref.watch(
          tournamentRoundByIdProvider(
            (tournamentId: tournamentId, roundId: m.roundId),
          ),
        );
        if (round != null && isKnockoutRoundType(round.roundType)) {
          return true;
        }
      }
      return tournamentFormat == TournamentFormat.knockout;
    }

    final league = all
        .where((m) => !isKnockoutMatch(m) && _isBlank(m.groupId))
        .toList()
      ..sort(compareSchedule);
    if (league.isNotEmpty) {
      sections.add(
        _FixtureSection(
          title: 'Round robin',
          subtitle: '${league.length} fixtures',
          matches: league,
        ),
      );
    }

    final groupMatches = all
        .where((m) => m.bracketRound == null && !_isBlank(m.groupId))
        .toList();
    if (groupMatches.isNotEmpty) {
      final byGroup = <String, List<MatchModel>>{};
      for (final m in groupMatches) {
        byGroup.putIfAbsent(m.groupId!, () => []).add(m);
      }
      final groupIds = byGroup.keys.toList()..sort();
      for (final groupId in groupIds) {
        final list = byGroup[groupId]!..sort(compareSchedule);
        final group = ref.watch(tournamentGroupByIdProvider(
          (tournamentId: tournamentId, groupId: groupId),
        ));
        final name = group?.name ??
            list.first.roundName ??
            'Group';
        sections.add(
          _FixtureSection(
            title: name,
            subtitle: '${list.length} fixtures · Group stage',
            matches: list,
          ),
        );
      }
    }

    if (showKnockoutSection) {
      final knockout = all.where(isKnockoutMatch).toList()
        ..sort((a, b) {
          final round = (a.bracketRound ?? 0).compareTo(b.bracketRound ?? 0);
          if (round != 0) return round;
          return (a.bracketSlot ?? 0).compareTo(b.bracketSlot ?? 0);
        });
      if (knockout.isNotEmpty) {
        sections.add(
          _FixtureSection(
            title: 'Knockout fixtures',
            subtitle: '${knockout.length} matches',
            matches: knockout,
          ),
        );
      }
    }

    return sections;
  }

  bool _isBlank(String? value) => value == null || value.isEmpty;
}

class _FixtureSection {
  const _FixtureSection({
    required this.title,
    required this.matches,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<MatchModel> matches;
}

class _FixtureSectionView extends StatelessWidget {
  const _FixtureSectionView({
    required this.section,
    required this.tournamentId,
  });

  final _FixtureSection section;
  final String tournamentId;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                section.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            if (section.subtitle != null)
              Text(
                section.subtitle!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cf.textMuted,
                    ),
              ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceSm),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: cf.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < section.matches.length; i++) ...[
                if (i > 0) Divider(height: 1, color: cf.border),
                _FixtureRow(
                  match: section.matches[i],
                  index: i + 1,
                  tournamentId: tournamentId,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FixtureRow extends ConsumerWidget {
  const _FixtureRow({
    required this.match,
    required this.index,
    required this.tournamentId,
  });

  final MatchModel match;
  final int index;
  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final statusUi = matchStatusUi(match, cf);
    final round = match.roundId != null && match.roundId!.isNotEmpty
        ? ref.watch(
            tournamentRoundByIdProvider(
              (tournamentId: tournamentId, roundId: match.roundId),
            ),
          )
        : null;
    final tournamentFormat =
        ref.watch(tournamentProvider(tournamentId)).valueOrNull?.format;
    final stage = tournamentMatchStageLabel(
      match,
      roundName: match.roundName ?? round?.name,
      roundType: round?.roundType,
      tournamentFormat: tournamentFormat,
    );
    final displayAt = matchCardPrimaryDate(match);
    final scheduleText = displayAt != null
        ? AppDateUtils.formatCardSchedule(displayAt)
        : 'Date TBD';

    return Material(
      color: cf.card,
      child: InkWell(
        onTap: () => context.push('/match/${match.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceMd,
            vertical: 12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '$index',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: cf.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${match.teamAName} vs ${match.teamBName}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scheduleText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cf.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stage,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: cf.textMuted,
                          ),
                    ),
                  ],
                ),
              ),
              MatchStatusChip(
                label: statusUi.label,
                color: statusUi.color,
                showLivePulse: statusUi.label == 'LIVE',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
