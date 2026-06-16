/// Team list ownership filter.
enum TeamListScope {
  yours,
  all,
  opponents,
}

extension TeamListScopeX on TeamListScope {
  String get label => switch (this) {
        TeamListScope.yours => 'Your teams',
        TeamListScope.all => 'All',
        TeamListScope.opponents => 'Opponents',
      };

  /// Short label for filter chips (matches My Cricket tab style).
  String get chipLabel => switch (this) {
        TeamListScope.yours => 'Yours',
        TeamListScope.all => 'All',
        TeamListScope.opponents => 'Opponents',
      };
}
