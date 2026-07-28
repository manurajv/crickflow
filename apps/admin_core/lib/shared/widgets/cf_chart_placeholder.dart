import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import 'cf_card.dart';

/// Chart placeholder until analytics modules land.
class CfChartPlaceholder extends StatelessWidget {
  const CfChartPlaceholder({
    super.key,
    this.title = 'Chart',
    this.height = 220,
  });

  final String title;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return CfCard(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.area_chart_outlined, size: 40, color: colors.textMuted),
                    const SizedBox(height: 8),
                    Text(
                      'Chart placeholder',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colors.textMuted,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
