import type {
  AppNotification,
  BallEvent,
  BatsmanInnings,
  BowlerInnings,
  BracketSlot,
  ChatMessage,
  ChatThread,
  CommunityComment,
  CommunityPost,
  HomePromotion,
  Innings,
  LocationData,
  Match,
  MatchHighlight,
  OpportunityPost,
  OverlayState,
  Player,
  PlayerStats,
  PointsTableEntry,
  Team,
  TeamStats,
  Tournament,
  UserProfile,
} from "@/types/models";
import {
  asBoolean,
  asNumber,
  asRecord,
  asString,
  asStringArray,
  parseDate,
} from "@/lib/utils";

function mapBracketRounds(raw: unknown): BracketSlot[][] {
  if (!Array.isArray(raw) || raw.length === 0) return [];
  const first = raw[0];
  if (first && typeof first === "object" && "slots" in (first as object)) {
    return [...raw]
      .map((item) => {
        const round = asRecord(item) ?? {};
        const slots = Array.isArray(round.slots) ? round.slots : [];
        return {
          index: asNumber(round.roundIndex),
          slots: slots.map(mapBracketSlot),
        };
      })
      .sort((a, b) => a.index - b.index)
      .map((round) => round.slots);
  }
  return raw.map((round) =>
    Array.isArray(round) ? round.map(mapBracketSlot) : [],
  );
}

function mapBracketSlot(raw: unknown): BracketSlot {
  const map = asRecord(raw) ?? {};
  return {
    matchId: asString(map.matchId) || undefined,
    teamAId: asString(map.teamAId) || undefined,
    teamBId: asString(map.teamBId) || undefined,
    teamAName: asString(map.teamAName),
    teamBName: asString(map.teamBName),
    winnerTeamId: asString(map.winnerTeamId) || undefined,
    winnerTeamName: asString(map.winnerTeamName),
  };
}

export function mapHighlight(id: string, data: Record<string, unknown>): MatchHighlight {
  return {
    id,
    title: asString(data.title) || asString(data.tag) || "Highlight",
    tag: asString(data.tag) || asString(data.highlightTag) || undefined,
    mediaUrl: asString(data.mediaUrl) || asString(data.url) || undefined,
    ballEventId: asString(data.ballEventId) || undefined,
  };
}

export function mapFantasyLeague(id: string, data: Record<string, unknown>) {
  return {
    id,
    name: asString(data.name, "Fantasy league"),
    matchId: asString(data.matchId),
    matchTitle: asString(data.matchTitle),
    status: asString(data.status, "open"),
    squadSize: asNumber(data.squadSize, 11),
  };
}

export function mapLocation(raw: unknown): LocationData {
  const map = asRecord(raw) ?? {};
  return {
    country: asString(map.country),
    stateProvince: asString(map.stateProvince),
    district: asString(map.district),
    city: asString(map.city),
    placeName:
      asString(map.placeName) ||
      asString(map.venue) ||
      asString(map.groundName),
    latitude: typeof map.latitude === "number" ? map.latitude : typeof map.lat === "number" ? map.lat : undefined,
    longitude:
      typeof map.longitude === "number"
        ? map.longitude
        : typeof map.lng === "number"
          ? map.lng
          : undefined,
  };
}

export function mapPlayerStats(raw: unknown): PlayerStats {
  const map = asRecord(raw) ?? {};
  return {
    runs: asNumber(map.runs),
    ballsFaced: asNumber(map.ballsFaced),
    fours: asNumber(map.fours),
    sixes: asNumber(map.sixes),
    wickets: asNumber(map.wickets),
    oversBowledBalls: asNumber(map.oversBowledBalls),
    runsConceded: asNumber(map.runsConceded),
    catches: asNumber(map.catches),
    runOuts: asNumber(map.runOuts),
    stumpings: asNumber(map.stumpings),
    matchesPlayed: asNumber(map.matchesPlayed),
    inningsPlayed: asNumber(map.inningsPlayed),
    dismissals: asNumber(map.dismissals),
    highScore: asNumber(map.highScore),
    thirties: asNumber(map.thirties),
    fifties: asNumber(map.fifties),
    hundreds: asNumber(map.hundreds),
    ducks: asNumber(map.ducks),
    threeWickets: asNumber(map.threeWickets),
    fiveWickets: asNumber(map.fiveWickets),
  };
}

