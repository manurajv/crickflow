import 'package:flutter/material.dart';
import '../../../../../core/constants/enums.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/utils/currency_utils.dart';
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
    final country = draft.location.country.isNotEmpty
        ? draft.location.country
        : draft.city;
    final currency = currencyCodeForCountry(country);
    onChanged(
      draft.copyWith(
        setup: fn(draft.setup).copyWith(
              budgetCurrencyCode: currency.isNotEmpty
                  ? currency
                  : draft.setup.budgetCurrencyCode,
            ),
      ),
    );
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

  static const _selectableRoles = [
    TournamentOfficialRole.umpire,
    TournamentOfficialRole.scorer,
    TournamentOfficialRole.streamer,
    TournamentOfficialRole.commentator,
  ];

  @override
  Widget build(BuildContext context) {
    final setup = draft.setup;
    final country = draft.location.country;
    final dayLabel = budgetRangeSectionLabel(
      base: 'Per day',
      countryOrCode: country,
    );
    final matchLabel = budgetRangeSectionLabel(
      base: 'Per match',
      countryOrCode: country,
    );

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
        const TournamentCreateSectionLabel(
          label: 'What do you need?',
          required: true,
        ),
        ..._selectableRoles.map((role) {
          final selected = setup.requiredOfficialRoles.contains(role);
          return CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(officialRoleShortLabel(role)),
            value: selected,
            onChanged: (v) {
              final next = Set<TournamentOfficialRole>.from(
                setup.requiredOfficialRoles,
              );
              final dayByRole =
                  Map<TournamentOfficialRole, OfficialBudgetBand>.from(
                setup.budgetPerDayByRole,
              );
              final matchByRole =
                  Map<TournamentOfficialRole, OfficialBudgetBand>.from(
                setup.budgetPerMatchByRole,
              );
              if (v == true) {
                next.add(role);
              } else {
                next.remove(role);
                dayByRole.remove(role);
                matchByRole.remove(role);
              }
              _patchSetup(
                (s) => s.copyWith(
                  requiredOfficialRoles: next,
                  budgetPerDayByRole: dayByRole,
                  budgetPerMatchByRole: matchByRole,
                ),
              );
            },
          );
        }),
        const SizedBox(height: AppDimens.spaceMd),
        const TournamentCreateSectionLabel(
          label: 'For how many days?',
          required: true,
        ),
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
        const TournamentCreateSectionLabel(
          label: 'Matches per day?',
          required: true,
        ),
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
        const TournamentCreateSectionLabel(
          label: 'Budget range',
          required: true,
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Same budget for all'),
          value: setup.sameBudgetForAll,
          onChanged: (v) {
            final same = v ?? true;
            if (same) {
              _patchSetup((s) => s.copyWith(sameBudgetForAll: true));
              return;
            }
            // Seed each selected role from the shared bands so nothing is lost.
            final seededDay =
                Map<TournamentOfficialRole, OfficialBudgetBand>.from(
              setup.budgetPerDayByRole,
            );
            final seededMatch =
                Map<TournamentOfficialRole, OfficialBudgetBand>.from(
              setup.budgetPerMatchByRole,
            );
            if (setup.budgetPerDay != null) {
              for (final role in setup.requiredOfficialRoles) {
                seededDay.putIfAbsent(role, () => setup.budgetPerDay!);
              }
            }
            if (setup.budgetPerMatch != null) {
              for (final role in setup.requiredOfficialRoles) {
                seededMatch.putIfAbsent(role, () => setup.budgetPerMatch!);
              }
            }
            _patchSetup(
              (s) => s.copyWith(
                sameBudgetForAll: false,
                budgetPerDayByRole: seededDay,
                budgetPerMatchByRole: seededMatch,
              ),
            );
          },
        ),
        if (setup.sameBudgetForAll) ...[
          TournamentCreateSectionLabel(label: dayLabel),
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
          TournamentCreateSectionLabel(label: matchLabel),
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
        ] else ...[
          if (setup.requiredOfficialRoles.isEmpty)
            const TournamentCreateNote(
              text: 'Select at least one official role to set budgets.',
            )
          else
            for (final role in _selectableRoles.where(
              setup.requiredOfficialRoles.contains,
            )) ...[
              const SizedBox(height: AppDimens.spaceSm),
              Text(
                officialRoleShortLabel(role),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppDimens.spaceXs),
              TournamentCreateSectionLabel(label: dayLabel),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _dayBudgets.map((b) {
                  return TournamentChoiceChip(
                    label: officialBudgetLabel(b),
                    selected: setup.budgetPerDayByRole[role] == b,
                    onTap: () {
                      final next =
                          Map<TournamentOfficialRole, OfficialBudgetBand>.from(
                        setup.budgetPerDayByRole,
                      );
                      next[role] = b;
                      _patchSetup(
                        (s) => s.copyWith(budgetPerDayByRole: next),
                      );
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppDimens.spaceXs),
              TournamentCreateSectionLabel(label: matchLabel),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _matchBudgets.map((b) {
                  return TournamentChoiceChip(
                    label: officialBudgetLabel(b),
                    selected: setup.budgetPerMatchByRole[role] == b,
                    onTap: () {
                      final next =
                          Map<TournamentOfficialRole, OfficialBudgetBand>.from(
                        setup.budgetPerMatchByRole,
                      );
                      next[role] = b;
                      _patchSetup(
                        (s) => s.copyWith(budgetPerMatchByRole: next),
                      );
                    },
                  );
                }).toList(),
              ),
            ],
        ],
        const SizedBox(height: AppDimens.spaceMd),
        const TournamentCreateSectionLabel(
          label: 'How can officials contact you?',
          required: true,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: selectableOfficialContactMethods.map((m) {
            final selected = setup.officialContactMethods.contains(m);
            return TournamentChoiceChip(
              label: officialContactLabel(m),
              selected: selected,
              onTap: () {
                final next = Set<OfficialContactMethod>.from(
                  setup.officialContactMethods,
                );
                if (selected) {
                  // Keep at least one method selected.
                  if (next.length <= 1) return;
                  next.remove(m);
                } else {
                  next.add(m);
                }
                _patchSetup((s) => s.copyWith(officialContactMethods: next));
              },
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
}
