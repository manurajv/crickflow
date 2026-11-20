/** Runtime feature switches. Prefer a flag over deleting navigation code. */
export const featureFlags = {
  /**
   * Temporary hide — set to true to restore a CrickFlow PRO nav/footer entry.
   * No website PRO page is linked today; keep this next to the flag so it is
   * obvious how to bring the item back.
   */
  showCrickFlowProNav: false,
} as const;
