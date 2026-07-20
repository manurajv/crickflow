import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/innings_model.dart';
import '../../../../shared/widgets/scoring_ui_kit.dart';
import '../utils/scoring_display_utils.dart';
import '../../../../core/theme/cf_colors.dart';

/// Batter on crease with live stats for picker cards.
class CreaseBatterOption {
  const CreaseBatterOption({
    required this.playerId,
    required this.name,
    required this.runs,
    required this.balls,
    required this.roleLabel,
    this.photoUrl,
  });

  final String playerId;
  final String name;
  final int runs;
  final int balls;
  final String roleLabel;
  final String? photoUrl;

  static CreaseBatterOption? fromInnings(
    InningsModel inn,
    String? playerId, {
    required String roleLabel,
  }) {
    if (playerId == null) return null;
    final b = ScoringDisplayUtils.batsman(inn, playerId);
    return CreaseBatterOption(
      playerId: playerId,
      name: b?.playerName.isNotEmpty == true ? b!.playerName : playerId,
      runs: b?.runs ?? 0,
      balls: b?.balls ?? 0,
      roleLabel: roleLabel,
    );
  }
}

/// Run out: which batter was dismissed?
Future<String?> showRunOutDismissedPicker(
  BuildContext context, {
  required InningsModel innings,
}) {
  final striker = CreaseBatterOption.fromInnings(
    innings,
    innings.strikerId,
    roleLabel: 'Striker',
  );
  final nonStriker = CreaseBatterOption.fromInnings(
    innings,
    innings.nonStrikerId,
    roleLabel: 'Non-striker',
  );
  final options = [striker, nonStriker].whereType<CreaseBatterOption>().toList();
  if (options.isEmpty) return Future.value(null);

  return ScoringUiKit.showSheet<String>(
    context,
    isScrollControlled: true,
    builder: (ctx) => _CreasePickerBody(
      title: 'Which batter got out?',
      subtitle: 'Run out — tap the dismissed batter',
      options: options,
      confirmLabel: 'Confirm run out',
    ),
  );
}

/// Token for "New batter" in the next-striker picker.
const kNewBatterNextStrikerToken = '__new_batter__';

/// Batter who remains on the crease after a run-out dismissal.
String? runOutSurvivorId(InningsModel innings, String dismissedPlayerId) {
  if (innings.strikerId != null && innings.strikerId != dismissedPlayerId) {
    return innings.strikerId;
  }
  if (innings.nonStrikerId != null &&
      innings.nonStrikerId != dismissedPlayerId) {
    return innings.nonStrikerId;
  }
  return null;
}

/// After run out: who faces the next delivery (striker / non-striker / new batter).
Future<String?> showRunOutNextStrikerPicker(
  BuildContext context, {
  required InningsModel innings,
  required String dismissedPlayerId,
}) {
  final options = <CreaseBatterOption>[];
  if (innings.strikerId != null &&
      innings.strikerId != dismissedPlayerId) {
    final s = CreaseBatterOption.fromInnings(
      innings,
      innings.strikerId,
      roleLabel: 'Current striker',
    );
    if (s != null) options.add(s);
  }
  if (innings.nonStrikerId != null &&
      innings.nonStrikerId != dismissedPlayerId) {
    final ns = CreaseBatterOption.fromInnings(
      innings,
      innings.nonStrikerId,
      roleLabel: 'Current non-striker',
    );
    if (ns != null) options.add(ns);
  }
  options.add(
    const CreaseBatterOption(
      playerId: kNewBatterNextStrikerToken,
      name: 'New batter',
      runs: 0,
      balls: 0,
      roleLabel: 'Incoming batter',
    ),
  );

  return ScoringUiKit.showSheet<String>(
    context,
    isScrollControlled: true,
    builder: (ctx) => _CreasePickerBody(
      title: 'Who will face the next ball?',
      subtitle: 'Select the batter on strike for the next delivery',
      options: options,
      confirmLabel: 'Confirm',
    ),
  );
}

/// Resolves striker/non-striker after run out including new-batter pick.
Future<
    ({
      String strikerId,
      String strikerName,
      String nonStrikerId,
      String nonStrikerName,
    })?> showRunOutNextStrikerFlow(
  BuildContext context, {
  required InningsModel innings,
  required String dismissedPlayerId,
  required List<CreaseBatterOption> newBatterOptions,
}) async {
  final picked = await showRunOutNextStrikerPicker(
    context,
    innings: innings,
    dismissedPlayerId: dismissedPlayerId,
  );
  if (picked == null) return null;

  final survivorId = runOutSurvivorId(innings, dismissedPlayerId);
  if (survivorId == null) return null;

  final survivorName =
      ScoringDisplayUtils.batsman(innings, survivorId)?.playerName ??
          survivorId;

  if (picked == kNewBatterNextStrikerToken) {
    if (newBatterOptions.isEmpty) return null;
    final newB = await showNewBatterPicker(
      context,
      title: 'Select new batter',
      subtitle: 'Incoming batter to face the next ball',
      options: newBatterOptions,
    );
    if (newB == null) return null;
    return (
      strikerId: newB.playerId,
      strikerName: newB.name,
      nonStrikerId: survivorId,
      nonStrikerName: survivorName,
    );
  }

  if (newBatterOptions.isEmpty) return null;
  final newB = await showNewBatterPicker(
    context,
    title: 'Select new batter',
    subtitle: 'Fill the vacant end',
    options: newBatterOptions,
  );
  if (newB == null) return null;

  final pickedName =
      ScoringDisplayUtils.batsman(innings, picked)?.playerName ?? picked;
  return (
    strikerId: picked,
    strikerName: pickedName,
    nonStrikerId: newB.playerId,
    nonStrikerName: newB.name,
  );
}

