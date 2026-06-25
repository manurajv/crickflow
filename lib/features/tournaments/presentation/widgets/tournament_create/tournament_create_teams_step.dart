import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/enums.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../data/models/tournament/tournament_create_draft.dart';
import '../../../../../data/models/tournament/tournament_setup_meta.dart';
import '../../../../../shared/widgets/cf_underlined_field.dart';
import '../../../../../shared/widgets/start_match_ui.dart';
import 'tournament_create_ui.dart';

class TournamentCreateTeamsStep extends ConsumerStatefulWidget {
  const TournamentCreateTeamsStep({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final TournamentCreateDraft draft;
  final ValueChanged<TournamentCreateDraft> onChanged;

  @override
  ConsumerState<TournamentCreateTeamsStep> createState() =>
      _TournamentCreateTeamsStepState();
}

class _TournamentCreateTeamsStepState
    extends ConsumerState<TournamentCreateTeamsStep> {
  late final TextEditingController _cityController;
  late final TextEditingController _entryFeeController;
  late final TextEditingController _totalTeamsController;
  late final TextEditingController _teamsRequiredController;
  late final TextEditingController _detailsController;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _cityController = TextEditingController(
      text: d.setup.teamLocation.city.isNotEmpty
          ? d.setup.teamLocation.city
          : d.city,
    );
    _entryFeeController = TextEditingController(text: d.entryFeeText);
    _totalTeamsController = TextEditingController(text: d.totalTeamsText);
    _teamsRequiredController = TextEditingController(text: d.teamsRequiredText);
    _detailsController = TextEditingController(text: d.setup.additionalDetails);
  }

  @override
  void dispose() {
    _cityController.dispose();
    _entryFeeController.dispose();
    _totalTeamsController.dispose();
    _teamsRequiredController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  void _patch(TournamentCreateDraft Function(TournamentCreateDraft) fn) {
    widget.onChanged(fn(widget.draft));
  }

  void _patchSetup(TournamentSetupMeta Function(TournamentSetupMeta) fn) {
    _patch((d) => d.copyWith(setup: fn(d.setup)));
  }

  @override
  void didUpdateWidget(covariant TournamentCreateTeamsStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    final city = widget.draft.setup.teamLocation.city.isNotEmpty
        ? widget.draft.setup.teamLocation.city
        : widget.draft.city;
    if (_cityController.text != city) {
      _cityController.text = city;
    }
  }

  @override
  Widget build(BuildContext context) {
    final setup = widget.draft.setup;

    return ListView(
      padding: AppDimens.screenPadding,
      children: [
        Text(
          'Team details',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Because you need teams for your tournament',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.cf.textSecondary,
              ),
        ),
        const SizedBox(height: AppDimens.spaceLg),
        CfUnderlinedField(
          controller: _cityController,
          label: 'City',
          required: true,
          onChanged: (v) => _patch((d) => d.copyWith(
                city: v,
                location: d.location.copyWith(city: v),
                setup: d.setup.copyWith(
                  teamLocation: d.setup.teamLocation.copyWith(city: v),
                ),
              )),
        ),
        const SizedBox(height: AppDimens.fieldSpacing),
        CfUnderlinedField(
          controller: _entryFeeController,
          label: 'Entry fee',
          required: true,
          keyboardType: TextInputType.number,
          onChanged: (v) => _patch((d) => d.copyWith(entryFeeText: v)),
        ),
        const SizedBox(height: AppDimens.fieldSpacing),
        CfUnderlinedField(
          controller: _totalTeamsController,
          label: 'Total no. of teams',
          required: true,
          keyboardType: TextInputType.number,
          onChanged: (v) => _patch((d) => d.copyWith(totalTeamsText: v)),
        ),
        const SizedBox(height: AppDimens.fieldSpacing),
        CfUnderlinedField(
          controller: _teamsRequiredController,
          label: 'How many teams do you require?',
          keyboardType: TextInputType.number,
          onChanged: (v) => _patch((d) => d.copyWith(teamsRequiredText: v)),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        const TournamentCreateSectionLabel(label: 'Winning prize', required: true),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: WinningPrizeType.values.map((p) {
            final label = switch (p) {
              WinningPrizeType.cash => 'CASH',
              WinningPrizeType.trophies => 'TROPHIES',
              WinningPrizeType.both => 'BOTH',
            };
            return TournamentChoiceChip(
              label: label,
              selected: setup.winningPrizeType == p,
              onTap: () => _patchSetup((s) => s.copyWith(winningPrizeType: p)),
            );
          }).toList(),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        const TournamentCreateSectionLabel(label: 'Matches on', required: true),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TournamentMatchSchedule.values.map((s) {
            final label = switch (s) {
              TournamentMatchSchedule.weekends => 'WEEKENDS',
              TournamentMatchSchedule.weekdays => 'WEEKDAYS',
              TournamentMatchSchedule.allDays => 'ALL DAYS',
            };
            return TournamentChoiceChip(
              label: label,
              selected: setup.matchesOn == s,
              onTap: () => _patchSetup((x) => x.copyWith(matchesOn: s)),
            );
          }).toList(),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        const TournamentCreateSectionLabel(label: 'Match timing', required: true),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TournamentDayNight.values.map((t) {
            final label = switch (t) {
              TournamentDayNight.day => 'DAY',
              TournamentDayNight.night => 'NIGHT',
              TournamentDayNight.dayAndNight => 'DAY & NIGHT',
            };
            return TournamentChoiceChip(
              label: label,
              selected: setup.matchTiming == t,
              onTap: () => _patchSetup((x) => x.copyWith(matchTiming: t)),
            );
          }).toList(),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        const TournamentCreateSectionLabel(label: 'Tournament format', required: true),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TournamentChoiceChip(
              label: 'LEAGUE',
              selected: widget.draft.format == TournamentFormat.league,
              onTap: () => _patch((d) => d.copyWith(format: TournamentFormat.league)),
            ),
            TournamentChoiceChip(
              label: 'KNOCKOUT',
              selected: widget.draft.format == TournamentFormat.knockout,
              onTap: () =>
                  _patch((d) => d.copyWith(format: TournamentFormat.knockout)),
            ),
            TournamentChoiceChip(
              label: 'LEAGUE + KO',
              selected: widget.draft.format == TournamentFormat.leagueKnockout,
              onTap: () => _patch(
                (d) => d.copyWith(format: TournamentFormat.leagueKnockout),
              ),
            ),
            TournamentChoiceChip(
              label: 'CUSTOM',
              selected: widget.draft.format == TournamentFormat.custom,
              onTap: () =>
                  _patch((d) => d.copyWith(format: TournamentFormat.custom)),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceMd),
        const TournamentCreateSectionLabel(label: 'Any additional details?'),
        TextField(
          controller: _detailsController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText:
                'Add more details like prizes, trophies, entry fees, rules, etc.',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => _patchSetup((s) => s.copyWith(additionalDetails: v)),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        StartMatchCard(
          child: Column(
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Inform all the players of my previous tournaments.',
                ),
                value: setup.informPreviousPlayers,
                onChanged: (v) => _patchSetup(
                  (s) => s.copyWith(informPreviousPlayers: v ?? false),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Do you need officials? (e.g. Umpire, Scorer)'),
                value: widget.draft.needOfficials,
                onChanged: (v) =>
                    _patch((d) => d.copyWith(needOfficials: v ?? false)),
              ),
            ],
          ),
        ),
        const TournamentCreateNote(
          text:
              '*We will use this information to post a looking request on CrickFlow Community.*',
        ),
      ],
    );
  }
}
