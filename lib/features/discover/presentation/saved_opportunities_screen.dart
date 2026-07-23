import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../shared/providers/opportunity_provider.dart';
import 'widgets/opportunity_author_sheet.dart';
import 'widgets/opportunity_post_card.dart';

/// Profile-hub list of bookmarked opportunity posts.
class SavedOpportunitiesScreen extends ConsumerWidget {
  const SavedOpportunitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final theme = Theme.of(context);
    final async = ref.watch(opportunitySavedPostsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Opportunities'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.spaceLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Could not load saved posts', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Text(
                  '$e',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: cf.textMuted),
                ),
                const SizedBox(height: AppDimens.spaceMd),
                FilledButton(
                  onPressed: () => ref.invalidate(opportunitySavedPostsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (posts) {
          if (posts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.spaceXl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bookmark_border, size: 48, color: cf.textMuted),
                    const SizedBox(height: AppDimens.spaceMd),
                    Text(
                      'No saved opportunities',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppDimens.spaceSm),
                    Text(
                      'Tap the bookmark on a Discover post to save it here.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cf.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              AppDimens.spaceMd,
              AppDimens.spaceMd,
              AppDimens.spaceXl,
            ),
            itemCount: posts.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppDimens.spaceMd),
            itemBuilder: (context, i) {
              final post = posts[i];
              return OpportunityPostCard(
                post: post,
                onAuthorTap: () =>
                    showOpportunityAuthorSheet(context, post.authorId),
              );
            },
          );
        },
      ),
    );
  }
}