/// After run out: who faces the next ball (striker)?
Future<String?> showStrikeDecisionPicker(
  BuildContext context, {
  required InningsModel innings,
}) {
  final striker = CreaseBatterOption.fromInnings(
    innings,
    innings.strikerId,
    roleLabel: 'Batter A',
  );
  final nonStriker = CreaseBatterOption.fromInnings(
    innings,
    innings.nonStrikerId,
    roleLabel: 'Batter B',
  );
  final options = [striker, nonStriker].whereType<CreaseBatterOption>().toList();
  if (options.length < 2) return Future.value(innings.strikerId);

  return ScoringUiKit.showSheet<String>(
    context,
    isScrollControlled: true,
    builder: (ctx) => _CreasePickerBody(
      title: 'Who will face the next ball?',
      subtitle: 'Confirm batting positions',
      options: options,
      confirmLabel: 'Confirm strike',
    ),
  );
}

/// New batter to fill vacant crease after wicket.
///
/// Not dismissible — scorer must confirm an incoming batter.
Future<CreaseBatterOption?> showNewBatterPicker(
  BuildContext context, {
  required String title,
  required String subtitle,
  required List<CreaseBatterOption> options,
}) {
  if (options.isEmpty) return Future.value(null);
  return ScoringUiKit.showSheet<CreaseBatterOption>(
    context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: _CreasePickerBody(
        title: title,
        subtitle: subtitle,
        options: options,
        confirmLabel: 'Confirm batter',
        returnFullOption: true,
      ),
    ),
  );
}

class _CreasePickerBody extends StatefulWidget {
  const _CreasePickerBody({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.confirmLabel,
    this.returnFullOption = false,
  });

  final String title;
  final String subtitle;
  final List<CreaseBatterOption> options;
  final String confirmLabel;
  final bool returnFullOption;

  @override
  State<_CreasePickerBody> createState() => _CreasePickerBodyState();
}

class _CreasePickerBodyState extends State<_CreasePickerBody> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.spaceMd,
          AppDimens.spaceMd,
          AppDimens.spaceMd,
          AppDimens.spaceLg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScoringSheetHeader(title: widget.title),
            const SizedBox(height: AppDimens.spaceXs),
            Text(
              widget.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cf.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            ...widget.options.map((o) {
              final selected = _selectedId == o.playerId;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
                child: _BatterCard(
                  option: o,
                  selected: selected,
                  onTap: () => setState(() => _selectedId = o.playerId),
                ),
              );
            }),
            const SizedBox(height: AppDimens.spaceSm),
            FilledButton(
              onPressed: _selectedId == null
                  ? null
                  : () {
                      if (widget.returnFullOption) {
                        final picked = widget.options.firstWhere(
                          (o) => o.playerId == _selectedId,
                        );
                        Navigator.pop(context, picked);
                      } else {
                        Navigator.pop(context, _selectedId);
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: cf.accent,
                foregroundColor: cf.background,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                widget.confirmLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BatterCard extends StatelessWidget {
  const _BatterCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final CreaseBatterOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final borderColor =
        selected ? cf.accent : cf.border.withValues(alpha: 0.35);
    final bg = selected
        ? cf.accent.withValues(alpha: 0.12)
        : cf.sectionBackground;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              _Avatar(name: option.name, photoUrl: option.photoUrl),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: cf.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      option.roleLabel,
                      style: TextStyle(
                        fontSize: 13,
                        color: cf.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${option.runs} (${option.balls})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: cf.textPrimary,
                    ),
                  ),
                  Text(
                    'R (B)',
                    style: TextStyle(
                      fontSize: 11,
                      color: cf.textSecondary,
                    ),
                  ),
                ],
              ),
              if (selected) ...[
                const SizedBox(width: AppDimens.spaceSm),
                Icon(Icons.check_circle, color: cf.accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final initial = name.isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 28,
        backgroundImage: NetworkImage(photoUrl!),
        backgroundColor: cf.sectionBackground,
      );
    }
    return CircleAvatar(
      radius: 28,
      backgroundColor: cf.sectionBackground,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: cf.accent,
        ),
      ),
    );
  }
}
