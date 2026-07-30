import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../models/monitoring_enums.dart';

Color platformHealthColor(BuildContext context, PlatformServiceHealth health) {
  final colors = context.adminColors;
  return switch (health) {
    PlatformServiceHealth.healthy => colors.success,
    PlatformServiceHealth.warning => colors.warning,
    PlatformServiceHealth.critical => colors.error,
    PlatformServiceHealth.offline => colors.error,
    PlatformServiceHealth.unknown => colors.textMuted,
  };
}

Color monitoringSeverityColor(BuildContext context, MonitoringSeverity s) {
  final colors = context.adminColors;
  return switch (s) {
    MonitoringSeverity.info => AdminColors.primaryBlue,
    MonitoringSeverity.warning => colors.warning,
    MonitoringSeverity.high => colors.error,
    MonitoringSeverity.critical => colors.error,
  };
}

class HealthDot extends StatelessWidget {
  const HealthDot({super.key, required this.health, this.size = 10});

  final PlatformServiceHealth health;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: platformHealthColor(context, health),
        shape: BoxShape.circle,
      ),
    );
  }
}

class HealthBadge extends StatelessWidget {
  const HealthBadge({super.key, required this.health});

  final PlatformServiceHealth health;

  @override
  Widget build(BuildContext context) {
    final color = platformHealthColor(context, health);
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HealthDot(health: health, size: 8),
            const SizedBox(width: 6),
            Text(
              health.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
