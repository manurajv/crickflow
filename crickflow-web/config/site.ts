export const siteConfig = {
  name: "CrickFlow",
  tagline: "Score. Stream. Connect.",
  description:
    "Live cricket scores, tournaments, teams, players, and community — the web home of CrickFlow.",
  url: process.env.NEXT_PUBLIC_SITE_URL ?? "https://crickflow.web.app",
  logoUrl: "https://crickflow-b06bc.web.app/assets/crickflow-logo.png",
  playStoreUrl: "https://play.google.com/store/apps/details?id=com.mavixas.crickflow",
} as const;

export const collections = {
  users: "users",
  players: "players",
  teams: "teams",
  matches: "matches",
  tournaments: "tournaments",
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
