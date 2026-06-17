import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/enums.dart';
import '../../../../data/models/location_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/match_rules_model.dart';
import '../../../../shared/widgets/cf_underlined_field.dart';
import 'ground_search_field.dart';
import 'match_wide_no_ball_rules_section.dart';

class StartMatchSetupForm extends StatefulWidget {
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
    required this.onLocationResolved,
    required this.onPickGroundOnMap,
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
  final ValueChanged<LocationModel> onLocationResolved;
  final VoidCallback onPickGroundOnMap;
  final VoidCallback? onManageOfficials;

  static const _startMatchBallTypes = [
    CricketBallType.tennis,
    CricketBallType.leather,
  ];

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
        PitchType.rough => 'Rough',
        PitchType.cement => 'Cement',
        PitchType.turf => 'Turf',
        PitchType.astroturf => 'Astroturf',
        PitchType.matting => 'Matting',
      };

  static String _ballTypeLabel(CricketBallType t) => switch (t) {
        CricketBallType.tennis => 'Tennis',
        CricketBallType.leather => 'Leather',
        CricketBallType.indoor => 'Tennis',
      };

  @override
  State<StartMatchSetupForm> createState() => _StartMatchSetupFormState();
}

class _StartMatchSetupFormState extends State<StartMatchSetupForm> {
  bool _advancedExpanded = false;

  MatchRulesModel get rules => widget.rules;

  CricketBallType get _selectedBallType {
    final resolved = rules.resolvedBallType;
    return resolved == CricketBallType.leather
        ? CricketBallType.leather
        : CricketBallType.tennis;
  }

