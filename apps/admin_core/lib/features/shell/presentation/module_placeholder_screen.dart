import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/cf_empty_state.dart';
import '../providers/shell_providers.dart';

/// Placeholder for modules not yet implemented.
class ModulePlaceholderScreen extends ConsumerStatefulWidget {
  const ModulePlaceholderScreen({
    super.key,
    required this.title,
    this.description =
        'This module will be implemented in a later phase. Navigation is prepared only.',
  });

  final String title;
  final String description;

  @override
  ConsumerState<ModulePlaceholderScreen> createState() =>
      _ModulePlaceholderScreenState();
}

class _ModulePlaceholderScreenState
    extends ConsumerState<ModulePlaceholderScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(breadcrumbProvider.notifier).state = ['Dashboard', widget.title];
    });
  }

  @override
  Widget build(BuildContext context) {
    return CfEmptyState(
      icon: Icons.construction_outlined,
      title: widget.title,
      message: widget.description,
    );
  }
}
