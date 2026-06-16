/// Team list ownership filter.
enum TeamListScope { yours, opponents, all }

extension TeamListScopeX on TeamListScope {
  String get label => switch (this) {
    TeamListScope.yours => 'Your teams',
    TeamListScope.opponents => 'Opponents',
    TeamListScope.all => 'All',
  };

  /// Short label for filter chips (matches My Cricket tab style).
  String get chipLabel => switch (this) {
    TeamListScope.yours => 'Yours',
    TeamListScope.opponents => 'Opponents',
    TeamListScope.all => 'All',
  };
}
