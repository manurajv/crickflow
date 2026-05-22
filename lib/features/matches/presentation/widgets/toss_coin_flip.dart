import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';

/// Animated gold coin for the toss screen (3D flip on Y axis).
class TossCoinFlip extends StatefulWidget {
  const TossCoinFlip({
    super.key,
    this.result,
    required this.onResult,
  });

  /// `heads` or `tails` after a flip; null before first flip.
  final String? result;
  final ValueChanged<String> onResult;

  @override
  State<TossCoinFlip> createState() => _TossCoinFlipState();
}

class _TossCoinFlipState extends State<TossCoinFlip>
    with SingleTickerProviderStateMixin {
  static const _coinSize = 132.0;

  late AnimationController _controller;
  Animation<double> _spin = const AlwaysStoppedAnimation(0);
  bool _flipping = false;
  String? _shownResult;

  @override
  void initState() {
    super.initState();
    _shownResult = widget.result;
    _controller = AnimationController(vsync: this);
    _controller.addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) return;
      final landing = _landingForAngle(_spin.value);
      setState(() {
        _flipping = false;
        _shownResult = landing;
      });
      widget.onResult(landing);
      HapticFeedback.mediumImpact();
    });
  }

  @override
  void didUpdateWidget(TossCoinFlip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_flipping && widget.result != oldWidget.result) {
      _shownResult = widget.result;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _landingForAngle(double angle) {
    final normalized = angle % (2 * pi);
    return normalized <= pi / 2 || normalized >= 3 * pi / 2 ? 'heads' : 'tails';
  }

  bool _showHeadsFace(double angle) {
    final normalized = angle % (2 * pi);
    return normalized <= pi / 2 || normalized >= 3 * pi / 2;
  }

  Future<void> _flip() async {
    if (_flipping) return;

    final landing = Random().nextBool() ? 'heads' : 'tails';
    final startAngle = _shownResult == 'tails' ? pi : 0.0;
    final startFace = _landingForAngle(startAngle);
    final needFlip = landing != startFace;
    final fullTurns = 4 + Random().nextInt(3);
    final endAngle =
        startAngle + (fullTurns * 2 * pi) + (needFlip ? pi : 0.0);

    setState(() => _flipping = true);
    HapticFeedback.lightImpact();

    _controller.duration = Duration(milliseconds: 1600 + fullTurns * 120);
    _spin = Tween<double>(begin: startAngle, end: endAngle).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    await _controller.forward(from: 0);
    if (mounted) _controller.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _flip,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final atRest = !_flipping;
              final angle = atRest
                  ? (_shownResult == 'tails' ? pi : 0.0)
                  : _spin.value;
              final showHeads = _showHeadsFace(angle);
              final wobble = sin(angle * 2).abs();
              final lift = _flipping ? -18 * sin(angle % (2 * pi)).abs() : 0.0;
              final squash = 1.0 - (_flipping ? 0.12 * wobble : 0.0);

              return Transform.translate(
                offset: Offset(0, lift),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..rotateY(angle),
                  child: Transform.scale(
                    scaleY: squash,
                    child: SizedBox(
                      width: _coinSize,
                      height: _coinSize,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: showHeads ? 1 : 0,
                            child: _CoinFace(
                              size: _coinSize,
                              isHeads: true,
                              highlighted: _flipping,
                              label: 'heads',
                            ),
                          ),
                          Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.0012)
                              ..rotateY(pi),
                            child: Opacity(
                              opacity: showHeads ? 0 : 1,
                              child: _CoinFace(
                                size: _coinSize,
                                isHeads: false,
                                highlighted: _flipping,
                                label: 'tails',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _flipping
              ? 'Flipping…'
              : _shownResult == null
                  ? 'Tap the coin to flip'
                  : "It's ${_shownResult!}!",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _shownResult == null
                ? AppColors.textSecondary
                : AppColors.gold,
          ),
        ),
        if (!_flipping && _shownResult != null)
          TextButton(
            onPressed: _flip,
            child: const Text('Flip again'),
          ),
      ],
    );
  }
}

class _CoinFace extends StatelessWidget {
  const _CoinFace({
    required this.size,
    required this.isHeads,
    required this.highlighted,
    required this.label,
  });

  final double size;
  final bool isHeads;
  final bool highlighted;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: isHeads
              ? [
                  const Color(0xFFFFE082),
                  AppColors.gold,
                  const Color(0xFFFF8F00),
                ]
              : [
                  AppColors.surfaceElevated,
                  AppColors.surface,
                  AppColors.card,
                ],
        ),
        border: Border.all(
          color: highlighted ? AppColors.gold : AppColors.border,
          width: highlighted ? 3.5 : 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: highlighted ? 0.45 : 0.2),
            blurRadius: highlighted ? 20 : 10,
            spreadRadius: highlighted ? 1 : 0,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'CRICKFLOW',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: isHeads
                  ? Colors.black.withValues(alpha: 0.55)
                  : AppColors.gold.withValues(alpha: 0.85),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Icon(
            isHeads ? Icons.sports_cricket : Icons.circle_outlined,
            size: 40,
            color: isHeads ? Colors.black87 : AppColors.gold,
          ),
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: isHeads ? Colors.black87 : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
