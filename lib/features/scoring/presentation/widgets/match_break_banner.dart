import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/match_model.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/cf_slide_to_confirm.dart';

/// Active break banner with live timer and slide-to-resume.
class MatchBreakBanner extends ConsumerStatefulWidget {
  const MatchBreakBanner({super.key, required this.match});

  final MatchModel match;

  @override
  ConsumerState<MatchBreakBanner> createState() => _MatchBreakBannerState();
}

class _MatchBreakBannerState extends ConsumerState<MatchBreakBanner> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final start = widget.match.activeMatchBreak?.startTime;
    if (start == null) return;
    setState(() => _elapsed = DateTime.now().difference(start));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Future<void> _resume() async {
    try {
      await ref
          .read(matchRepositoryProvider)
          .endMatchBreak(widget.match.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not resume: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final br = widget.match.activeMatchBreak!;
    final started = DateFormat.jm().format(br.startTime);

    return Material(
      color: AppColors.primaryBlue,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${br.breakType} Break',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppColors.gold,
              ),
            ),
            Text('Started: $started'),
            Text('Duration: ${_formatDuration(_elapsed)}'),
            if (br.reason.isNotEmpty) Text('Reason: ${br.reason}'),
            const SizedBox(height: AppDimens.spaceSm),
            CfSlideToConfirm(
              label: 'Slide To Resume Match',
              onConfirmed: _resume,
            ),
          ],
        ),
      ),
    );
  }
}