function mapBatsman(raw: unknown): BatsmanInnings {
  const map = asRecord(raw) ?? {};
  return {
    playerId: asString(map.playerId),
    playerName: asString(map.playerName),
    runs: asNumber(map.runs),
    balls: asNumber(map.balls),
    fours: asNumber(map.fours),
    sixes: asNumber(map.sixes),
    isOut: asBoolean(map.isOut),
    dismissalInfo: asString(map.dismissalInfo),
    retiredHurt: asBoolean(map.retiredHurt) || asBoolean(map.isRetiredHurt) || asString(map.status) === "retired_hurt",
    isEligibleToReturn: asBoolean(map.canReturn) || asBoolean(map.isEligibleToReturn),
    status: asString(map.status) || undefined,
  };
}

function mapBowler(raw: unknown): BowlerInnings {
  const map = asRecord(raw) ?? {};
  return {
    playerId: asString(map.playerId),
    playerName: asString(map.playerName),
    oversBowledBalls: asNumber(map.oversBowledBalls),
    runsConceded: asNumber(map.runsConceded),
    wickets: asNumber(map.wickets),
    wides: asNumber(map.wides),
    noBalls: asNumber(map.noBalls),
  };
}

function mapInnings(raw: unknown): Innings {
  const map = asRecord(raw) ?? {};
  return {
    inningsNumber: asNumber(map.inningsNumber, 1),
    battingTeamId: asString(map.battingTeamId),
    bowlingTeamId: asString(map.bowlingTeamId),
    status: asString(map.status, "notStarted"),
    totalRuns: asNumber(map.totalRuns),
    totalWickets: asNumber(map.totalWickets),
    legalBalls: asNumber(map.legalBalls),
    extras: asNumber(map.extras),
    strikerId: asString(map.strikerId) || undefined,
    nonStrikerId: asString(map.nonStrikerId) || undefined,
    currentBowlerId: asString(map.currentBowlerId) || undefined,
    batsmen: Array.isArray(map.batsmen) ? map.batsmen.map(mapBatsman) : [],
    bowlers: Array.isArray(map.bowlers) ? map.bowlers.map(mapBowler) : [],
    fielders: Array.isArray(map.fielders)
      ? map.fielders.map((item) => {
          const f = asRecord(item) ?? {};
          return {
            playerId: asString(f.playerId),
            catches: asNumber(f.catches),
            runOuts: asNumber(f.runOuts),
            stumpings: asNumber(f.stumpings),
          };
        })
      : [],
    partnershipRuns: asNumber(map.partnershipRuns),
    partnershipBalls: asNumber(map.partnershipBalls),
    isFreeHitActive: asBoolean(map.isFreeHitActive),
    targetRuns: typeof map.targetRuns === "number" ? map.targetRuns : undefined,
    partnerships: Array.isArray(map.partnerships)
      ? map.partnerships.map((item) => {
          const p = asRecord(item) ?? {};
          return {
            batterAId: asString(p.batterAId),
            batterBId: asString(p.batterBId),
            batterAName: asString(p.batterAName),
            batterBName: asString(p.batterBName),
            runs: asNumber(p.runs),
            balls: asNumber(p.balls),
          };
        })
      : [],
    fallOfWickets: Array.isArray(map.fallOfWickets)
      ? map.fallOfWickets.map((item) => {
          const f = asRecord(item) ?? {};
          return {
            wicketNumber: asNumber(f.wicketNumber),
            batsmanId: asString(f.batsmanId),
            batsmanName: asString(f.batsmanName),
            teamScore: asNumber(f.teamScore),
            legalBalls: asNumber(f.legalBalls),
            dismissal: asString(f.dismissal),
          };
        })
      : [],
  };
}

