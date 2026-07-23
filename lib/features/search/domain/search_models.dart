enum SearchCategory {
  all,
  players,
  teams,
  matches,
  tournaments,
  grounds,
  posts,
}

extension SearchCategoryX on SearchCategory {
  String get label => switch (this) {
        SearchCategory.all => 'All',
        SearchCategory.players => 'Players',
        SearchCategory.teams => 'Teams',
        SearchCategory.matches => 'Matches',
        SearchCategory.tournaments => 'Tournaments',
        SearchCategory.grounds => 'Grounds',
        SearchCategory.posts => 'Posts',
      };

  String get suggestionNoun => switch (this) {
        SearchCategory.all => 'Everywhere',
        SearchCategory.players => 'Players',
        SearchCategory.teams => 'Teams',
        SearchCategory.matches => 'Matches',
        SearchCategory.tournaments => 'Tournaments',
        SearchCategory.grounds => 'Grounds',
        SearchCategory.posts => 'Community posts',
      };
}

/// Ranking score for a candidate string vs query.
double searchRelevanceScore(String haystack, String query) {
  final h = haystack.trim().toLowerCase();
  final q = query.trim().toLowerCase();
  if (h.isEmpty || q.isEmpty) return 0;
  if (h == q) return 1000;
  if (h.startsWith(q)) return 800 + (q.length / h.length) * 50;
  if (h.contains(q)) return 500 + (q.length / h.length) * 40;
  // Token / similar prefix
  final tokens = h.split(RegExp(r'[\s\-_]+'));
  for (final t in tokens) {
    if (t == q) return 900;
    if (t.startsWith(q)) return 700;
    if (t.contains(q)) return 400;
  }
  // Simple edit-distance-ish: shared prefix length
  var i = 0;
  while (i < h.length && i < q.length && h[i] == q[i]) {
    i++;
  }
  if (i >= 2) return 100.0 + i * 10;
  return 0;
}
