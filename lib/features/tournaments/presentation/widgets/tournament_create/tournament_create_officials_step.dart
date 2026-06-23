import 'package:flutter/material.dart';
import '../../../../../core/constants/enums.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../data/models/tournament/tournament_create_draft.dart';
import '../../../../../data/models/tournament/tournament_setup_meta.dart';
import 'tournament_create_ui.dart';

class TournamentCreateOfficialsStep extends StatelessWidget {
  const TournamentCreateOfficialsStep({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final TournamentCreateDraft draft;
  final ValueChanged<TournamentCreateDraft> onChanged;

  void _patchSetup(TournamentSetupMeta Function(TournamentSetupMeta) fn) {
    onChanged(draft.copyWith(setup: fn(draft.setup)));
  }

  static const _dayOptions = ['1', '2', '3', '4', '5+'];
  static const _matchOptions = ['1', '2', '3', '4', '5+'];

  static const _dayBudgets = [
    OfficialBudgetBand.day500to1000,
    OfficialBudgetBand.day1100to1500,
    OfficialBudgetBand.day1600to2000,
    OfficialBudgetBand.day2000plus,
    OfficialBudgetBand.dayNotDecided,
  ];

  static const _matchBudgets = [
    OfficialBudgetBand.match100to500,
    OfficialBudgetBand.match600to1000,
    OfficialBudgetBand.match1100to1500,
    OfficialBudgetBand.match1500plus,
    OfficialBudgetBand.matchNotDecided,
  ];

  @override
  Widget build(BuildContext context) {
    final setup = draft.setup;

    return ListView(
      padding: AppDimens.screenPadding,
      children: [
        Text(
          'Official details',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppDimens.spaceLg),
        const TournamentCreateSectionLabel(label: 'What do you need?', required: true),
        ...[
          TournamentOfficialRole.umpire,
          TournamentOfficialRole.scorer,
          TournamentOfficialRole.streamer,
          TournamentOfficialRole.commentator,
        ].map((role) {
          final selected = setup.requiredOfficialRoles.contains(role);
          return CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_roleLabel(role)),
            value: selected,
            onChanged: (v) {
              final next = Set<TournamentOfficialRole>.from(
                setup.requiredOfficialRoles,
              );
              if (v == true) {
                next.add(role);
              } else {
                next.remove(role);
              }
              _patchSetup((s) => s.copyWith(requiredOfficialRoles: next));
            },
          );
        }),
        const SizedBox(height: AppDimens.spaceMd),
        const TournamentCreateSectionLabel(label: 'For how many days?', required: true),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _dayOptions.map((opt) {
            return TournamentChoiceChip(
              label: opt,
              selected: setup.officialDays == opt,
              onTap: () => _patchSetup((s) => s.copyWith(officialDays: opt)),
            );
          }).toList(),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        const TournamentCreateSectionLabel(label: 'Matches per day?', required: true),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _matchOptions.map((opt) {
            return TournamentChoiceChip(
              label: opt,
              selected: setup.matchesPerDay == opt,
              onTap: () => _patchSetup((s) => s.copyWith(matchesPerDay: opt)),
            );
          }).toList(),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        const TournamentCreateSectionLabel(label: 'Budget range', required: true),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Same budget for all'),
          value: setup.sameBudgetForAll,
          onChanged: (v) =>
              _patchSetup((s) => s.copyWith(sameBudgetForAll: v ?? true)),
        ),
        const TournamentCreateSectionLabel(label: 'Per day (in INR):'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _dayBudgets.map((b) {
            return TournamentChoiceChip(
              label: officialBudgetLabel(b),
              selected: setup.budgetPerDay == b,
              onTap: () => _patchSetup((s) => s.copyWith(budgetPerDay: b)),
            );
          }).toList(),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        const TournamentCreateSectionLabel(label: 'Per match (in INR):'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _matchBudgets.map((b) {
            return TournamentChoiceChip(
              label: officialBudgetLabel(b),
              selected: setup.budgetPerMatch == b,
              onTap: () => _patchSetup((s) => s.copyWith(budgetPerMatch: b)),
            );
          }).toList(),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        const TournamentCreateSectionLabel(
          label: 'How can officials contact you?',
          required: true,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: OfficialContactMethod.values.map((m) {
            return TournamentChoiceChip(
              label: officialContactLabel(m),
              selected: setup.officialContactMethod == m,
              onTap: () => _patchSetup((s) => s.copyWith(officialContactMethod: m)),
            );
          }).toList(),
        ),
        const TournamentCreateNote(
          text:
              '*We will use this information to post a Looking request on CrickFlow Community.*',
        ),
      ],
    );
  }

  String _roleLabel(TournamentOfficialRole role) => switch (role) {
        TournamentOfficialRole.umpire => 'Umpire',
        TournamentOfficialRole.scorer => 'Scorer',
        TournamentOfficialRole.streamer => 'Live Streamer',
        TournamentOfficialRole.commentator => 'Commentator',
        TournamentOfficialRole.photographer => 'Photographer',
        TournamentOfficialRole.videographer => 'Videographer',
      };
}