export function mapMatch(id: string, data: Record<string, unknown>): Match {
  const stream = asRecord(data.stream) ?? {};
  const rules = asRecord(data.rules) ?? {};
  const hero = asRecord(data.matchHero);
  return {
    id,
    title: asString(data.title, "Match"),
    matchType: asString(data.matchType, "single"),
    status: asString(data.status, "draft"),
    teamAId: asString(data.teamAId) || undefined,
    teamBId: asString(data.teamBId) || undefined,
    teamAName: asString(data.teamAName),
    teamBName: asString(data.teamBName),
    tournamentId: asString(data.tournamentId) || undefined,
    roundName: asString(data.roundName) || undefined,
    rules: {
      cricketMatchType: asString(rules.cricketMatchType, "limitedOvers"),
      format: asString(rules.format, "standard"),
      ballType: asString(rules.ballType, "leather"),
      totalOvers: asNumber(rules.totalOvers, 20),
      ballsPerOver: asNumber(rules.ballsPerOver, 6),
      freeHitEnabled: asBoolean(rules.freeHitEnabled, true),
    },
    innings: Array.isArray(data.innings) ? data.innings.map(mapInnings) : [],
    currentInningsIndex: asNumber(data.currentInningsIndex),
    location: mapLocation(data.location),
    venue: asString(data.venue),
    scheduledAt: parseDate(data.scheduledAt),
    startedAt: parseDate(data.startedAt),
    completedAt: parseDate(data.completedAt),
    createdBy: asString(data.createdBy) || undefined,
    winnerTeamId: asString(data.winnerTeamId) || undefined,
    resultSummary: asString(data.resultSummary),
    matchHero: hero
      ? {
          playerId: asString(hero.playerId) || undefined,
          playerName: asString(hero.playerName),
          reason: asString(hero.reason),
        }
      : undefined,
    playerOfMatchId: asString(data.playerOfMatchId) || undefined,
    stream: {
      status: (asString(stream.status, "idle") as Match["stream"]["status"]) || "idle",
      destination: asString(stream.destination, "youtube"),
      viewerCount: asNumber(stream.viewerCount),
      youtubeWatchUrl: asString(stream.youtubeWatchUrl) || undefined,
      secondaryYoutubeWatchUrl: asString(stream.secondaryYoutubeWatchUrl) || undefined,
      webrtcEnabled: asBoolean(stream.webrtcEnabled),
      cameraALabel: asString(stream.cameraALabel, "Main camera"),
      cameraBLabel: asString(stream.cameraBLabel, "Camera 2"),
    },
    publicMatchId: asString(data.publicMatchId) || undefined,
    setup: asRecord(data.setup) ?? undefined,
  };
}

export function mapOverlay(data: Record<string, unknown>): OverlayState {
  return {
    matchId: asString(data.matchId),
    teamAName: asString(data.teamAName),
    teamBName: asString(data.teamBName),
    battingTeamName: asString(data.battingTeamName),
    totalRuns: asNumber(data.totalRuns),
    totalWickets: asNumber(data.totalWickets),
    legalBalls: asNumber(data.legalBalls),
    ballsPerOver: asNumber(data.ballsPerOver, 6),
    runRate: asNumber(data.runRate),
    requiredRunRate:
      typeof data.requiredRunRate === "number" ? data.requiredRunRate : undefined,
    target: typeof data.target === "number" ? data.target : undefined,
    strikerName: asString(data.strikerName),
    strikerRuns: asNumber(data.strikerRuns),
    strikerBalls: asNumber(data.strikerBalls),
    nonStrikerName: asString(data.nonStrikerName),
    nonStrikerRuns: asNumber(data.nonStrikerRuns),
    nonStrikerBalls: asNumber(data.nonStrikerBalls),
    bowlerName: asString(data.bowlerName),
    bowlerWickets: asNumber(data.bowlerWickets),
    bowlerRuns: asNumber(data.bowlerRuns),
    bowlerBalls: asNumber(data.bowlerBalls),
    matchStatus: asString(data.matchStatus, "Live"),
    isFreeHit: asBoolean(data.isFreeHit) || asBoolean(data.isFreeHitActive),
  };
}

export function mapBallEvent(id: string, data: Record<string, unknown>): BallEvent {
  const wheel = asRecord(data.wagonWheel);
  return {
    id,
    matchId: asString(data.matchId),
    inningsNumber: asNumber(data.inningsNumber, 1),
    overNumber: asNumber(data.overNumber),
    ballInOver: asNumber(data.ballInOver),
    eventType: asString(data.eventType),
    runs: asNumber(data.runs),
    batsmanRuns: asNumber(data.batsmanRuns),
    extraRuns: asNumber(data.extraRuns),
    isLegalDelivery: asBoolean(data.isLegalDelivery, true),
    isFreeHit: asBoolean(data.isFreeHit),
    isWicket: asBoolean(data.isWicket),
    commentary: asString(data.commentary) || asString(data.dismissalText),
    sequence: asNumber(data.sequence),
    strikerId: asString(data.strikerId) || undefined,
    bowlerId: asString(data.bowlerId) || undefined,
    bowlerName: asString(data.bowlerName) || undefined,
    wagonWheel: wheel
      ? {
          enabled: asBoolean(wheel.enabled),
          x: typeof wheel.x === "number" ? wheel.x : undefined,
          y: typeof wheel.y === "number" ? wheel.y : undefined,
          shotType: asString(wheel.shotType) || undefined,
        }
      : undefined,
    dismissalText: asString(data.dismissalText) || undefined,
    isHighlight: asBoolean(data.isHighlight),
  };
}

