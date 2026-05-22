import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';

/// Slide-to-confirm control (e.g. umpire confirms innings break).
class CfSlideToConfirm extends StatefulWidget {
  const CfSlideToConfirm({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onConfirmed;
  final bool enabled;

  @override
  State<CfSlideToConfirm> createState() => _CfSlideToConfirmState();
}

class _CfSlideToConfirmState extends State<CfSlideToConfirm> {
  double _drag = 0;
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const thumbSize = 52.0;
        const pad = 4.0;
        final trackW = constraints.maxWidth;
        final maxDrag = (trackW - thumbSize - pad * 2).clamp(0.0, double.infinity);

        void onDragUpdate(DragUpdateDetails d) {
          if (!widget.enabled || _confirmed) return;
          setState(() {
            _drag = (_drag + d.delta.dx).clamp(0.0, maxDrag);
          });
        }

        void onDragEnd(DragEndDetails _) {
          if (!widget.enabled || _confirmed) return;
          if (_drag >= maxDrag * 0.85) {
            setState(() {
              _drag = maxDrag;
              _confirmed = true;
            });
            HapticFeedback.mediumImpact();
            widget.onConfirmed();
          } else {
            setState(() => _drag = 0);
          }
        }

        return Opacity(
          opacity: widget.enabled ? 1 : 0.45,
          child: Container(
            height: thumbSize + pad * 2,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(thumbSize),
              border: Border.all(color: AppColors.border),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(left: thumbSize + 12),
                    child: Align(
                      alignment: Alignment.center,
                      child: Text(
                        widget.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: pad + _drag,
                  child: GestureDetector(
                    onHorizontalDragUpdate: onDragUpdate,
                    onHorizontalDragEnd: onDragEnd,
                    child: Container(
                      width: thumbSize,
                      height: thumbSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _confirmed ? AppColors.gold : AppColors.primaryBlue,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        _confirmed ? Icons.check : Icons.chevron_right,
                        color: _confirmed ? Colors.black : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
