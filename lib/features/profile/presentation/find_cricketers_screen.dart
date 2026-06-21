import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/player_discovery_repository.dart';
import '../../../shared/providers/player_social_provider.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import 'widgets/player_card_tile.dart';

class FindCricketersScreen extends ConsumerStatefulWidget {
  const FindCricketersScreen({super.key});

  @override
  ConsumerState<FindCricketersScreen> createState() =>
      _FindCricketersScreenState();
}

class _FindCricketersScreenState extends ConsumerState<FindCricketersScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  FindCricketersFilter _filter = FindCricketersFilter.all;
  List<UserModel> _results = [];
  var _loading = false;

  static const _visibleFilters = [
    FindCricketersFilter.all,
    FindCricketersFilter.popular,
    FindCricketersFilter.followers,
    FindCricketersFilter.following,
    FindCricketersFilter.teammates,
    FindCricketersFilter.nearby,
    FindCricketersFilter.recentlyJoined,
    FindCricketersFilter.suggested,
    FindCricketersFilter.mutualConnections,
  ];

  @override
  void initState() {
    super.initState();
    _search('');
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search(_searchController.text);
    });
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    final uid = ref.read(authStateProvider).value?.uid;
    final me = ref.read(currentUserProfileProvider).valueOrNull;
    try {
      final results = await ref
          .read(playerDiscoveryRepositoryProvider)
          .searchPlayers(
            query: query,
            currentUserId: uid,
            filter: _filter,
            currentUser: me,
          );
      if (mounted) {
        setState(() {
          _results = results;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    }
  }

  void _setFilter(FindCricketersFilter filter) {
    if (_filter == filter) return;
    setState(() => _filter = filter);
    _search(_searchController.text);
  }

  String _filterLabel(FindCricketersFilter filter) => switch (filter) {
        FindCricketersFilter.all => 'All',
        FindCricketersFilter.popular => 'Popular Cricketers',
        FindCricketersFilter.fromContacts => 'From Contacts',
        FindCricketersFilter.followers => 'Followers',
        FindCricketersFilter.following => 'Following',
        FindCricketersFilter.teammates => 'Teammates',
        FindCricketersFilter.nearby => 'Nearby Players',
        FindCricketersFilter.recentlyJoined => 'Recently Joined',
        FindCricketersFilter.suggested => 'Suggested For You',
        FindCricketersFilter.mutualConnections => 'Mutual Connections',
      };

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final uid = ref.watch(authStateProvider).value?.uid;

    return Scaffold(
      appBar: const CfChromeAppBar(title: Text('Find Cricketers')),
      body: Column(
        children: [
          Padding(
            padding: AppDimens.listPadding.copyWith(bottom: 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or Player ID (e.g. CF000001)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _search('');
                        },
                      )
                    : null,
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
                vertical: AppDimens.spaceSm,
              ),
              itemCount: _visibleFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _visibleFilters[index];
                final selected = _filter == filter;
                return FilterChip(
                  label: Text(_filterLabel(filter)),
                  selected: selected,
                  onSelected: (_) => _setFilter(filter),
                  selectedColor: cf.accent.withValues(alpha: 0.2),
                  checkmarkColor: cf.accent,
                );
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Text(
                          _emptyMessage(),
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: cf.textSecondary,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        padding: AppDimens.listPadding,
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final user = _results[index];
                          return PlayerCardTile(
                            user: user,
                            viewerId: uid,
                            onOpenProfile: () {
                              final id = user.playerId;
                              if (id != null && id.isNotEmpty) {
                                context.push('/player/$id');
                              }
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _emptyMessage() {
    if (_filter == FindCricketersFilter.mutualConnections) {
      return 'Mutual connections coming soon';
    }
    if (_filter == FindCricketersFilter.teammates) {
      return 'No teammates found yet. Join a team to discover squad mates.';
    }
    if (_filter == FindCricketersFilter.nearby) {
      return 'No nearby players found. Update your location in profile settings.';
    }
    if (_searchController.text.trim().isNotEmpty) {
      return 'No players match your search';
    }
    return 'No players to show';
  }
}