export function mapTeam(id: string, data: Record<string, unknown>): Team {
  const stats = asRecord(data.stats) ?? {};
  const teamStats: TeamStats = {
    matchesPlayed: asNumber(stats.matchesPlayed),
    matchesWon: asNumber(stats.matchesWon),
    matchesLost: asNumber(stats.matchesLost),
    matchesTied: asNumber(stats.matchesTied),
    points: asNumber(stats.points),
    netRunRate: asNumber(stats.netRunRate),
    totalRunsScored: asNumber(stats.totalRunsScored),
    totalWicketsTaken: asNumber(stats.totalWicketsTaken),
    totalWicketsLost: asNumber(stats.totalWicketsLost),
  };
  return {
    id,
    name: asString(data.name, "Team"),
    teamCode: asString(data.teamCode) || undefined,
    logoUrl: asString(data.logoUrl) || asString(data.teamProfileImageUrl) || undefined,
    teamProfileImageUrl: asString(data.teamProfileImageUrl) || undefined,
    captainId: asString(data.captainId) || undefined,
    viceCaptainId: asString(data.viceCaptainId) || undefined,
    coachName: asString(data.coachName) || undefined,
    playerIds: asStringArray(data.playerIds),
    memberCount: asNumber(data.memberCount),
    location: mapLocation(data.location),
    stats: teamStats,
    createdBy: asString(data.createdBy) || undefined,
  };
}

export function mapPlayer(id: string, data: Record<string, unknown>): Player {
  return {
    id,
    name: asString(data.name, "Player"),
    teamId: asString(data.teamId) || undefined,
    jerseyNumber: typeof data.jerseyNumber === "number" ? data.jerseyNumber : undefined,
    battingStyle: asString(data.battingStyle) || undefined,
    bowlingStyle: asString(data.bowlingStyle) || undefined,
    photoUrl: asString(data.photoUrl) || undefined,
    role: asString(data.role) || undefined,
    location: mapLocation(data.location),
    stats: mapPlayerStats(data.stats),
    userId: asString(data.userId) || asString(data.uid) || undefined,
    playerId: asString(data.playerId) || asString(data.cfPlayerId) || undefined,
    country: asString(data.country) || undefined,
  };
}

export function mapUser(id: string, data: Record<string, unknown>): UserProfile {
  return {
    id,
    email: asString(data.email),
    name: asString(data.name),
    displayName: asString(data.displayName),
    phoneNumber: asString(data.phoneNumber) || asString(data.mobile) || undefined,
    photoUrl: asString(data.photoUrl) || undefined,
    role: asString(data.role, "organizer"),
    location: mapLocation(data.location),
    playerId: asString(data.playerId) || undefined,
    bio: asString(data.bio),
    onboardingCompleted: asBoolean(data.onboardingCompleted),
  };
}

export function mapTournament(id: string, data: Record<string, unknown>): Tournament {
  return {
    id,
    name: asString(data.name, "Tournament"),
    format: asString(data.format, "league"),
    status: asString(data.status, "upcoming"),
    teamIds: asStringArray(data.teamIds),
    matchIds: asStringArray(data.matchIds),
    pointsTable: Array.isArray(data.pointsTable)
      ? data.pointsTable.map((item) => {
          const p = asRecord(item) ?? {};
          const entry: PointsTableEntry = {
            teamId: asString(p.teamId),
            teamName: asString(p.teamName),
            played: asNumber(p.played),
            won: asNumber(p.won),
            lost: asNumber(p.lost),
            tied: asNumber(p.tied),
            noResult: asNumber(p.noResult),
            points: asNumber(p.points),
            netRunRate: asNumber(p.netRunRate),
            position: asNumber(p.position),
          };
          return entry;
        })
      : [],
    location: mapLocation(data.location),
    bannerUrl: asString(data.bannerUrl) || asString(data.thumbnailUrl) || undefined,
    thumbnailUrl: asString(data.thumbnailUrl) || undefined,
    grounds: asStringArray(data.grounds),
    bracketRounds: mapBracketRounds(data.bracketRounds),
    organizerName: asString(data.organizerName) || asString(data.organizer) || undefined,
    createdBy: asString(data.createdBy) || undefined,
    startDate: parseDate(data.startDate),
    endDate: parseDate(data.endDate),
  };
}

