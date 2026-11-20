/// Runtime feature switches. Prefer a flag or comment over deleting code
/// so hidden entries can be restored in one place.
class FeatureFlags {
  FeatureFlags._();

  /// Temporary hide — set to `true` to restore the CrickFlow PRO item in
  /// the app drawer (and any website equivalent). The `/store` route and
  /// [StoreScreen] stay in the app; only the navigation entry is gated.
  static const bool showCrickFlowProNav = false;
}
