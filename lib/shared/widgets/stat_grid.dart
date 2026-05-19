import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

class StatCellData {
  const StatCellData({required this.value, required this.label});

  final String value;
  final String label;
}

/// Three-column stats grid (reference-inspired, CrickFlow theme).
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.cells});

  final List<StatCellData> cells;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const crossCount = 3;
        final width = (constraints.maxWidth - 16) / crossCount;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: cells
              .map(
                (c) => SizedBox(
                  width: width,
                  child: _StatCell(data: c),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.data});

  final StatCellData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(
            data.value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            data.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
