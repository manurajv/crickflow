import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/match_rules_model.dart';
import '../../../../shared/widgets/cf_underlined_field.dart';

class StartMatchSetupForm extends StatelessWidget {
  const StartMatchSetupForm({
    super.key,
    required this.rules,
    required this.cityController,
    required this.venueController,
    required this.oversController,
    required this.oversPerBowlerController,
    required this.dateTimeLabel,
    required this.onPickDateTime,
    required this.onRulesChanged,
    required this.onCityChanged,
    required this.onVenueChanged,
    this.onManageOfficials,
  });

  final MatchRulesModel rules;
  final TextEditingController cityController;
  final TextEditingController venueController;
  final TextEditingController oversController;
  final TextEditingController oversPerBowlerController;
  final String dateTimeLabel;
  final VoidCallback onPickDateTime;
  final ValueChanged<MatchRulesModel> onRulesChanged;
  final ValueChanged<String> onCityChanged;
  final ValueChanged<String> onVenueChanged;
  final VoidCallback? onManageOfficials;

  static String _matchTypeLabel(CricketMatchType t) => switch (t) {
        CricketMatchType.limitedOvers => 'Limited Overs',
        CricketMatchType.indoor => 'Indoor',
        CricketMatchType.testMatch => 'Test Match',
      };

  static IconData _matchTypeIcon(CricketMatchType t) => switch (t) {
        CricketMatchType.limitedOvers => Icons.sports_cricket,
        CricketMatchType.indoor => Icons.roofing_outlined,
        CricketMatchType.testMatch => Icons.calendar_view_day,
      };

  static String _pitchLabel(PitchType t) => switch (t) {
        PitchType.rough => 'ROUGH',
        PitchType.cement => 'CEMENT',
        PitchType.turf => 'TURF',
        PitchType.astroturf => 'ASTROTURF',
        PitchType.matting => 'MATTING',
      };

  void _onMatchTypeSelected(CricketMatchType type) {
    final next = MatchRulesModel.forMatchType(type).copyWith(
      pitchType: rules.pitchType,
      matchOfficials: rules.matchOfficials,
      powerplaySlots: rules.powerplaySlots,
      wideRuns: rules.wideRuns,
      noBallRuns: rules.noBallRuns,
      wideCountsAsLegalDelivery: rules.wideCountsAsLegalDelivery,
      noBallCountsAsLegalDelivery: rules.noBallCountsAsLegalDelivery,
      impactPlayerEnabled: rules.impactPlayerEnabled,
      wagonWheelDots: type == CricketMatchType.indoor ? false : rules.wagonWheelDots,
      wagonWheelRuns123:
          type == CricketMatchType.indoor ? false : rules.wagonWheelRuns123,
      wagonWheelShotSelection: type == CricketMatchType.indoor
          ? false
          : rules.wagonWheelShotSelection,
    );
    onRulesChanged(next);
  }

  Future<void> _openPowerplay(BuildContext context) async {
    final result = await context.push<List<List<int>>>(
      '/match/create/powerplay',
      extra: {
        'totalOvers': rules.totalOvers,
        'slots': rules.powerplaySlots,
      },
    );
    if (result != null) {
      onRulesChanged(rules.copyWith(powerplaySlots: result));
    }
  }

  String _powerplaySummary() {
    final count = rules.activePowerplayCount;
    if (count == 0) return 'Power play';
    return 'Power play ($count)';
  }

  void _setWagonWheel(bool enabled) {
    if (rules.isIndoor) return;
    onRulesChanged(
      rules.copyWith(
        wagonWheelEnabled: enabled,
        wagonWheelDots: enabled,
        wagonWheelRuns123: enabled,
        wagonWheelShotSelection: enabled,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showOvers = !rules.isTestMatch;
    final wwOn = rules.wagonWheelActive;
    final wwLocked = rules.isIndoor;

    return ListView(
      padding: AppDimens.listPadding,
      children: [
        const _FormLabel('Match type', isRequired: true),
        const SizedBox(height: AppDimens.spaceSm),
        _MatchTypePicker(
          selected: rules.cricketMatchType,
          onSelected: _onMatchTypeSelected,
        ),
        if (showOvers) ...[
          const SizedBox(height: AppDimens.spaceLg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 2,
                child: CfUnderlinedField(
                  controller: oversController,
                  label: 'No. of overs',
                  required: true,
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n > 0) {
                      onRulesChanged(rules.copyWith(totalOvers: n));
                    }
                  },
                ),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                flex: 2,
                child: CfUnderlinedField(
                  controller: oversPerBowlerController,
                  label: 'Overs per bowler',
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n > 0) {
                      onRulesChanged(rules.copyWith(oversPerBowler: n));
                    }
                  },
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _openPowerplay(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_powerplaySummary(), style: const TextStyle(fontSize: 13)),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ),
        ],
        CfUnderlinedField(
          controller: cityController,
          label: 'City / town',
          required: true,
          onChanged: onCityChanged,
        ),
        const SizedBox(height: AppDimens.fieldSpacing),
        CfUnderlinedField(
          controller: venueController,
          label: 'Ground',
          required: true,
          onChanged: onVenueChanged,
        ),
        const SizedBox(height: AppDimens.fieldSpacing),
        CfPickerField(
          label: 'Date & time',
          value: dateTimeLabel,
          onTap: onPickDateTime,
        ),
        const SizedBox(height: AppDimens.spaceLg),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Enable wagon wheel tracking',
            style: TextStyle(fontSize: 15),
          ),
          subtitle: Text(
            wwLocked
                ? 'Off for indoor matches'
                : 'Capture shot direction for runs 1–6 after each scoring shot',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          value: wwOn,
          activeThumbColor: AppColors.gold,
          onChanged: wwLocked ? null : _setWagonWheel,
        ),
        const SizedBox(height: AppDimens.spaceSm),
        const _FormLabel('Pitch type'),
        const SizedBox(height: AppDimens.spaceSm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PitchType.values.map((p) {
            final selected = rules.pitchType == p;
            return FilterChip(
              label: Text(
                _pitchLabel(p),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              selected: selected,
              onSelected: (_) => onRulesChanged(rules.copyWith(pitchType: p)),
              selectedColor: AppColors.primaryBlue.withValues(alpha: 0.35),
              checkmarkColor: AppColors.gold,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            );
          }).toList(),
        ),
        const SizedBox(height: AppDimens.spaceLg),
        const _FormLabel('Match officials'),
        const SizedBox(height: AppDimens.spaceSm),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Assign match officials'),
          subtitle: const Text(
            'Umpires, scorers, commentators — optional before toss',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          trailing: const Icon(Icons.chevron_right, color: AppColors.gold),
          onTap: onManageOfficials,
        ),
        const SizedBox(height: AppDimens.spaceXl),
      ],
    );
  }
}

class _FormLabel extends StatelessWidget {
  const _FormLabel(this.text, {this.isRequired = false});

  final String text;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Text(
      isRequired ? '$text *' : text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _MatchTypePicker extends StatelessWidget {
  const _MatchTypePicker({
    required this.selected,
    required this.onSelected,
  });

  final CricketMatchType selected;
  final ValueChanged<CricketMatchType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: CricketMatchType.values.map((type) {
        final isSelected = type == selected;
        return InkWell(
          onTap: () => onSelected(type),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 100,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryBlue
                  : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.gold : AppColors.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  StartMatchSetupForm._matchTypeIcon(type),
                  size: 22,
                  color: isSelected ? AppColors.gold : AppColors.textSecondary,
                ),
                const SizedBox(height: 6),
                Text(
                  StartMatchSetupForm._matchTypeLabel(type),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

