enum AdsHubSection {
  dashboard,
  admobConfig,
  customAds,
  sponsored,
  campaigns,
  placements,
  revenue,
  advertisers,
  approvalQueue,
  history;

  String get label => switch (this) {
        AdsHubSection.dashboard => 'Dashboard',
        AdsHubSection.admobConfig => 'AdMob Config',
        AdsHubSection.customAds => 'Custom Ads',
        AdsHubSection.sponsored => 'Sponsored Content',
        AdsHubSection.campaigns => 'Campaigns',
        AdsHubSection.placements => 'Placements',
        AdsHubSection.revenue => 'Revenue',
        AdsHubSection.advertisers => 'Advertisers',
        AdsHubSection.approvalQueue => 'Approval Queue',
        AdsHubSection.history => 'History',
      };
}

enum ManagedAdStatus {
  draft,
  pendingApproval,
  approved,
  rejected,
  scheduled,
  active,
  paused,
  archived,
  expired;

  String get label => switch (this) {
        ManagedAdStatus.draft => 'Draft',
        ManagedAdStatus.pendingApproval => 'Pending Approval',
        ManagedAdStatus.approved => 'Approved',
        ManagedAdStatus.rejected => 'Rejected',
        ManagedAdStatus.scheduled => 'Scheduled',
        ManagedAdStatus.active => 'Active',
        ManagedAdStatus.paused => 'Paused',
        ManagedAdStatus.archived => 'Archived',
        ManagedAdStatus.expired => 'Expired',
      };

  String get wireValue => name;

  static ManagedAdStatus parse(String? raw) {
    if (raw == null || raw.isEmpty) return ManagedAdStatus.draft;
    for (final v in ManagedAdStatus.values) {
      if (v.name == raw) return v;
    }
    return ManagedAdStatus.draft;
  }
}

enum ManagedAdMediaType {
  image,
  video,
  gif,
  carousel;

  String get label => switch (this) {
        ManagedAdMediaType.image => 'Image',
        ManagedAdMediaType.video => 'Video',
        ManagedAdMediaType.gif => 'GIF',
        ManagedAdMediaType.carousel => 'Carousel',
      };

  String get wireValue => name;

  static ManagedAdMediaType parse(String? raw) {
    if (raw == null || raw.isEmpty) return ManagedAdMediaType.image;
    for (final v in ManagedAdMediaType.values) {
      if (v.name == raw) return v;
    }
    return ManagedAdMediaType.image;
  }
}

enum ManagedAdPlacement {
  home,
  communityFeed,
  discoverFeed,
  tournamentScreen,
  matchHub,
  matchScorecard,
  playerProfile,
  teamProfile,
  groundProfile,
  liveMatchList,
  searchResults,
  news;

  String get label => switch (this) {
        ManagedAdPlacement.home => 'Home Screen',
        ManagedAdPlacement.communityFeed => 'Community Feed',
        ManagedAdPlacement.discoverFeed => 'Discover Feed',
        ManagedAdPlacement.tournamentScreen => 'Tournament Screen',
        ManagedAdPlacement.matchHub => 'Match Hub',
        ManagedAdPlacement.matchScorecard => 'Match Scorecard',
        ManagedAdPlacement.playerProfile => 'Player Profile',
        ManagedAdPlacement.teamProfile => 'Team Profile',
        ManagedAdPlacement.groundProfile => 'Ground Profile',
        ManagedAdPlacement.liveMatchList => 'Live Match List',
        ManagedAdPlacement.searchResults => 'Search Results',
        ManagedAdPlacement.news => 'News Section',
      };

  String get wireValue => name;

  static ManagedAdPlacement parse(String? raw) {
    if (raw == null || raw.isEmpty) return ManagedAdPlacement.home;
    for (final v in ManagedAdPlacement.values) {
      if (v.name == raw) return v;
    }
    return ManagedAdPlacement.home;
  }
}

enum ManagedAdCampaignType {
  brand,
  sponsorship,
  promotion,
  awareness,
  performance;

  String get label => switch (this) {
        ManagedAdCampaignType.brand => 'Brand',
        ManagedAdCampaignType.sponsorship => 'Sponsorship',
        ManagedAdCampaignType.promotion => 'Promotion',
        ManagedAdCampaignType.awareness => 'Awareness',
        ManagedAdCampaignType.performance => 'Performance',
      };

  String get wireValue => name;

  static ManagedAdCampaignType parse(String? raw) {
    if (raw == null || raw.isEmpty) return ManagedAdCampaignType.brand;
    for (final v in ManagedAdCampaignType.values) {
      if (v.name == raw) return v;
    }
    return ManagedAdCampaignType.brand;
  }
}

enum ManagedSponsoredEntityType {
  tournament,
  match,
  team,
  player,
  communityPost,
  discoverPost,
  ground,
  organization;

  String get label => switch (this) {
        ManagedSponsoredEntityType.tournament => 'Tournament',
        ManagedSponsoredEntityType.match => 'Match',
        ManagedSponsoredEntityType.team => 'Team',
        ManagedSponsoredEntityType.player => 'Player',
        ManagedSponsoredEntityType.communityPost => 'Community Post',
        ManagedSponsoredEntityType.discoverPost => 'Discover Post',
        ManagedSponsoredEntityType.ground => 'Ground',
        ManagedSponsoredEntityType.organization => 'Organization',
      };

  String get wireValue => name;

  static ManagedSponsoredEntityType parse(String? raw) {
    if (raw == null || raw.isEmpty) {
      return ManagedSponsoredEntityType.tournament;
    }
    for (final v in ManagedSponsoredEntityType.values) {
      if (v.name == raw) return v;
    }
    return ManagedSponsoredEntityType.tournament;
  }
}

enum ManagedAdmobFormat {
  banner,
  native,
  interstitial,
  rewarded,
  appOpen;

  String get label => switch (this) {
        ManagedAdmobFormat.banner => 'Banner',
        ManagedAdmobFormat.native => 'Native',
        ManagedAdmobFormat.interstitial => 'Interstitial',
        ManagedAdmobFormat.rewarded => 'Rewarded',
        ManagedAdmobFormat.appOpen => 'App Open',
      };

  String get wireValue => name;
}

enum AdsSortField {
  createdAt,
  title,
  status,
  startDate,
  priority,
}

class AdsSort {
  const AdsSort({
    this.field = AdsSortField.createdAt,
    this.descending = true,
  });

  final AdsSortField field;
  final bool descending;

  AdsSort toggle(AdsSortField next) {
    if (field == next) {
      return AdsSort(field: field, descending: !descending);
    }
    return AdsSort(field: next, descending: true);
  }
}
