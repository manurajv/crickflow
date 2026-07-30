/// Revenue Center hub sections (architecture-ready — no payment gateway).
enum RevenueHubSection {
  dashboard,
  adsRevenue,
  sponsorships,
  subscriptions,
  transactions,
  payouts,
  reports,
  integrations;

  String get label => switch (this) {
        RevenueHubSection.dashboard => 'Revenue Dashboard',
        RevenueHubSection.adsRevenue => 'Ads Revenue',
        RevenueHubSection.sponsorships => 'Sponsorships',
        RevenueHubSection.subscriptions => 'Subscriptions',
        RevenueHubSection.transactions => 'Transactions',
        RevenueHubSection.payouts => 'Payouts',
        RevenueHubSection.reports => 'Reports',
        RevenueHubSection.integrations => 'Integrations',
      };
}

enum RevenueStreamKind {
  ads,
  sponsorship,
  subscription,
  inApp,
  other;

  String get label => switch (this) {
        RevenueStreamKind.ads => 'Advertisements',
        RevenueStreamKind.sponsorship => 'Sponsorship',
        RevenueStreamKind.subscription => 'Subscription',
        RevenueStreamKind.inApp => 'In-app purchase',
        RevenueStreamKind.other => 'Other',
      };

  String get wireValue => name;

  static RevenueStreamKind parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return RevenueStreamKind.other;
  }
}

enum RevenueTxnStatus {
  estimated,
  recorded,
  pending,
  paid,
  failed,
  architectureOnly;

  String get label => switch (this) {
        RevenueTxnStatus.estimated => 'Estimated',
        RevenueTxnStatus.recorded => 'Recorded',
        RevenueTxnStatus.pending => 'Pending',
        RevenueTxnStatus.paid => 'Paid',
        RevenueTxnStatus.failed => 'Failed',
        RevenueTxnStatus.architectureOnly => 'Architecture only',
      };

  String get wireValue => name;

  static RevenueTxnStatus parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return RevenueTxnStatus.estimated;
  }
}