export function mapCommunityPost(id: string, data: Record<string, unknown>): CommunityPost {
  return {
    id,
    authorId: asString(data.authorId),
    authorName: asString(data.authorName),
    authorPhotoUrl: asString(data.authorPhotoUrl) || undefined,
    authorPlayerId: asString(data.authorPlayerId) || undefined,
    category: asString(data.category, "general"),
    postKind: asString(data.postKind) || undefined,
    title: asString(data.title),
    body: asString(data.body),
    location: mapLocation(data.location),
    tournamentId: asString(data.tournamentId) || undefined,
    media: Array.isArray(data.media)
      ? data.media.map((item) => {
          const m = asRecord(item) ?? {};
          return {
            url: asString(m.url),
            type: asString(m.type, "image"),
            aspect: asString(m.aspect) || undefined,
          };
        })
      : [],
    likeCount: asNumber(data.likeCount),
    commentCount: asNumber(data.commentCount),
    shareCount: asNumber(data.shareCount),
    createdAt: parseDate(data.createdAt),
  };
}

export function mapCommunityComment(id: string, data: Record<string, unknown>): CommunityComment {
  return {
    id,
    authorId: asString(data.authorId),
    authorName: asString(data.authorName),
    body: asString(data.body) || asString(data.text),
    createdAt: parseDate(data.createdAt),
  };
}

export function mapOpportunity(id: string, data: Record<string, unknown>): OpportunityPost {
  return {
    id,
    authorId: asString(data.authorId),
    authorName: asString(data.authorName),
    authorPhotoUrl: asString(data.authorPhotoUrl) || undefined,
    category: asString(data.category, "findPlayer"),
    title: asString(data.title),
    description: asString(data.description),
    location: mapLocation(data.location),
    fields: asRecord(data.fields) ?? {},
    tags: asStringArray(data.tags),
    searchText: asString(data.searchText),
    contactMethods: asStringArray(data.contactMethods),
    contactPhone: asString(data.contactPhone),
    contactWhatsApp: asString(data.contactWhatsApp),
    mediaUrls: asStringArray(data.mediaUrls),
    status: asString(data.status, "active"),
    viewCount: asNumber(data.viewCount),
    saveCount: asNumber(data.saveCount),
    createdAt: parseDate(data.createdAt),
  };
}

export function mapChat(id: string, data: Record<string, unknown>): ChatThread {
  const participantsRaw = asRecord(data.participants) ?? {};
  const participants: ChatThread["participants"] = {};
  for (const [uid, value] of Object.entries(participantsRaw)) {
    const p = asRecord(value) ?? {};
    participants[uid] = {
      name: asString(p.name),
      photoUrl: asString(p.photoUrl) || undefined,
      playerId: asString(p.playerId) || undefined,
    };
  }
  const unreadRaw = asRecord(data.unread) ?? {};
  const unread: Record<string, number> = {};
  for (const [uid, value] of Object.entries(unreadRaw)) {
    unread[uid] = asNumber(value);
  }
  return {
    id,
    participantIds: asStringArray(data.participantIds),
    participants,
    lastMessage: asString(data.lastMessage),
    lastMessageAt: parseDate(data.lastMessageAt),
    lastSenderId: asString(data.lastSenderId),
    status: asString(data.status, "active"),
    requestFrom: asString(data.requestFrom) || undefined,
    unread,
    archivedBy: asStringArray(data.archivedBy),
  };
}

export function mapMessage(id: string, data: Record<string, unknown>): ChatMessage {
  return {
    id,
    senderId: asString(data.senderId),
    text: asString(data.text) || asString(data.body),
    createdAt: parseDate(data.createdAt) ?? parseDate(data.timestamp),
    readBy: asStringArray(data.readBy),
  };
}

export function mapNotification(id: string, data: Record<string, unknown>): AppNotification {
  return {
    id,
    userId: asString(data.userId),
    title: asString(data.title),
    body: asString(data.body) || asString(data.message),
    matchId: asString(data.matchId) || undefined,
    tournamentId: asString(data.tournamentId) || undefined,
    playerId: asString(data.playerId) || undefined,
    teamId: asString(data.teamId) || undefined,
    requestId: asString(data.requestId) || undefined,
    chatId: asString(data.chatId) || undefined,
    tab: asString(data.tab) || undefined,
    type: asString(data.type) || undefined,
    category: asString(data.category) || asString(data.type) || undefined,
    read: asBoolean(data.read),
    createdAt: parseDate(data.createdAt),
  };
}

export function mapPromotion(id: string, data: Record<string, unknown>): HomePromotion {
  return {
    id,
    kind: asString(data.kind, "announcement"),
    title: asString(data.title),
    description: asString(data.description),
    imageUrl: asString(data.imageUrl),
    buttonText: asString(data.buttonText),
    redirectAction: asString(data.redirectAction, "none"),
    redirectUrl: asString(data.redirectUrl),
    active: asBoolean(data.active, true),
  };
}
