export type SeriesStatus = "draft" | "active" | "suspended" | "archived";

export interface SeriesSettings {
  maxSquadSize: number;
  requireFullName: boolean;
  requireCrickFlowPlayerId: boolean;
  requireDateOfBirth: boolean;
  requireNationalId: boolean;
  requirePassport: boolean;
  requirePhoneNumber: boolean;
  requireAddress: boolean;
  requireProfilePhoto: boolean;
  rankingRules?: {
    winPoints: number;
    lossPoints: number;
    tiePoints: number;
    noResultPoints: number;
    useNetRunRate: boolean;
  };
}

export interface Series {
  id: string;
  name: string;
  description: string;
  rulesText: string;
  status: SeriesStatus;
  kind: string;
  coverImageUrl?: string;
  logoUrl?: string;
  superAdminUserId?: string;
  clubCount: number;
  playerCount: number;
  matchCount: number;
  tournamentCount: number;
  settings: SeriesSettings;
}

export interface SeriesClub {
  id: string;
  seriesId: string;
  name: string;
  description: string;
  logoUrl?: string;
  status: string;
  squadCount: number;
}

export interface SeriesClubRanking {
  id: string;
  seriesId: string;
  clubId: string;
  clubName: string;
  played: number;
  won: number;
  lost: number;
  points: number;
  netRunRate: number;
}

export interface SeriesPlayerRanking {
  id: string;
  seriesId: string;
  userId: string;
  displayName: string;
  matches: number;
  runs: number;
  wickets: number;
}

export interface SeriesApproval {
  id: string;
  targetType: string;
  targetId: string;
  requestedBy: string;
  metadata: Record<string, unknown>;
}

export interface SeriesDetailData {
  series: Series;
  clubs: SeriesClub[];
  clubRankings: SeriesClubRanking[];
  playerRankings: SeriesPlayerRanking[];
  competitions: Array<{
    id: string;
    title: string;
    type: string;
    status: string;
    matchId?: string;
    tournamentId?: string;
  }>;
  admins: Array<{
    id: string;
    userId: string;
    displayName: string;
    status: string;
    role: string;
  }>;
  canManage: boolean;
  isSuperAdmin: boolean;
  pendingApprovalCount: number;
  approvals: SeriesApproval[];
}
