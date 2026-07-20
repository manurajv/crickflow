import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/admob_config.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../shared/widgets/ads/cf_banner_ad.dart';
import '../domain/search_models.dart';
import '../providers/search_providers.dart';
import 'widgets/search_result_cards.dart';

class SearchResultsScreen extends ConsumerStatefulWidget {
  const SearchResultsScreen({super.key});

  @override
  ConsumerState<SearchResultsScreen> createState() =>
      _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(searchQueryProvider).text;
    _controller = TextEditingController(text: initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final query = ref.watch(searchQueryProvider);
    final resultsAsync = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search…',
            border: InputBorder.none,
            hintStyle: TextStyle(color: cf.textMuted),
          ),
          onChanged: (v) => ref.read(searchQueryProvider.notifier).setText(v),
          onSubmitted: (v) {
            final q = v.trim();
            if (q.isEmpty) return;
            ref.read(recentSearchesProvider.notifier).add(q);
            ref
                .read(searchQueryProvider.notifier)
                .applySuggestion(q, query.category);
          },
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
                vertical: 8,
              ),
              itemCount: SearchCategory.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = SearchCategory.values[index];
                final selected = cat == query.category;
                return ChoiceChip(
                  label: Text(cat.label),
                  selected: selected,
                  onSelected: (_) {
                    ref.read(searchQueryProvider.notifier).setCategory(cat);
                  },
                );
              },
            ),
          ),
          Expanded(
            child: resultsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Search failed: $e')),
              data: (result) {
                if (query.debounced.isEmpty) {
                  return Center(
                    child: Text(
                      'Type to search',
                      style: TextStyle(color: cf.textSecondary),
                    ),
                  );
                }
                if (result.hits.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimens.spaceXl),
                      child: Text(
                        'No results for "${result.query}"',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cf.textSecondary),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: result.hits.length + 1,
                  itemBuilder: (context, index) {
                    if (index == result.hits.length) {
                      return const CfBannerAd(
                        placement: AdPlacement.searchResults,
                      );
                    }
                    return SearchResultCard(hit: result.hits[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
