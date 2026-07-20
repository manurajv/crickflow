import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../domain/search_models.dart';
import '../providers/search_providers.dart';

/// Dedicated search entry — autofocuses the field and shows recent + suggestions.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit(String raw, {SearchCategory category = SearchCategory.all}) {
    final q = raw.trim();
    if (q.isEmpty) return;
    ref.read(recentSearchesProvider.notifier).add(q);
    ref.read(searchQueryProvider.notifier).applySuggestion(q, category);
    context.push('/search/results');
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final recent = ref.watch(recentSearchesProvider);
    final text = _controller.text.trim();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search players, teams, matches…',
            border: InputBorder.none,
            hintStyle: TextStyle(color: cf.textMuted),
          ),
          style: Theme.of(context).textTheme.titleMedium,
          onChanged: (v) {
            ref.read(searchQueryProvider.notifier).setText(v);
            setState(() {});
          },
          onSubmitted: _submit,
        ),
        actions: [
          if (text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                ref.read(searchQueryProvider.notifier).setText('');
                setState(() {});
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppDimens.spaceXl),
        children: [
          if (recent.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceMd,
                AppDimens.spaceMd,
                AppDimens.spaceXs,
              ),
              child: Row(
                children: [
                  Text(
                    'Recent searches',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () =>
                        ref.read(recentSearchesProvider.notifier).clear(),
                    child: const Text('Clear all'),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                ),
                itemCount: recent.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final item = recent[index];
                  return InputChip(
                    label: Text(item),
                    onPressed: () {
                      _controller.text = item;
                      _submit(item);
                    },
                    onDeleted: () =>
                        ref.read(recentSearchesProvider.notifier).remove(item),
                    deleteIconColor: cf.textMuted,
                  );
                },
              ),
            ),
          ],
          if (text.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceLg,
                AppDimens.spaceMd,
                AppDimens.spaceXs,
              ),
              child: Text(
                'Suggestions',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            ...SearchCategory.values.map((cat) {
              return ListTile(
                leading: Icon(
                  switch (cat) {
                    SearchCategory.all => Icons.search,
                    SearchCategory.players => Icons.person_outline,
                    SearchCategory.teams => Icons.groups_outlined,
                    SearchCategory.matches => Icons.sports_cricket_outlined,
                    SearchCategory.tournaments => Icons.emoji_events_outlined,
                    SearchCategory.grounds => Icons.stadium_outlined,
                    SearchCategory.clubs => Icons.home_work_outlined,
                    SearchCategory.users => Icons.people_outline,
                  },
                  color: cf.accent,
                ),
                title: Text('Search "$text" in ${cat.suggestionNoun}'),
                onTap: () => _submit(text, category: cat),
              );
            }),
          ] else if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppDimens.spaceXl),
              child: Column(
                children: [
                  Icon(Icons.search, size: 48, color: cf.textMuted),
                  const SizedBox(height: 12),
                  Text(
                    'Search CrickFlow',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Find players, teams, matches, tournaments, grounds, and more.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: cf.textSecondary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
