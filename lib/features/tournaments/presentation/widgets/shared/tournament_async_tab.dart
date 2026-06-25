import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_dimens.dart';

/// Shared loading / error / empty wrapper for tournament dashboard tabs.
class TournamentAsyncTab<T> extends StatelessWidget {
  const TournamentAsyncTab({
    super.key,
    required this.asyncValue,
    required this.builder,
    required this.onRefresh,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyTitle = 'Nothing here yet',
    this.emptyDescription = '',
  });

  final AsyncValue<T> asyncValue;
  final Widget Function(T data) builder;
  final Future<void> Function() onRefresh;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyDescription;

  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
            Center(
              child: Padding(
                padding: AppDimens.screenPadding,
                child: Text('$e', textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
      ),
      data: (data) => RefreshIndicator(
        onRefresh: onRefresh,
        child: builder(data),
      ),
    );
  }
}

/// Inline empty hint inside a populated tab section.
class TournamentModuleEmptyInline extends StatelessWidget {
  const TournamentModuleEmptyInline({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceMd),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
