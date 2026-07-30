/// Firestore read budgets for admin panels.
///
/// Keep list pagination at [pageSize]. Use [summaryScanMax] for KPI sample
/// scans. Prefer `count()` aggregations when filters allow exact totals.
abstract final class AdminQueryLimits {
  /// Default cursor page size for hub tables.
  static const int pageSize = 25;

  /// Cap for summary / KPI sample document reads.
  static const int summaryScanMax = 250;

  /// Cap for analytics series samples.
  static const int analyticsSampleMax = 300;

  /// Cap for monitoring probe samples.
  static const int monitoringSampleMax = 80;

  /// Cap for grounds tournament catalog aggregation.
  static const int groundsTournamentScanMax = 500;

  /// Cap for grounds registry docs.
  static const int groundsRegistryScanMax = 400;

  /// Cap for audit timeline one-shot.
  static const int auditTimelineMax = 40;

  /// Cap for role usage count fallback sample.
  static const int roleUsageFallbackMax = 50;

  /// Soft clamp helper.
  static int clamp(int requested, int max) =>
      requested < 1 ? 1 : (requested > max ? max : requested);
}
