import type {
  ChatStatus,
  CommunityCategory,
  CricketBallType,
  MatchStatus,
  MatchType,
  OpportunityCategory,
  OpportunityStatus,
  StreamStatus,
  TournamentFormat,
  TournamentStatus,
  UserRole,
} from "./enums";

export type FirestoreMap = Record<string, unknown>;

export interface LocationData {
  country: string;
  stateProvince: string;
  district: string;
  city: string;
  placeName: string;
  latitude?: number;
  longitude?: number;
}

export interface PlayerStats {
  runs: number;
  ballsFaced: number;
  fours: number;
  sixes: number;
  wickets: number;
  oversBowledBalls: number;
  runsConceded: number;
  catches: number;
  runOuts: number;
  stumpings: number;
  matchesPlayed: number;
  inningsPlayed: number;
  dismissals: number;
  highScore: number;
  thirties: number;
  fifties: number;
  hundreds: number;
  ducks: number;
  threeWickets: number;
  fiveWickets: number;
}

export interface TeamStats {
  matchesPlayed: number;
  matchesWon: number;
  matchesLost: number;
  matchesTied: number;
  points: number;
  netRunRate: number;
  totalRunsScored: number;
  totalWicketsTaken: number;
  totalWicketsLost: number;
}

export interface BatsmanInnings {
  playerId: string;
  playerName: string;
  runs: number;
  balls: number;
  fours: number;
  sixes: number;
  isOut: boolean;
  dismissalInfo: string;
  retiredHurt: boolean;
  isEligibleToReturn: boolean;
  status?: string;
}

export interface BowlerInnings {
  playerId: string;
  playerName: string;
  oversBowledBalls: number;
  runsConceded: number;
  wickets: number;
  wides: number;
  noBalls: number;
}

export interface PartnershipRecord {
  batterAId: string;
  batterBId: string;
  batterAName: string;
  batterBName: string;
  runs: number;
  balls: number;
}

export interface FallOfWicket {
  wicketNumber: number;
  batsmanId: string;
  batsmanName: string;
  teamScore: number;
  legalBalls: number;
  dismissal: string;
}

export interface InningsFielder {
  playerId: string;
  catches: number;
  runOuts: number;
  stumpings: number;
}

export interface Innings {
  inningsNumber: number;
  battingTeamId: string;
  bowlingTeamId: string;
  status: string;
  totalRuns: number;
  totalWickets: number;
  legalBalls: number;
  extras: number;
  strikerId?: string;
  nonStrikerId?: string;
  currentBowlerId?: string;
  batsmen: BatsmanInnings[];
  bowlers: BowlerInnings[];
  fielders: InningsFielder[];
  partnershipRuns: number;
  partnershipBalls: number;
  isFreeHitActive: boolean;
  targetRuns?: number;
  partnerships: PartnershipRecord[];
  fallOfWickets: FallOfWicket[];
}

export interface StreamInfo {
  status: StreamStatus;
  destination: string;
  viewerCount: number;
  youtubeWatchUrl?: string;
  secondaryYoutubeWatchUrl?: string;
  webrtcEnabled: boolean;
  cameraALabel: string;
  cameraBLabel: string;
}

export interface MatchRules {
  cricketMatchType: string;
  format: string;
  ballType: CricketBallType | string;
  totalOvers: number;
  ballsPerOver: number;
  freeHitEnabled: boolean;
}

export interface Match {
  id: string;
  title: string;
  matchType: MatchType | string;
  status: MatchStatus | string;
  teamAId?: string;
  teamBId?: string;
  teamAName: string;
  teamBName: string;
  tournamentId?: string;
  roundName?: string;
  rules: MatchRules;
  innings: Innings[];
  currentInningsIndex: number;
  location: LocationData;
  venue: string;
  scheduledAt?: Date | null;
  startedAt?: Date | null;
  completedAt?: Date | null;
  createdBy?: string;
  winnerTeamId?: string;
  resultSummary: string;
  matchHero?: { playerId?: string; playerName: string; reason: string };
  playerOfMatchId?: string;
  stream: StreamInfo;
  publicMatchId?: string;
  setup?: FirestoreMap;
}

export interface OverlayState {
  matchId: string;
  teamAName: string;
  teamBName: string;
  battingTeamName: string;
  totalRuns: number;
  totalWickets: number;
  legalBalls: number;
  ballsPerOver: number;
  runRate: number;
  requiredRunRate?: number;
  target?: number;
  strikerName: string;
  strikerRuns: number;
  strikerBalls: number;
  nonStrikerName: string;
  nonStrikerRuns: number;
  nonStrikerBalls: number;
  bowlerName: string;
  bowlerWickets: number;
  bowlerRuns: number;
  bowlerBalls: number;
  matchStatus: string;
  isFreeHit?: boolean;
}

