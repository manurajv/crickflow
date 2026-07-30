/// Elevation / shadow intent for admin surfaces.
abstract final class AdminElevations {
  /// Cards and panels in light mode.
  static const double card = 1.5;

  /// Cards in dark mode (border-led; keep flat).
  static const double cardDark = 0;

  /// Hovered interactive cards.
  static const double cardHover = 3;

  /// Top bar / sticky headers.
  static const double appBar = 0;

  /// Dialogs / menus.
  static const double overlay = 8;

  /// Floating snackbars.
  static const double snackbar = 4;
}
