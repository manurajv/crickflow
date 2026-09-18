import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/models/series/series.dart';
import '../../../shared/providers/series_providers.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import 'widgets/series_ui.dart';

/// Directory for one Orgs family: Associations, Clubs, or Series.
class OrgsDirectoryScreen extends ConsumerStatefulWidget {
  const OrgsDirectoryScreen({super.key, required this.family});

  final OrgFamily family;

  @override
  ConsumerState<OrgsDirectoryScreen> createState() =>
      _OrgsDirectoryScreenState();
}

class _OrgsDirectoryScreenState extends ConsumerState<OrgsDirectoryScreen> {
  final _search = TextEditingController();
  SeriesKind? _kindFilter;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  IconData get _familyIcon => switch (widget.family) {
        OrgFamily.associations => Icons.account_tree_outlined,
        OrgFamily.clubs => Icons.account_balance_outlined,
        OrgFamily.series => Icons.hub_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final family = widget.family;
    final async = ref.watch(listActiveSeriesProvider);
    return Scaffold(
      backgroundColor: cf.background,
      appBar: CfChromeAppBar(
        title: Text(family.title),
        actions: [
          IconButton(
            tooltip: 'Create ${family.singular}',
            onPressed: () => context.push(
              '/series/create?family=${family.name}',
            ),
            icon: Icon(Icons.add_circle_outline, color: cf.accent),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load: $e')),
        data: (all) {
          final familyItems = all
              .where((o) => family.kinds.contains(o.kind))
              .toList();
          final q = _search.text.trim().toLowerCase();
          var items = familyItems;
          if (_kindFilter != null) {
            items = items.where((o) => o.kind == _kindFilter).toList();
          }
          if (q.isNotEmpty) {
            items = items
                .where(
                  (o) =>
                      o.name.toLowerCase().contains(q) ||
                      o.location.toLowerCase().contains(q) ||
                      o.region.toLowerCase().contains(q) ||
                      o.description.toLowerCase().contains(q),
                )
                .toList();
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.spaceMd,
                  AppDimens.spaceMd,
                  AppDimens.spaceMd,
                  AppDimens.spaceSm,
                ),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: orgSearchDecoration(context),
                ),
              ),
              if (family.kinds.length > 1)
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceMd,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: orgFilterChip(
                          context,
                          label: 'All',
                          selected: _kindFilter == null,
                          onSelected: (_) =>
                              setState(() => _kindFilter = null),
                        ),
                      ),
                      ...family.kinds.map(
                        (k) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: orgFilterChip(
                            context,
                            label: k.label,
                            selected: _kindFilter == k,
                            onSelected: (_) =>
                                setState(() => _kindFilter = k),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(listActiveSeriesProvider),
                  child: items.isEmpty
                      ? ListView(
                          children: [
                            SeriesEmptyState(
                              icon: _familyIcon,
                              title: 'No ${family.title.toLowerCase()} yet',
                              message:
                                  'Create a ${family.singular.toLowerCase()} to get started.',
                              action: FilledButton.icon(
                                onPressed: () => context.push(
                                  '/series/create?family=${family.name}',
                                ),
                                icon: const Icon(Icons.add),
                                label: Text('Create ${family.singular}'),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppDimens.spaceMd),
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppDimens.spaceMd),
                          itemBuilder: (_, i) => _OrgCoverCard(org: items[i]),
                        ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.push('/series/create?family=${family.name}'),
        icon: const Icon(Icons.add),
        label: Text('Create ${family.singular}'),
      ),
    );
  }
}

class _OrgCoverCard extends StatelessWidget {
  const _OrgCoverCard({required this.org});
  final SeriesModel org;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final image = org.coverImageUrl ?? org.logoUrl;
    return Material(
      color: cf.card,
      elevation: cf.isLight ? 1 : 0,
      shadowColor: cf.cardShadow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/series/${org.id}'),
        child: SizedBox(
          height: 168,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image != null)
                Image.network(
                  image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: cf.surfaceElevated,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.image_outlined,
                      color: cf.textMuted,
                      size: 40,
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(gradient: cf.heroGradient),
                  alignment: Alignment.center,
                  child: Text(
                    org.name.isNotEmpty ? org.name[0].toUpperCase() : '?',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      cf.bannerScrimEnd,
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: cf.accent.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    org.kind.label,
                    style: TextStyle(
                      color: cf.onAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      org.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      org.subtitleMeta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
