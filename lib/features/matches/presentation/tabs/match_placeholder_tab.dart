import 'package:flutter/material.dart';
import '../../../../core/theme/app_dimens.dart';

class MatchPlaceholderTab extends StatelessWidget {
  const MatchPlaceholderTab({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.construction_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String description;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppDimens.listPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(height: AppDimens.spaceMd),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppDimens.spaceLg),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