  void _onMatchTypeSelected(CricketMatchType type) {
    final preservedBall = _selectedBallType;
    var next = MatchRulesModel.forMatchType(type).copyWith(
      ballType: preservedBall,
      pitchType: rules.pitchType,
      matchOfficials: rules.matchOfficials,
      powerplaySlots: rules.powerplaySlots,
      wideRuns: rules.wideRuns,
      noBallRuns: rules.noBallRuns,
      wideCountsAsLegalDelivery: rules.wideCountsAsLegalDelivery,
      noBallCountsAsLegalDelivery: rules.noBallCountsAsLegalDelivery,
      impactPlayerEnabled: rules.impactPlayerEnabled,
      wagonWheelDots:
          type == CricketMatchType.indoor ? false : rules.wagonWheelDots,
      wagonWheelRuns123:
          type == CricketMatchType.indoor ? false : rules.wagonWheelRuns123,
      wagonWheelShotSelection: type == CricketMatchType.indoor
          ? false
          : rules.wagonWheelShotSelection,
    );
    if (rules.isManualOversPerBowler) {
      next = next.copyWith(
        oversPerBowler: MatchRulesModel.clampOversPerBowler(
          rules.oversPerBowler,
          next.totalOvers,
        ),
        isManualOversPerBowler: true,
      );
    }
    widget.onRulesChanged(next);
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
      widget.onRulesChanged(rules.copyWith(powerplaySlots: result));
    }
  }

  String _powerplaySummary() {
    final count = rules.activePowerplayCount;
    return count == 0 ? 'Set up powerplay overs' : 'Powerplay ($count active)';
  }

  void _setWagonWheel(bool enabled) {
    if (rules.isIndoor) return;
    widget.onRulesChanged(
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
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceXl,
      ),
      children: [
        // ── 1. Venue & schedule ──────────────────────────────────────────
        _SectionCard(
          title: 'Venue & schedule',
          icon: Icons.place_outlined,
          children: [
            CfUnderlinedField(
              controller: widget.cityController,
              label: 'City / town',
              required: true,
              onChanged: widget.onCityChanged,
            ),
            const SizedBox(height: AppDimens.fieldSpacing),
            GroundSearchField(
              controller: widget.venueController,
              onVenueChanged: widget.onVenueChanged,
              onLocationResolved: (loc) {
                widget.onLocationResolved(loc);
                if (loc.city.isNotEmpty &&
                    widget.cityController.text.trim().isEmpty) {
                  widget.cityController.text = loc.city;
                }
              },
              onPickOnMap: widget.onPickGroundOnMap,
            ),
            const SizedBox(height: AppDimens.fieldSpacing),
            CfPickerField(
              label: 'Date & time',
              value: widget.dateTimeLabel,
              onTap: widget.onPickDateTime,
            ),
          ],
        ),

        const SizedBox(height: AppDimens.spaceMd),

        // ── 2. Match type ────────────────────────────────────────────────
        _SectionCard(
          title: 'Match type',
          icon: Icons.sports_cricket,
          isRequired: true,
          children: [
            _MatchTypePicker(
              selected: rules.cricketMatchType,
              onSelected: _onMatchTypeSelected,
            ),
          ],
        ),

        const SizedBox(height: AppDimens.spaceMd),

        // ── 3. Ball & pitch ──────────────────────────────────────────────
        _SectionCard(
          title: 'Ball & pitch',
          icon: Icons.settings_outlined,
          children: [
            _SubLabel('Ball type'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  StartMatchSetupForm._startMatchBallTypes.map((ball) {
                final selected = _selectedBallType == ball;
                return _ChoiceChip(
                  label: StartMatchSetupForm._ballTypeLabel(ball),
                  selected: selected,
                  onTap: () =>
                      widget.onRulesChanged(rules.copyWith(ballType: ball)),
                );
              }).toList(),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            _SubLabel('Pitch type'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PitchType.values.map((p) {
                final selected = rules.pitchType == p;
                return _ChoiceChip(
                  label: StartMatchSetupForm._pitchLabel(p),
                  selected: selected,
                  onTap: () =>
                      widget.onRulesChanged(rules.copyWith(pitchType: p)),
                );
              }).toList(),
            ),
          ],
        ),

        const SizedBox(height: AppDimens.spaceMd),

        // ── 4. Match rules (overs) ───────────────────────────────────────
        if (showOvers)
          _SectionCard(
            title: 'Match rules',
            icon: Icons.rule_outlined,
            children: [
              Row(
                children: [
                  Expanded(
                    child: CfUnderlinedField(
                      controller: widget.oversController,
                      label: 'Total overs',
                      required: true,
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null && n > 0) {
                          widget.onRulesChanged(rules.withTotalOvers(n));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceMd),
                  Expanded(
                    child: CfUnderlinedField(
                      controller: widget.oversPerBowlerController,
                      label: 'Overs / bowler',
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null && n >= 1) {
                          widget.onRulesChanged(
                              rules.withManualOversPerBowler(n));
                        }
                      },
                    ),
                  ),
                ],
              ),
              if (rules.isManualOversPerBowler) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => widget.onRulesChanged(
                        rules.resetOversPerBowlerToAuto()),
                    icon: const Icon(Icons.autorenew, size: 16),
                    label: const Text('Reset to auto'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.gold,
                      visualDensity: VisualDensity.compact,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  rules.isManualOversPerBowler
                      ? 'Bowler limit set manually.'
                      : 'Bowler limit auto-calculated (total ÷ 5, rounded up).',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.spaceSm),
              const Divider(height: 1),
              InkWell(
                onTap: () => _openPowerplay(context),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.bolt_outlined,
                        size: 18,
                        color: AppColors.gold,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _powerplaySummary(),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

        if (showOvers) const SizedBox(height: AppDimens.spaceMd),

        // ── 5. Wagon wheel ───────────────────────────────────────────────
        _SectionCard(
          title: 'Tracking',
          icon: Icons.track_changes_outlined,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Wagon wheel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        wwLocked
                            ? 'Not available for indoor matches'
                            : 'Capture shot direction after each scoring shot',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: wwOn,
                  activeTrackColor: AppColors.gold,
                  thumbColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.white;
                    }
                    return null;
                  }),
                  onChanged: wwLocked ? null : _setWagonWheel,
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: AppDimens.spaceMd),

        // ── 6. Officials ─────────────────────────────────────────────────
        _SectionCard(
          title: 'Match officials',
          icon: Icons.badge_outlined,
          children: [
            InkWell(
              onTap: widget.onManageOfficials,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Assign umpires, scorers & more',
                            style: TextStyle(fontSize: 14),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Optional — can be assigned before toss',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.gold,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: AppDimens.spaceMd),

        // ── 7. Advanced (balls per over) — collapsed by default ──────────
        _AdvancedSection(
          expanded: _advancedExpanded,
          onToggle: () =>
              setState(() => _advancedExpanded = !_advancedExpanded),
          child: _SectionCard(
            title: 'Special cases',
            icon: Icons.tune_outlined,
            children: [
              _SubLabel('Players per team'),
              const SizedBox(height: 8),
              Text(
                'Playing squad size for each team (6-a-side, 7-a-side, 11-a-side, etc.).',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppDimens.spaceSm),
              _PlayersPerTeamStepper(
                value: rules.playersPerTeam,
                onChanged: (v) => widget.onRulesChanged(
                  rules.copyWith(
                    playersPerTeam: MatchRulesModel.clampPlayersPerTeam(v),
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              const Divider(height: 1),
              const SizedBox(height: AppDimens.spaceSm),
              _SubLabel('Balls per over'),
              const SizedBox(height: 8),
              Text(
                'Standard cricket uses 6 balls per over. Change only for special formats.',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppDimens.spaceSm),
              _BallsPerOverStepper(
                value: rules.ballsPerOver,
                onChanged: (v) => widget.onRulesChanged(
                  rules.copyWith(
                    ballsPerOver: MatchRulesModel.clampBallsPerOver(v),
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              const Divider(height: 1),
              const SizedBox(height: AppDimens.spaceSm),
              MatchWideNoBallRulesSection(
                rules: rules,
                onChanged: widget.onRulesChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Private widgets ────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
    this.isRequired = false,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header row
            Row(
              children: [
                Icon(icon, size: 16, color: AppColors.gold),
                const SizedBox(width: 6),
                Text(
                  isRequired ? '$title *' : title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceMd),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SubLabel extends StatelessWidget {
  const _SubLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryBlue.withValues(alpha: 0.25)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.gold : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _AdvancedSection extends StatelessWidget {
  const _AdvancedSection({
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: AppDimens.spaceSm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.tune_outlined,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Special cases',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: AppDimens.spaceSm),
          child,
        ],
      ],
    );
  }
}

class _PlayersPerTeamStepper extends StatelessWidget {
  const _PlayersPerTeamStepper({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepButton(
          icon: Icons.remove,
          onTap: value > 1 ? () => onChanged(value - 1) : null,
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                '$value',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Text(
                'players per team',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        _StepButton(
          icon: Icons.add,
          onTap: value < 25 ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

class _BallsPerOverStepper extends StatelessWidget {
  const _BallsPerOverStepper({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepButton(
          icon: Icons.remove,
          onTap: value > 1 ? () => onChanged(value - 1) : null,
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                '$value',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Text(
                'balls per over',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        _StepButton(
          icon: Icons.add,
          onTap: value < 12 ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.gold.withValues(alpha: 0.15)
              : AppColors.surfaceElevated,
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled ? AppColors.gold : AppColors.border,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? AppColors.gold : AppColors.textMuted,
        ),
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
    return Row(
      children: CricketMatchType.values.map((type) {
        final isSelected = type == selected;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 12),
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
                      color: isSelected
                          ? AppColors.gold
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      StartMatchSetupForm._matchTypeLabel(type),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.2,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
