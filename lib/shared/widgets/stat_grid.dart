import 'package:flutter/material.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/cf_colors.dart';

class StatCellData {
  const StatCellData({required this.value, required this.label});

  final String value;
  final String label;
}

/// Professional dashboard stats grid — white cards, dark text in light mode.
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
    final cf = context.cf;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: cfCardDecoration(context),
      child: Column(
        children: [
          Text(
            data.value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cf.textPrimary,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            data.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cf.textSecondary,
                  fontWeight: FontWeight.w500,
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
