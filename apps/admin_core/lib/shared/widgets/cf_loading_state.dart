import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/theme/admin_colors.dart';
import 'cf_skeleton.dart';

class CfLoadingState extends StatelessWidget {
  const CfLoadingState({
    super.key,
    this.message,
    this.skeleton = false,
  });

  final String? message;

  /// When true, shows a card/table shimmer instead of a spinner.
  final bool skeleton;

  @override
  Widget build(BuildContext context) {
    if (skeleton) {
      return const CfSkeletonPage();
    }

    final dimens = context.adminDimens;
    return Semantics(
      label: message ?? 'Loading',
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AdminColors.primaryBlue,
              ),
            ),
            if (message != null) ...[
              SizedBox(height: dimens.spaceLg),
              Text(message!, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}
