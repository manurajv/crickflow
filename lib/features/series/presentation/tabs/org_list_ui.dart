import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/tournament_model.dart';
import '../../../../domain/services/series/org_competition_lists.dart';

/// Live / Upcoming / Completed chips (My Cricket chip style) with counts.
class OrgStatusChips extends StatelessWidget {
  const OrgStatusChips({
    super.key,
    required this.selected,
    required this.counts,
    required this.onChanged,
    this.trailing,
  });

  final OrgStatusFilter selected;
  final Map<OrgStatusFilter, int> counts;
  final ValueChanged<OrgStatusFilter> onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceSm,
        AppDimens.spaceMd,
        0,
      ),
      child: Row(
        children: [
          for (final f in OrgStatusFilter.values) ...[
            ChoiceChip(
              key: Key('org_filter_${f.name}'),
              label: Text(
                f == OrgStatusFilter.all
                    ? f.label
                    : '${f.label} (${counts[f] ?? 0})',
              ),
              selected: selected == f,
              onSelected: (_) => onChanged(f),
              selectedColor: cf.accent,
              backgroundColor: cf.sectionBackground,
              labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected == f ? cf.onAccent : cf.textSecondary,
                    fontWeight:
                        selected == f ? FontWeight.w700 : FontWeight.w500,
                  ),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(width: AppDimens.spaceXs),
          ],
          ?trailing,
        ],
      ),
    );
  }
}

/// "Live now · 2" style group title.
class OrgSectionHeader extends StatelessWidget {
  const OrgSectionHeader({
    super.key,
    required this.bucket,
    required this.title,
    required this.count,
  });

  final OrgBucket bucket;
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final color = bucket == OrgBucket.live ? cf.statusLive : cf.textSecondary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceXs,
      ),
      child: Row(
        children: [
          if (bucket == OrgBucket.live) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: bucket == OrgBucket.live ? color : cf.textPrimary,
                ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: cf.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

/// Full-width start / request action shown above the lists.
class OrgStartButton extends StatelessWidget {
  const OrgStartButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.buttonKey,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceSm,
        AppDimens.spaceMd,
        0,
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          key: buttonKey,
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
        ),
      ),
    );
  }
}

/// Popup chip narrowing a list to standalone org matches or one org
/// tournament (null = everything).
class OrgCompetitionFilterChip extends StatelessWidget {
  const OrgCompetitionFilterChip({
    super.key,
    required this.tournaments,
    required this.value,
    required this.onChanged,
    this.allLabel = 'All matches',
  });

  final List<TournamentModel> tournaments;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String allLabel;

  String get _label {
    if (value == null) return allLabel;
    if (value == kOrgStandaloneFilter) return 'Standalone';
    for (final t in tournaments) {
      if (t.id == value) return t.name;
    }
    return allLabel;
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final active = value != null;
    return PopupMenuButton<String>(
      key: const Key('org_tournament_filter'),
      tooltip: 'Filter by tournament',
      onSelected: (v) => onChanged(v.isEmpty ? null : v),
      itemBuilder: (_) => [
        PopupMenuItem(value: '', child: Text(allLabel)),
        const PopupMenuItem(
          value: kOrgStandaloneFilter,
          child: Text('Standalone matches'),
        ),
        if (tournaments.isNotEmpty) const PopupMenuDivider(),
        for (final t in tournaments)
          PopupMenuItem(value: t.id, child: Text(t.name)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              active ? cf.accent.withValues(alpha: 0.16) : cf.sectionBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? cf.accent : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 16,
              color: active ? cf.accent : cf.textSecondary,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                _label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: active ? cf.accent : cf.textSecondary,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: active ? cf.accent : cf.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal chip row with the same padding as [OrgStatusChips].
class OrgStatusChipsLike extends StatelessWidget {
  const OrgStatusChipsLike({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceSm,
        AppDimens.spaceMd,
        0,
      ),
      child: Row(children: children),
    );
  }
}
