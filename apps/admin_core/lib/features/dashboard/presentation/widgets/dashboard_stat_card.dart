import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../models/dashboard_models.dart';

class DashboardOverviewStatCard extends StatefulWidget {
  const DashboardOverviewStatCard({super.key, required this.metric});

  final OverviewMetric metric;

  @override
  State<DashboardOverviewStatCard> createState() =>
      _DashboardOverviewStatCardState();
}

class _DashboardOverviewStatCardState extends State<DashboardOverviewStatCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final m = widget.metric;
    final growthColor = m.growthPositive == null
        ? colors.textMuted
        : (m.growthPositive! ? colors.success : colors.error);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
        child: CfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: m.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(m.icon, color: m.accent, size: 20),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: growthColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (m.growthPositive != null)
                          Icon(
                            m.growthPositive!
                                ? Icons.trending_up_rounded
                                : Icons.trending_down_rounded,
                            size: 14,
                            color: growthColor,
                          ),
                        if (m.growthPositive != null) const SizedBox(width: 4),
                        Text(
                          m.growthLabel,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: growthColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                m.value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                m.title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 28,
                width: double.infinity,
                child: CustomPaint(
                  painter: _SparklinePainter(
                    values: m.sparkline,
                    color: m.accent,
                    fill: m.accent.withValues(alpha: 0.12),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Today's growth",
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.textMuted,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.color,
    required this.fill,
  });

  final List<double> values;
  final Color color;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 0.001 ? 1.0 : (maxV - minV);

    Offset pointAt(int i) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * (i / (values.length - 1));
      final norm = (values[i] - minV) / range;
      final y = size.height - (norm * size.height);
      return Offset(x, y);
    }

    final path = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(pointAt(i).dx, pointAt(i).dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..style = PaintingStyle.fill
        ..color = fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

class DashboardQuickActionCard extends StatefulWidget {
  const DashboardQuickActionCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  final QuickActionItem item;
  final VoidCallback onTap;

  @override
  State<DashboardQuickActionCard> createState() =>
      _DashboardQuickActionCardState();
}

class _DashboardQuickActionCardState extends State<DashboardQuickActionCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final item = widget.item;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? 1.02 : 1,
        duration: const Duration(milliseconds: 160),
        child: CfCard(
          onTap: widget.onTap,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: item.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: item.accent, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                item.label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 18, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

Color serviceHealthColor(BuildContext context, ServiceHealth status) {
  final colors = context.adminColors;
  return switch (status) {
    ServiceHealth.healthy => colors.success,
    ServiceHealth.warning => colors.warning,
    ServiceHealth.offline => colors.error,
  };
}

String serviceHealthLabel(ServiceHealth status) => switch (status) {
      ServiceHealth.healthy => 'Healthy',
      ServiceHealth.warning => 'Warning',
      ServiceHealth.offline => 'Offline',
    };
