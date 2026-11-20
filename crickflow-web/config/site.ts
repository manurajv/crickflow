/** Bump this when replacing favicon or logo files so browsers fetch the new assets. */
export const assetVersion = "20261120";

export const siteConfig = {
  name: "CrickFlow",
  tagline: "Score. Stream. Connect.",
  description:
    "Live cricket scores, tournaments, teams, players, and community — the web home of CrickFlow.",
  url: process.env.NEXT_PUBLIC_SITE_URL ?? "https://crickflow.web.app",
  logoUrl: `/icons/crickflow-logo.png?v=${assetVersion}`,
  icons: {
    ico: `/favicon.ico?v=${assetVersion}`,
    png16: `/icons/favicon-16.png?v=${assetVersion}`,
    png32: `/icons/favicon-32.png?v=${assetVersion}`,
    apple: `/icons/apple-touch-icon.png?v=${assetVersion}`,
    icon192: `/icons/icon-192.png?v=${assetVersion}`,
    icon512: `/icons/icon-512.png?v=${assetVersion}`,
  },
  playStoreUrl: "https://play.google.com/store/apps/details?id=com.mavixas.crickflow",
} as const;

export const collections = {
  users: "users",
  players: "players",
  teams: "teams",
  matches: "matches",
  tournaments: "tournaments",
  series: "series",
  seriesClubs: "series_clubs",
  seriesAdmins: "series_admins",
  seriesApprovals: "series_approvals",
  seriesCompetitions: "series_competitions",
  seriesClubRankings: "series_club_rankings",
  seriesPlayerRankings: "series_player_rankings",
  seriesMatchDigests: "series_match_digests",
  seriesAuditLogs: "series_audit_logs",
  seriesMemberships: "series_memberships",
  seriesClubAdmins: "series_club_admins",
  seriesRegistrations: "series_registrations",
  ballEvents: "ball_events",
  overlay: "overlay",
  public: "public",
  highlights: "highlights",
  communityPosts: "community_posts",
  communityPostReports: "community_post_reports",
  opportunityPosts: "opportunity_posts",
  opportunityPostReports: "opportunity_post_reports",
  notifications: "notifications",
  chats: "chats",
  chatBlocks: "chat_blocks",
  badges: "badges",
  homePromotions: "home_promotions",
  playerFollows: "playerFollows",
  teamFollowers: "teamFollowers",
  matchFollowers: "matchFollowers",
  fantasyLeagues: "fantasy_leagues",
  playerInvites: "player_invites",
  adminUsers: "admin_users",
} as const;

export const queryLimits: {
  home: number;
  list: number;
  feed: number;
  liveCommentary: number;
  rankingsPool: number;
  searchPool: number;
} = {
  home: 8,
  list: 24,
  feed: 20,
  liveCommentary: 40,
  rankingsPool: 400,
  searchPool: 80,
};