export interface BallEvent {
  id: string;
  matchId: string;
  inningsNumber: number;
  overNumber: number;
  ballInOver: number;
  eventType: string;
  runs: number;
  batsmanRuns: number;
  extraRuns: number;
  isLegalDelivery: boolean;
  isFreeHit: boolean;
  isWicket: boolean;
  commentary: string;
  sequence: number;
  strikerId?: string;
  bowlerId?: string;
  bowlerName?: string;
  wagonWheel?: { enabled?: boolean; x?: number; y?: number; shotType?: string };
  dismissalText?: string;
  isHighlight?: boolean;
}

export interface Team {
  id: string;
  name: string;
  teamCode?: string;
  logoUrl?: string;
  teamProfileImageUrl?: string;
  captainId?: string;
  viceCaptainId?: string;
  coachName?: string;
  playerIds: string[];
  memberCount: number;
  location: LocationData;
  stats: TeamStats;
  createdBy?: string;
}

export interface Player {
  id: string;
  name: string;
  teamId?: string;
  jerseyNumber?: number;
  battingStyle?: string;
  bowlingStyle?: string;
  photoUrl?: string;
  role?: string;
  location: LocationData;
  stats: PlayerStats;
  userId?: string;
  playerId?: string;
  country?: string;
}

export interface UserProfile {
  id: string;
  email: string;
  name: string;
  displayName: string;
  phoneNumber?: string;
  photoUrl?: string;
  role: UserRole | string;
  location: LocationData;
  playerId?: string;
  bio: string;
  playingRole?: string;
  battingStyle?: string;
  bowlingStyle?: string;
  jerseyNumber?: number;
  onboardingCompleted: boolean;
}

export interface PointsTableEntry {
  teamId: string;
  teamName: string;
  played: number;
  won: number;
  lost: number;
  tied: number;
  noResult: number;
  points: number;
  netRunRate: number;
  position: number;
}

export interface BracketSlot {
  matchId?: string;
  teamAId?: string;
  teamBId?: string;
  teamAName: string;
  teamBName: string;
  winnerTeamId?: string;
  winnerTeamName: string;
}

export interface Tournament {
  id: string;
  name: string;
  format: TournamentFormat | string;
  status: TournamentStatus | string;
  teamIds: string[];
  matchIds: string[];
  pointsTable: PointsTableEntry[];
  bracketRounds: BracketSlot[][];
  location: LocationData;
  bannerUrl?: string;
  thumbnailUrl?: string;
  grounds: string[];
  organizerName?: string;
  createdBy?: string;
  startDate?: Date | null;
  endDate?: Date | null;
}

export interface MatchHighlight {
  id: string;
  title: string;
  tag?: string;
  mediaUrl?: string;
  ballEventId?: string;
}

export interface FantasyLeague {
  id: string;
  name: string;
  matchId: string;
  matchTitle: string;
  status: string;
  squadSize: number;
}

export interface CommunityPost {
  id: string;
  authorId: string;
  authorName: string;
  authorPhotoUrl?: string;
  authorPlayerId?: string;
  category: CommunityCategory | string;
  postKind?: string;
  title: string;
  body: string;
  location: LocationData;
  tournamentId?: string;
  media: { url: string; type: string; aspect?: string }[];
  likeCount: number;
  commentCount: number;
  shareCount: number;
  createdAt?: Date | null;
}

export interface CommunityComment {
  id: string;
  authorId: string;
  authorName: string;
  body: string;
  createdAt?: Date | null;
}

export interface OpportunityPost {
  id: string;
  authorId: string;
  authorName: string;
  authorPhotoUrl?: string;
  category: OpportunityCategory | string;
  title: string;
  description: string;
  location: LocationData;
  fields: FirestoreMap;
  tags: string[];
  searchText: string;
  contactMethods: string[];
  contactPhone: string;
  contactWhatsApp: string;
  mediaUrls: string[];
  status: OpportunityStatus | string;
  viewCount: number;
  saveCount: number;
  createdAt?: Date | null;
}

export interface ChatThread {
  id: string;
  participantIds: string[];
  participants: Record<string, { name: string; photoUrl?: string; playerId?: string }>;
  lastMessage: string;
  lastMessageAt?: Date | null;
  lastSenderId: string;
  status: ChatStatus | string;
  requestFrom?: string;
  unread: Record<string, number>;
  archivedBy: string[];
}

export interface ChatMessage {
  id: string;
  senderId: string;
  text: string;
  createdAt?: Date | null;
  readBy: string[];
}

export interface AppNotification {
  id: string;
  userId: string;
  title: string;
  body: string;
  matchId?: string;
  tournamentId?: string;
  playerId?: string;
  teamId?: string;
  requestId?: string;
  chatId?: string;
  tab?: string;
  type?: string;
  category?: string;
  read: boolean;
  createdAt?: Date | null;
}

export interface DerivedGround {
  id: string;
  name: string;
  location: LocationData;
  matchCount: number;
  tournamentCount: number;
}

export interface HomePromotion {
  id: string;
  kind: string;
  title: string;
  description: string;
  imageUrl: string;
  buttonText: string;
  redirectAction: string;
  redirectUrl: string;
  active: boolean;
}
